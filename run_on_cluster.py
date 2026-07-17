#!/usr/bin/env python3
"""
run_on_cluster.py — Submit every DBMS-bench usage scenario to the GMT measurement cluster.

This is a thin orchestration layer on top of ``gmt-helpers/api/submit_software.py``:
it discovers all usage scenarios in this repo (``<benchmark>/<db>.yml``) and submits
each one to the Green Metrics Tool API, reusing that script's ``APIClient`` for the
actual HTTP work.

Before submitting it makes sure the repo is clean and pushed, because the cluster
measures whatever is on GitHub — not your local working tree. If anything is
uncommitted or unpushed it fails fast and submits nothing.

The repo URL and branch are taken from git, so the cluster measures exactly the
commit you have checked out.

Examples:
  # Submit all scenarios on the current branch as one-off measurements
  ./run_on_cluster.py --api-key YOUR_TOKEN --machine-id 42

  # Preview what would be submitted without contacting the API
  ./run_on_cluster.py --api-key YOUR_TOKEN --machine-id 42 --dry-run

  # Only the TPC-H Postgres scenario, with a completion email
  ./run_on_cluster.py --api-key YOUR_TOKEN --machine-id 42 \
      --filter 'tpch/pg.yml' --email you@example.com

  # Only unoptimized scenarios
  ./run_on_cluster.py --api-key YOUR_TOKEN --machine-id 42 -t 0 -n
"""

from __future__ import annotations

import argparse
import fnmatch
import importlib.util
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from types import ModuleType

# Default location of submit_software.py: gmt-helpers checked out next to this repo.
DEFAULT_SUBMIT_SCRIPT = (
    Path(__file__).resolve().parent.parent / "gmt-helpers" / "api" / "submit_software.py"
)


def fail(message: str) -> "None":
    """Print an error to stderr and exit non-zero."""
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def load_submit_module(path: Path) -> ModuleType:
    """Import submit_software.py from an arbitrary path so we can reuse APIClient."""
    if not path.is_file():
        fail(
            f"submit_software.py not found at {path}\n"
            "       Pass --submit-script /path/to/submit_software.py "
            "or set GMT_SUBMIT_SCRIPT."
        )
    spec = importlib.util.spec_from_file_location("submit_software", path)
    if spec is None or spec.loader is None:
        fail(f"could not load submit_software.py from {path}")
    module = importlib.util.module_from_spec(spec)
    # Register before exec: the module defines @dataclass classes, and dataclass
    # processing looks the module up in sys.modules by name while executing.
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)  # type: ignore[union-attr]
    except Exception as exc:  # pragma: no cover - surfaced to the user
        fail(f"failed to import submit_software.py from {path}: {exc}")
    return module


def git(repo: Path, *args: str) -> str:
    """Run a git command in ``repo`` and return stripped stdout (raises on failure)."""
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"git {' '.join(args)} failed: {result.stderr.strip() or result.stdout.strip()}"
        )
    return result.stdout.strip()


def normalize_repo_url(url: str) -> str:
    """Turn any git remote URL into a plain https://host/owner/repo URL."""
    url = url.strip()
    if url.endswith(".git"):
        url = url[:-4]
    # scp-like syntax: git@github.com:owner/repo  (optionally ssh:// prefixed)
    match = re.match(r"^(?:ssh://)?[^@]+@([^:/]+)[:/](.+)$", url)
    if match:
        return f"https://{match.group(1)}/{match.group(2)}"
    if url.startswith("ssh://"):
        rest = url[len("ssh://") :].split("@", 1)[-1]
        host, _, path = rest.partition("/")
        return f"https://{host}/{path}"
    return url


def ensure_clean_and_pushed(repo: Path, remote: str, branch: str, do_fetch: bool) -> None:
    """Fail unless the working tree is clean and the branch is pushed to ``remote``."""
    # 1) Nothing uncommitted (tracked changes or untracked files): the cluster
    #    only ever sees what is committed and pushed to GitHub.
    status = git(repo, "status", "--porcelain")
    if status:
        fail(
            "working tree is not clean — commit or stash everything first:\n"
            + status
        )

    # 2) The branch must exist on the remote and match HEAD exactly.
    if do_fetch:
        try:
            git(repo, "fetch", "--quiet", remote, branch)
        except RuntimeError as exc:
            fail(f"could not fetch {remote}/{branch}: {exc}\n       (use --no-fetch to skip)")

    local_sha = git(repo, "rev-parse", "HEAD")
    try:
        remote_sha = git(repo, "rev-parse", f"{remote}/{branch}")
    except RuntimeError:
        fail(
            f"branch '{branch}' has not been pushed to '{remote}' — push it first:\n"
            f"       git push -u {remote} {branch}"
        )

    if local_sha != remote_sha:
        ahead = git(repo, "rev-list", "--count", f"{remote}/{branch}..HEAD")
        behind = git(repo, "rev-list", "--count", f"HEAD..{remote}/{branch}")
        detail = []
        if ahead != "0":
            detail.append(f"{ahead} commit(s) not pushed — run: git push {remote} {branch}")
        if behind != "0":
            detail.append(f"{behind} commit(s) behind {remote}/{branch} — run: git pull")
        fail(
            f"local HEAD ({local_sha[:9]}) differs from {remote}/{branch} ({remote_sha[:9]}):\n"
            + "\n".join(f"       {d}" for d in detail)
        )


def discover_scenarios(repo: Path) -> list[Path]:
    """Find all usage-scenario files: benchmarks/<benchmark>/<db>.yml under the repo.

    A file counts as a usage scenario only if it declares a ``flow:`` block, which
    excludes helper YAML like compose.yml and .github/dependabot.yml.
    """
    scenarios = []
    for path in sorted(repo.glob("benchmarks/*/*.yml")):
        text = path.read_text(encoding="utf-8", errors="replace")
        if re.search(r"^flow:", text, re.MULTILINE):
            scenarios.append(path)
    return scenarios


def scenario_tier(rel_path: Path) -> str:
    """Return the tuning tier for a scenario path: 0, 1, or 2.

    Tier 2 includes the common ``.t2.yml`` files and the ``.t2col.yml`` columnar
    sub-tier, because both represent workload-aware optimization beyond T1.
    """
    name = rel_path.name
    if name.endswith(".t1.yml"):
        return "1"
    if name.endswith(".t2.yml") or name.endswith(".t2col.yml"):
        return "2"
    return "0"


def build_name(prefix: str, rel_path: Path, branch: str) -> str:
    """A useful, unambiguous run name, e.g. 'DBMS-bench tpcc/pg'."""
    benchmark = rel_path.parent.name  # tpcc / tpch (drop the benchmarks/ prefix)
    db = rel_path.stem  # pg, maria, ...
    return f"{prefix} {benchmark}/{db}"


def submission_error_details(
    exc: Exception,
    payload: dict[str, object],
    api_url: str,
) -> list[str]:
    """Return safe diagnostics for a failed API submission.

    Do not include authentication headers or the API key. The payload only holds
    non-secret submission metadata.
    """
    details = [f"request: POST {api_url.rstrip('/')}/v1/software/add"]

    cause = exc.__cause__
    response = getattr(cause, "response", None)
    if response is not None:
        details.append(f"status: HTTP {response.status_code}")
        content_type = response.headers.get("content-type")
        if content_type:
            details.append(f"content-type: {content_type}")
        body = (response.text or "").strip()
        if body:
            details.append(f"response: {body[:1000]}")
    else:
        details.append("status: unavailable (no HTTP response attached)")

    details.append(
        "payload: "
        + json.dumps(payload, sort_keys=True, ensure_ascii=False, default=str)
    )

    if re.search(r"\bHTTP 404\b", str(exc)):
        details.append(
            "hint: HTTP 404 usually means the API endpoint was not found; check "
            "--api-url and that the submit helper still targets the current GMT API."
        )

    return details


def build_parser(submit_mod: ModuleType) -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--api-key",
        default=os.getenv("GMT_AUTH_TOKEN"),
        help="GMT API token (X-Authentication). Defaults to $GMT_AUTH_TOKEN.",
    )
    p.add_argument(
        "--machine-id",
        required=True,
        help="Target measurement machine ID (see: submit_software.py list-machines).",
    )
    p.add_argument(
        "--schedule-mode",
        default="one-off",
        choices=sorted(submit_mod.VALID_SCHEDULE_MODES),
        help="Measurement schedule mode (default: one-off).",
    )
    p.add_argument("--email", help="Optional email for a completion notification.")
    p.add_argument(
        "--name-prefix",
        default=None,
        help="Run-name prefix (default: the repo directory name, e.g. DBMS-bench).",
    )
    p.add_argument(
        "--remote",
        default="origin",
        help="Git remote to read the repo URL from and check against (default: origin).",
    )
    p.add_argument("--branch", help="Override the branch (default: current git branch).")
    p.add_argument("--repo-url", help="Override the repo URL (default: from git remote).")
    p.add_argument(
        "--filter",
        help="Only submit scenarios whose repo-relative path matches this glob "
        "(e.g. 'tpch/*.yml' or 'tpcc/pg.yml').",
    )
    p.add_argument(
        "-t",
        "--tier",
        choices=("0", "1", "2"),
        help="Only submit one tuning tier: 0=unoptimized base, 1=T1, 2=T2/T2+.",
    )
    p.add_argument(
        "--api-url",
        default=os.getenv("GMT_API_URL", "https://api.green-coding.io/").strip(),
        help="Base GMT API URL.",
    )
    p.add_argument(
        "--submit-script",
        default=os.getenv("GMT_SUBMIT_SCRIPT", str(DEFAULT_SUBMIT_SCRIPT)),
        help="Path to submit_software.py.",
    )
    p.add_argument(
        "--timeout",
        type=int,
        default=submit_mod.DEFAULT_TIMEOUT,
        help=f"HTTP timeout in seconds (default {submit_mod.DEFAULT_TIMEOUT}).",
    )
    p.add_argument("--no-fetch", action="store_true", help="Skip 'git fetch' before checking.")
    p.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="Show what would be submitted without contacting the API.",
    )
    return p


def main() -> None:
    # submit_software.py is imported first so its constants drive argument parsing
    # (schedule modes, default timeout) and we reuse its APIClient for submission.
    pre = argparse.ArgumentParser(add_help=False)
    pre.add_argument(
        "--submit-script",
        default=os.getenv("GMT_SUBMIT_SCRIPT", str(DEFAULT_SUBMIT_SCRIPT)),
    )
    submit_path = Path(pre.parse_known_args()[0].submit_script).expanduser()
    submit_mod = load_submit_module(submit_path)

    args = build_parser(submit_mod).parse_args()

    if not args.api_key:
        fail("no API key — pass --api-key or set $GMT_AUTH_TOKEN.")

    # Resolve the repo this script lives in.
    script_dir = Path(__file__).resolve().parent
    try:
        repo = Path(git(script_dir, "rev-parse", "--show-toplevel"))
    except RuntimeError as exc:
        fail(f"not inside a git repository: {exc}")

    branch = args.branch or git(repo, "rev-parse", "--abbrev-ref", "HEAD")
    if branch == "HEAD":
        fail("detached HEAD — check out a branch or pass --branch.")

    repo_url = args.repo_url or normalize_repo_url(git(repo, "remote", "get-url", args.remote))
    name_prefix = args.name_prefix or repo.name

    # Hard gate: refuse to submit anything unless everything is committed and pushed.
    # A dry-run submits nothing, so let it preview even on a dirty tree.
    if args.dry_run:
        print("[dry-run] skipping the committed/pushed check.\n")
    else:
        ensure_clean_and_pushed(repo, args.remote, branch, do_fetch=not args.no_fetch)

    scenarios = discover_scenarios(repo)
    rel_scenarios = [s.relative_to(repo) for s in scenarios]
    if args.tier is not None:
        rel_scenarios = [r for r in rel_scenarios if scenario_tier(r) == args.tier]
    if args.filter:
        # Match against the full repo-relative path (benchmarks/tpcc/pg.yml) as well
        # as the benchmarks-relative path (tpcc/pg.yml), so either form works.
        def _matches(r: Path) -> bool:
            full = r.as_posix()
            short = r.relative_to("benchmarks").as_posix() if r.parts[0] == "benchmarks" else full
            return fnmatch.fnmatch(full, args.filter) or fnmatch.fnmatch(short, args.filter)

        rel_scenarios = [r for r in rel_scenarios if _matches(r)]
    if not rel_scenarios:
        filters = []
        if args.tier is not None:
            filters.append(f"tier {args.tier}")
        if args.filter:
            filters.append(f"'{args.filter}'")
        suffix = " matching " + " and ".join(filters) if filters else ""
        fail("no usage scenarios found to submit" + suffix)

    print(f"Repo:     {repo_url}")
    print(f"Branch:   {branch}")
    print(f"Machine:  {args.machine_id}")
    print(f"Schedule: {args.schedule_mode}")
    print(f"API:      {args.api_url.rstrip('/')}")
    if args.tier is not None:
        print(f"Tier:     T{args.tier}")
    print(f"Scenarios ({len(rel_scenarios)}):")
    for rel in rel_scenarios:
        print(f"  - {rel.as_posix():<28} -> {build_name(name_prefix, rel, branch)}")

    if args.dry_run:
        print("\n[dry-run] nothing submitted.")
        return

    client = submit_mod.APIClient(
        api_url=args.api_url,
        token=args.api_key,
        timeout=args.timeout,
    )

    print()
    failures = 0
    for rel in rel_scenarios:
        payload = {
            "name": build_name(name_prefix, rel, branch),
            "repo_url": repo_url,
            "machine_id": args.machine_id,
            "schedule_mode": args.schedule_mode,
            "branch": branch,
            "filename": rel.as_posix(),
        }
        if args.email:
            payload["email"] = args.email
        try:
            client.submit_software(payload)
            print(f"  ok    {rel.as_posix()}")
        except Exception as exc:  # APIError, HTTP errors, etc.
            failures += 1
            print(f"  FAIL  {rel.as_posix()}: {exc}", file=sys.stderr)
            for detail in submission_error_details(exc, payload, args.api_url):
                print(f"        {detail}", file=sys.stderr)

    submitted = len(rel_scenarios) - failures
    print(f"\nSubmitted {submitted}/{len(rel_scenarios)} scenario(s).")
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
