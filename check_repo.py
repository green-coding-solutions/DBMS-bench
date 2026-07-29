#!/usr/bin/env python3
"""
check_repo.py — Consistency checks for the DBMS-bench repo.

The whole point of this repo is a *fair* comparison between database engines:
every engine has to run with the same resource budget and the same benchmark
parameters, otherwise the energy/throughput numbers are not comparable.

Because GMT refuses to `!include` a compose file from a parent directory, each
benchmark folder (``benchmarks/tpcc/``, ``benchmarks/tpch/``, ...) carries its
own copy of ``compose.yml`` next to the usage scenarios. Copies drift, so this
script enforces three invariants:

  1. Every ``compose.yml`` in the repo is byte-for-byte identical (the per-folder
     copies must match the root source of truth).
  2. Inside ``compose.yml`` every database service gets the same resource budget
     (``cpus`` and ``mem_limit``) — the load drivers are intentionally
     unconstrained and are skipped.
  3. For each benchmark, the per-engine driver scripts use the same fairness
     knobs (virtual users, scale factor, terminals, duration, ...) across all
     databases.

Exit code is 0 when everything is consistent, 1 otherwise. Run it from anywhere;
paths are resolved relative to this file.
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parent

# Database engines that may take part in a benchmark, and the benchmark folders
# that hold the GMT usage scenarios + the compose.yml copy.
DATABASES = ["pg", "maria", "mysql", "oracle", "mssql", "db2"]
BENCHMARKS = ["tpcc", "tpch", "wikipedia", "ycsb", "chbenchmark"]

# Driver scripts live at db/<db>/<benchmark>/. HammerDB benchmarks are configured in
# .tcl scripts, BenchBase benchmarks in an .xml config.
HAMMERDB_BENCHMARKS = {"tpcc", "tpch"}
BENCHBASE_BENCHMARKS = {"wikipedia", "ycsb", "chbenchmark"}

# Fairness knobs to extract from the HammerDB .tcl scripts, by benchmark. The
# values carry an engine-specific prefix in the scripts (pg_, maria_, mssqls_,
# ...; Oracle has none), so we match on the canonical suffix only. We compare a
# curated allow-list rather than every `diset` so engine-specific tuning that
# does not affect the comparison (connection strings, storage engines, ...) is
# ignored.
TCL_KNOBS = {
    "tpcc": {
        "vu": r"\bset\s+vu\s+(\d+)",
        "vuset_vu": r"\bvuset\s+vu\s+(\d+)",
        # A leading [\s_] absorbs the engine prefix (pg_rampup, maria_rampup, ...)
        # as well as the bare Oracle form (`diset tpcc rampup 2`).
        "rampup": r"[\s_]rampup\s+(\d+)",
        "duration": r"[\s_]duration\s+(\d+)",
    },
    "tpch": {
        "scale_fact": r"scale_fact\s+(\d+)",
        "num_tpch_threads": r"num_tpch_threads\s+(\d+)",
        "total_querysets": r"total_querysets\s+(\d+)",
        # Per-query intra-query parallelism. Each engine names this knob
        # differently in HammerDB: pg_/oracle/db2's `degree_of_parallel`, and
        # MSSQL's `mssqls_maxdop` (MAXDOP) — the same fairness setting, so we
        # match either. maria/mysql have no such HammerDB knob (no parallel
        # query control there), so they legitimately never set it. Db2 does have
        # one, and it must be paired with INTRA_PARALLEL=YES on the server (see
        # benchmarks/tpch/db2.yml) or Db2 rejects the request with SQL1530W.
        "degree_of_parallel": r"(?:degree_of_parallel|mssqls_maxdop)\s+(\d+)",
    },
}

# Fairness knobs to extract from the BenchBase .xml configs. <time>/<rate>/
# <weights> live inside <works>/<work>; the rest are top-level.
XML_TOP_KNOBS = ["scalefactor", "terminals", "batchsize", "isolation"]
XML_WORK_KNOBS = ["time", "rate", "weights"]


class Reporter:
    """Collects failures so we can report everything at once and exit non-zero."""

    def __init__(self) -> None:
        self.failures: list[str] = []
        self.warnings: list[str] = []

    def ok(self, msg: str) -> None:
        print(f"  \033[32m✓\033[0m {msg}")

    def fail(self, msg: str) -> None:
        print(f"  \033[31m✗\033[0m {msg}")
        self.failures.append(msg)

    def warn(self, msg: str) -> None:
        print(f"  \033[33m!\033[0m {msg}")
        self.warnings.append(msg)

    def section(self, title: str) -> None:
        print(f"\n\033[1m{title}\033[0m")


# --------------------------------------------------------------------------- #
# Check 1: every compose.yml is identical
# --------------------------------------------------------------------------- #
def check_compose_identical(rep: Reporter) -> None:
    rep.section("1. compose.yml files are identical")

    root = REPO / "compose.yml"
    if not root.is_file():
        rep.fail("root compose.yml not found")
        return

    reference = root.read_bytes()
    rep.ok(f"reference: {root.relative_to(REPO)} ({len(reference)} bytes)")

    copies = sorted(
        p for p in REPO.glob("benchmarks/*/compose.yml") if p.parent.name in BENCHMARKS
    )
    missing = [
        b for b in BENCHMARKS if not (REPO / "benchmarks" / b / "compose.yml").is_file()
    ]
    for b in missing:
        rep.fail(f"{b}/compose.yml is missing")

    for copy in copies:
        rel = copy.relative_to(REPO)
        if copy.read_bytes() == reference:
            rep.ok(f"{rel} matches root")
        else:
            rep.fail(f"{rel} differs from root compose.yml")


# --------------------------------------------------------------------------- #
# Check 2: every DB service has the same resource budget in compose.yml
# --------------------------------------------------------------------------- #
def parse_compose_resources(path: Path) -> dict[str, dict[str, str]]:
    """Return {service: {cpus, mem_limit}} for top-level services that declare a
    resource budget. A tiny indentation-based parser so we need no PyYAML (GMT's
    venv has it, but check_repo.py is meant to run with a bare interpreter).

    Assumes the canonical 2-space-per-level layout of this repo's compose.yml:
    `services:` at column 0, service names at 2 spaces, keys at 4 spaces.
    """
    resources: dict[str, dict[str, str]] = {}
    in_services = False
    current: str | None = None

    for raw in path.read_text().splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        stripped = raw.strip()

        if indent == 0:
            in_services = stripped.rstrip(":") == "services" and stripped.endswith(":")
            current = None
            continue
        if not in_services:
            continue

        if indent == 2 and stripped.endswith(":"):
            current = stripped[:-1].strip()
            continue
        if indent >= 4 and current is not None and ":" in stripped:
            key, _, value = stripped.partition(":")
            key = key.strip()
            if key in ("cpus", "mem_limit"):
                resources.setdefault(current, {})[key] = value.strip()

    return resources


def check_compose_resources(rep: Reporter) -> None:
    rep.section("2. DB resource budgets are equal in compose.yml")

    root = REPO / "compose.yml"
    if not root.is_file():
        rep.fail("root compose.yml not found")
        return

    resources = parse_compose_resources(root)
    if not resources:
        rep.fail("no services with cpus/mem_limit found in compose.yml")
        return

    for field in ("cpus", "mem_limit"):
        values = {svc: res[field] for svc, res in resources.items() if field in res}
        if not values:
            rep.fail(f"no service declares `{field}`")
            continue
        distinct = set(values.values())
        if len(distinct) == 1:
            rep.ok(
                f"{field}: all {len(values)} DB services = {next(iter(distinct))} "
                f"({', '.join(sorted(values))})"
            )
        else:
            rep.fail(
                f"{field} differs across DB services: "
                + ", ".join(f"{svc}={val}" for svc, val in sorted(values.items()))
            )


# --------------------------------------------------------------------------- #
# Check 3: benchmark parameters are the same for every database
# --------------------------------------------------------------------------- #
def extract_tcl_knobs(benchmark: str, db: str) -> dict[str, str] | None:
    """Extract fairness knobs from a HammerDB engine's build + run scripts.
    Returns None if the engine has no scripts for this benchmark."""
    bench_dir = REPO / "db" / db / benchmark
    if not bench_dir.is_dir():
        return None

    text = ""
    for tcl in sorted(bench_dir.glob("*.tcl")):
        text += "\n" + tcl.read_text()
    if not text.strip():
        return None

    found: dict[str, str] = {}
    for knob, pattern in TCL_KNOBS[benchmark].items():
        matches = re.findall(pattern, text)
        if matches:
            # All occurrences of a knob within one engine must agree, otherwise
            # the engine's own scripts are inconsistent.
            if len(set(matches)) > 1:
                found[knob] = f"<inconsistent:{','.join(matches)}>"
            else:
                found[knob] = matches[0]
    return found


def extract_xml_knobs(benchmark: str, db: str) -> dict[str, str] | None:
    """Extract fairness knobs from a BenchBase engine's XML config. Returns None
    if the engine has no config for this benchmark."""
    bench_dir = REPO / "db" / db / benchmark
    if not bench_dir.is_dir():
        return None

    configs = sorted(bench_dir.glob("*config*.xml"))
    if not configs:
        return None

    tree = ET.parse(configs[0])
    root = tree.getroot()

    found: dict[str, str] = {}
    for knob in XML_TOP_KNOBS:
        el = root.find(knob)
        if el is not None and el.text is not None:
            found[knob] = el.text.strip()
    work = root.find("./works/work")
    if work is not None:
        for knob in XML_WORK_KNOBS:
            el = work.find(knob)
            if el is not None and el.text is not None:
                found[knob] = el.text.strip()
    return found


def check_benchmark_params(rep: Reporter) -> None:
    rep.section("3. Benchmark parameters are equal across databases")

    for benchmark in BENCHMARKS:
        extractor = (
            extract_tcl_knobs if benchmark in HAMMERDB_BENCHMARKS else extract_xml_knobs
        )

        per_db = {}
        for db in DATABASES:
            knobs = extractor(benchmark, db)
            if knobs is None:
                continue
            per_db[db] = knobs

        print(f"\n  [{benchmark}] engines: {', '.join(per_db) or '(none found)'}")
        if not per_db:
            rep.warn(f"{benchmark}: no driver scripts found")
            continue

        all_knobs = sorted({k for knobs in per_db.values() for k in knobs})
        if not all_knobs:
            rep.warn(f"{benchmark}: no known fairness knobs found in driver scripts")
            continue

        for knob in all_knobs:
            present = {db: knobs[knob] for db, knobs in per_db.items() if knob in knobs}
            absent = [db for db in per_db if knob not in per_db[db]]
            distinct = set(present.values())

            if len(distinct) == 1 and not absent:
                rep.ok(f"{benchmark}.{knob} = {next(iter(distinct))} (all engines)")
            elif len(distinct) == 1 and absent:
                # Same value where defined, but some engines don't set it.
                rep.warn(
                    f"{benchmark}.{knob} = {next(iter(distinct))} but not set for: "
                    f"{', '.join(absent)}"
                )
            else:
                rep.fail(
                    f"{benchmark}.{knob} differs: "
                    + ", ".join(f"{db}={val}" for db, val in sorted(present.items()))
                    + (f" (absent: {', '.join(absent)})" if absent else "")
                )


def main() -> int:
    print(f"DBMS-bench consistency check — repo: {REPO}")
    rep = Reporter()

    check_compose_identical(rep)
    check_compose_resources(rep)
    check_benchmark_params(rep)

    print()
    if rep.failures:
        print(f"\033[31mFAILED: {len(rep.failures)} problem(s) found.\033[0m")
        if rep.warnings:
            print(f"({len(rep.warnings)} warning(s) — review but not fatal.)")
        return 1

    if rep.warnings:
        print(f"\033[32mOK\033[0m with {len(rep.warnings)} warning(s).")
    else:
        print("\033[32mAll checks passed.\033[0m")
    return 0


if __name__ == "__main__":
    sys.exit(main())
