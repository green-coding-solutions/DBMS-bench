#!/usr/bin/env python3
"""
check_repo.py — Consistency checks for the DBMS-bench repo.

The whole point of this repo is a *fair* comparison between database engines:
every engine has to run with the same resource budget and the same benchmark
parameters, otherwise the energy/throughput numbers are not comparable.

Because GMT refuses to `!include` a compose file from a parent directory, each
benchmark folder (``benchmarks/tpcc/``, ``benchmarks/tpch/``, ...) carries its
own copy of ``compose.yml`` next to the usage scenarios. Copies drift, so this
script enforces four invariants:

  1. Every ``compose.yml`` in the repo is byte-for-byte identical (the per-folder
     copies must match the root source of truth).
  2. Inside ``compose.yml`` every database service gets the same resource budget
     (``cpus`` and ``mem_limit``) — the load drivers are intentionally
     unconstrained and are skipped.
  3. For each benchmark, the per-engine driver scripts use the same fairness
     knobs (virtual users, scale factor, terminals, duration, ...) across all
     databases.
  4. For each engine, the T1 tuning payload is byte-for-byte identical across all
     benchmarks — comments included. T1 is hardware-sized and workload-agnostic
     (TUNING.md), so a per-benchmark difference is drift, and a *missing comment*
     is the provenance a reviewer needs to reproduce the number going missing.

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
        # differently in HammerDB: pg_/oracle's `degree_of_parallel`, and
        # MSSQL's `mssqls_maxdop` (MAXDOP) — the same fairness setting, so we
        # match either. maria/mysql/db2 have no such HammerDB knob (no parallel
        # query control there), so they legitimately never set it.
        "degree_of_parallel": r"(?:degree_of_parallel|mssqls_maxdop)\s+(\d+)",
    },
}

# Fairness knobs to extract from the BenchBase .xml configs. <time>/<rate>/
# <weights> live inside <works>/<work>; the rest are top-level.
XML_TOP_KNOBS = ["scalefactor", "terminals", "batchsize", "isolation"]
XML_WORK_KNOBS = ["time", "rate", "weights"]


def tier_of(path: Path) -> str:
    """Map a driver-script filename to its tuning tier via the dotted suffix
    before the extension: ``pg_tproch_run.tcl`` -> ``base``,
    ``pg_tproch_run.t2.tcl`` -> ``t2``, ``..._buildschema.t2col.tcl`` -> ``t2col``,
    ``pg_wikipedia_config.xml`` -> ``base``, ``..._config.t2.xml`` -> ``t2``.

    Tiers add driver-script variants that deliberately change tuning knobs (e.g.
    the parallel degree), so fairness knobs are compared WITHIN a tier across
    engines, never across tiers."""
    stem = path.name[: -len(path.suffix)] if path.suffix else path.name
    parts = stem.split(".")
    return parts[1] if len(parts) > 1 else "base"


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
def extract_tcl_knobs(benchmark: str, db: str, tier: str = "base") -> dict[str, str] | None:
    """Extract fairness knobs from a HammerDB engine's build + run scripts for one
    tuning tier. Returns None if the engine has no scripts for that tier."""
    bench_dir = REPO / "db" / db / benchmark
    if not bench_dir.is_dir():
        return None

    text = ""
    for tcl in sorted(bench_dir.glob("*.tcl")):
        if tier_of(tcl) != tier:
            continue
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


def extract_xml_knobs(benchmark: str, db: str, tier: str = "base") -> dict[str, str] | None:
    """Extract fairness knobs from a BenchBase engine's XML config for one tuning
    tier. Returns None if the engine has no config for that tier."""
    bench_dir = REPO / "db" / db / benchmark
    if not bench_dir.is_dir():
        return None

    configs = sorted(c for c in bench_dir.glob("*config*.xml") if tier_of(c) == tier)
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


def discover_tiers(benchmark: str, is_hammerdb: bool) -> list[str]:
    """Every tuning tier that has driver scripts for this benchmark, across all
    engines. 'base' is always first; the rest (t1, t2, t2col, ...) follow sorted."""
    pattern = "*.tcl" if is_hammerdb else "*config*.xml"
    tiers: set[str] = set()
    for db in DATABASES:
        bench_dir = REPO / "db" / db / benchmark
        if not bench_dir.is_dir():
            continue
        for f in bench_dir.glob(pattern):
            tiers.add(tier_of(f))
    tiers.discard("base")
    return ["base", *sorted(tiers)]


def check_benchmark_params(rep: Reporter) -> None:
    rep.section("3. Benchmark parameters are equal across databases (per tier)")

    for benchmark in BENCHMARKS:
        is_hammerdb = benchmark in HAMMERDB_BENCHMARKS
        extractor = extract_tcl_knobs if is_hammerdb else extract_xml_knobs

        for tier in discover_tiers(benchmark, is_hammerdb):
            per_db = {}
            for db in DATABASES:
                knobs = extractor(benchmark, db, tier)
                if knobs is None:
                    continue
                # A sub-tier (t2, t2col, ...) only restates the knobs it
                # re-tunes; everything else is inherited from the engine's base
                # tier. Most importantly build-phase knobs (e.g.
                # num_tpch_threads) live in the base buildschema and a run-only
                # sub-tier reuses them. Fill those in from base so we compare the
                # effective config, not just what the sub-tier happens to repeat.
                if tier != "base":
                    base = extractor(benchmark, db, "base")
                    if base is not None:
                        knobs = {**base, **knobs}
                per_db[db] = knobs

            label = benchmark if tier == "base" else f"{benchmark} [{tier}]"
            print(f"\n  [{label}] engines: {', '.join(per_db) or '(none found)'}")
            if not per_db:
                if tier == "base":
                    rep.warn(f"{label}: no driver scripts found")
                continue

            # A tier only one engine implements (e.g. columnar t2col on mssql) has
            # nothing to compare across engines — acknowledge and move on.
            if tier != "base" and len(per_db) == 1:
                rep.ok(f"{label}: only {next(iter(per_db))} implements this tier")
                continue

            all_knobs = sorted({k for knobs in per_db.values() for k in knobs})
            if not all_knobs:
                rep.warn(f"{label}: no known fairness knobs found in driver scripts")
                continue

            for knob in all_knobs:
                present = {db: knobs[knob] for db, knobs in per_db.items() if knob in knobs}
                absent = [db for db in per_db if knob not in per_db[db]]
                distinct = set(present.values())

                if len(distinct) == 1 and not absent:
                    rep.ok(f"{label}.{knob} = {next(iter(distinct))} (all engines)")
                elif len(distinct) == 1 and absent:
                    # Same value where defined, but some engines don't set it.
                    rep.warn(
                        f"{label}.{knob} = {next(iter(distinct))} but not set for: "
                        f"{', '.join(absent)}"
                    )
                else:
                    rep.fail(
                        f"{label}.{knob} differs: "
                        + ", ".join(f"{db}={val}" for db, val in sorted(present.items()))
                        + (f" (absent: {', '.join(absent)})" if absent else "")
                    )


# --------------------------------------------------------------------------- #
# Check 4: the T1 tuning payload is identical across benchmarks, per engine
# --------------------------------------------------------------------------- #
# The compose service that each engine's scenarios tune.
T1_SERVICE_OF = {
    "pg": "postgres",
    "maria": "mariadb",
    "mysql": "mysql",
    "oracle": "oracle",
    "mssql": "mssql",
    "db2": "db2",
}

# Db2 is the one engine whose *service* block legitimately varies per benchmark
# (it carries DBNAME=tpcc vs tpch), and whose flow-prepend names that database.
# So compare only its flow-prepend, with the database name normalised away.
T1_FLOW_ONLY = {"db2"}
T1_DBNAME_RE = re.compile(r"\b(?:tpcc|tpch)\b")


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def extract_t1_payload(benchmark: str, db: str) -> str | None:
    """Return the T1 *tuning payload* of benchmarks/<benchmark>/<db>.t1.yml as raw
    text: the engine's service block (with the comments that justify each knob),
    plus the `flow-prepend:` tuning step for engines that have no command-flag
    config (Oracle, Db2). None when the scenario does not exist.

    Everything else in the file — description, custom_metrics, which services are
    removed, the load driver, the `flow:` include — is benchmark-specific and is
    deliberately not compared. Raw text rather than parsed YAML, because the
    per-knob provenance comments are exactly what must not drift.
    """
    path = REPO / "benchmarks" / benchmark / f"{db}.t1.yml"
    if not path.is_file():
        return None

    lines = path.read_text().splitlines()
    chunks: list[str] = []

    if db not in T1_FLOW_ONLY:
        svc = T1_SERVICE_OF[db]
        si = next((i for i, l in enumerate(lines) if l.rstrip() == "services:"), None)
        if si is None:
            return None
        j = si + 1
        block: list[str] = []
        # the engine preamble: contiguous indent-2 comments right under `services:`
        while j < len(lines) and lines[j].startswith("  #"):
            block.append(lines[j])
            j += 1
        # the engine's own service key and its indented body (absent for Oracle,
        # which is kept as-is from compose.yml and tuned via flow-prepend)
        if j < len(lines) and lines[j].rstrip() == f"  {svc}:":
            block.append(lines[j])
            j += 1
            while j < len(lines) and (not lines[j].strip() or _indent(lines[j]) >= 4):
                block.append(lines[j])
                j += 1
        while block and not block[-1].strip():
            block.pop()
        chunks.append("\n".join(block))

    fi = next((i for i, l in enumerate(lines) if l.rstrip() == "flow-prepend:"), None)
    if fi is not None:
        start = fi
        while start - 1 >= 0 and lines[start - 1].startswith("#"):
            start -= 1
        end = fi + 1
        while end < len(lines) and (
            not lines[end].strip() or lines[end].startswith((" ", "\t"))
        ):
            end += 1
        block = lines[start:end]
        while block and not block[-1].strip():
            block.pop()
        chunks.append("\n".join(block))

    payload = "\n".join(c for c in chunks if c.strip())
    if db in T1_FLOW_ONLY:
        payload = T1_DBNAME_RE.sub("@DB@", payload)
    return payload or None


def check_t1_identical(rep: Reporter) -> None:
    rep.section("4. T1 tuning payload is identical across benchmarks (per engine)")

    for db in DATABASES:
        payloads = {
            b: p
            for b in BENCHMARKS
            if (p := extract_t1_payload(b, db)) is not None
        }
        if not payloads:
            rep.warn(f"{db}: no T1 scenarios found")
            continue
        if len(payloads) == 1:
            rep.ok(f"{db}.t1: only {next(iter(payloads))} ships this engine")
            continue

        groups: dict[str, list[str]] = {}
        for bench, payload in payloads.items():
            groups.setdefault(payload, []).append(bench)

        if len(groups) == 1:
            note = " (flow-prepend only; DBNAME normalised)" if db in T1_FLOW_ONLY else ""
            rep.ok(f"{db}.t1 = same tuning in {', '.join(sorted(payloads))}{note}")
            continue

        rep.fail(
            f"{db}.t1 tuning payload differs across benchmarks: "
            + " | ".join("{" + ", ".join(sorted(bs)) + "}" for bs in groups.values())
        )
        # Point at the first divergent line so the drift is actionable.
        ref_bench = sorted(payloads)[0]
        ref = payloads[ref_bench].splitlines()
        for bench in sorted(payloads):
            if bench == ref_bench:
                continue
            other = payloads[bench].splitlines()
            for n, (a, b) in enumerate(zip(ref, other), start=1):
                if a != b:
                    print(f"      {ref_bench} vs {bench}, first diff at payload line {n}:")
                    print(f"        - {a.strip()}")
                    print(f"        + {b.strip()}")
                    break
            else:
                if len(ref) != len(other):
                    print(
                        f"      {bench}: {len(other)} payload lines vs "
                        f"{len(ref)} in {ref_bench}"
                    )


def main() -> int:
    print(f"DBMS-bench consistency check — repo: {REPO}")
    rep = Reporter()

    check_compose_identical(rep)
    check_compose_resources(rep)
    check_benchmark_params(rep)
    check_t1_identical(rep)

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
