# Tuning tiers

This repo measures DBMS energy with a **standardised, symmetric optimisation
procedure** rather than a hand-picked per-engine optimum. The thing we hold
constant across engines is the *procedure* (same objective, same search space,
same budget, same fixed resource envelope), so the comparison survives the
"you tuned engine X better than engine Y" critique. Each step up the ladder is
reproducible because it is mechanical or algorithmic, not artisanal.

## The ladder

| Tier | Name | What changes | Status |
|------|------|--------------|--------|
| **T0** | Default / out-of-the-box | Stock container, nothing tuned but what's needed to run | shipped (`benchmarks/<bench>/<db>.yml`) |
| **T1** | Envelope-sized | Each vendor's own rules-of-thumb, evaluated at the engine's effective limit `M` (see "How each T1 number is derived") | shipped (`benchmarks/<bench>/<db>.t1.yml`) |
| **T2** | Workload-aware | Indexes / partitioning / parallelism + curated config (+ native advisors where usable) | **shipped** — all 5 benchmarks (29 `.t2`/`.t2col` files) |
| **T2+** | Columnar sub-tier | Best-per-engine columnar (SQL Server columnstore, Db2 BLU) on the analytical benchmarks | shipped (TPC-H `mssql.t2col`, `db2.t2col`) |
| **T3** | Auto-tuned | One black-box optimiser (e.g. Optuna TPE) over the common knob space, fixed trial budget, objective = energy | planned |

Reporting energy at every rung gives the paper an effort-attribution story:
*how much energy each level of tuning effort actually buys.*

T1 currently ships for **all five benchmarks** — TPC-C, TPC-H (HammerDB, 6 engines incl. Db2) and Wikipedia, YCSB,
CH-benCHmark (BenchBase, 5 engines; no Db2 profile) — i.e. 27 `*.t1.yml` files. The engine config for a given engine is
the same across all five (T1 is hardware-sized), so only the metric and the shared flow differ per file.

## Objective function

Primary: **energy per unit of work** — Joules per TPC-C SQL-op (NOPM-derived),
per TPC-H query, and per Wikipedia/YCSB/CH-benCHmark request (BenchBase
`measuredRequests`; for CH-benCHmark that count is OLTP txns + OLAP queries).
This is already the SCI functional unit in each scenario. Always **integrate
power over the whole run**; never compare on peak watts or wall-clock alone
(race-to-idle makes both misleading).

Measure both meters and report both:

- **Wall / full-system meter** — the honest total; **T3 optimises against this.**
- **RAPL (CPU+DRAM)** — blind to storage and NIC energy. Track the wall/RAPL
  ratio per engine and tier: the gap is the energy invisible to CPU-only
  telemetry and is expected to be largest for I/O-bound TPC-H.

## Fixed envelope

Every engine container gets `cpus: 4` and `mem_limit: 8g` (see `compose.yml`).
T1 sizes each engine to use *that* envelope well — memory is sized **relative to
the container's cgroup limit, not host RAM**, because a buffer above the cgroup
limit triggers OOM-kill / swap and wrecks the energy numbers.

One engine cannot actually reach that envelope, and this matters more than any
individual knob value: **Oracle Database Free is licence-capped at ~2 GB of
database RAM (SGA+PGA) and 2 CPU threads.** Every other engine fits — Db2
Community (16 GB / 4 cores), SQL Server Developer (full), and PostgreSQL / MySQL
/ MariaDB (unrestricted). So define the **effective memory limit**

> `M = min(8 GB cgroup, edition cap)` → 8 GB for every engine except Oracle Free, where `M = 2 GB`.

Every T1 memory number is a vendor rule-of-thumb evaluated at `M`. **The quantity
held constant across engines is the procedure — rule applied to `M` — not the
resulting byte counts.** Two engines landing on different numbers is the expected
output of the procedure, not evidence that it was applied unevenly.

## T1 settings and provenance

T1 is **hardware-sized and workload-agnostic** — the same engine config is used
for TPC-C and TPC-H (the `.t1.yml` files for a given engine are identical except
for the metric and the included flow; `check_repo.py` check 4 enforces this,
comments included). Workload specialisation is deferred to T2.
**Durability is left at each engine's default** (e.g. PostgreSQL
`synchronous_commit=on`, InnoDB `flush_log_at_trx_commit=1`) so the T0→T1 delta
is pure resource sizing, not a safety trade.

| Dimension | PostgreSQL | MySQL / MariaDB | SQL Server | Oracle Free | Db2 |
|-----------|-----------|------------------|------------|-------------|-----|
| Buffer / cache | `shared_buffers=2GB` (25%) + `effective_cache_size=6GB` | `innodb_buffer_pool_size=5G` (~62%) | `MSSQL_MEMORY_LIMIT_MB=5120` (max server memory) | `sga_target=1300M` (capped, see below) | STMM auto within instance memory |
| Work / sort mem | `work_mem=16MB`, `maintenance_work_mem=512MB` | n/a (server-managed) | (auto) | `pga_aggregate_target=500M` | `SORTHEAP/SHEAPTHRES_SHR AUTOMATIC` |
| Parallelism | `max_parallel_workers=4`, `..._per_gather=2` | (limited) | deferred to T2 (MAXDOP) | capped at 2 threads | (STMM / default) |
| Redo / WAL | `max_wal_size=4GB`, `wal_buffers=16MB` | `innodb_redo_log_capacity=2G` (MySQL) / `innodb_log_file_size=2G` (MariaDB) | default | default | default |
| Storage I/O | `random_page_cost=1.1`, `effective_io_concurrency=200` | `innodb_flush_method=O_DIRECT`, `innodb_io_capacity(_max)=2000/4000` | default | default | default |

Rules-of-thumb follow each vendor's published guidance (PostgreSQL 25%/75%
shared_buffers/effective_cache_size, the PGTune "OLTP" profile shape; InnoDB
buffer pool 50–75% of RAM with O_DIRECT; SQL Server "max server memory" leaving
~25–35% for the OS/SQLOS).

### Why the T1 files look so different from each other

Opening `<bench>/mysql.t1.yml` next to `<bench>/oracle.t1.yml` shows a nine-line
list of `--innodb-*` flags beside a retrying `sqlplus` script. That is the most
divergent pair in the repo, and **three independent things vary between them** —
only the third is about tuning at all:

1. **Knob namespace.** There is no cross-engine "buffer pool size" knob, because
   the caches are not the same object. InnoDB with `O_DIRECT` bypasses the OS
   page cache, so its buffer pool *is* the only cache and takes ~62% of `M`
   directly. PostgreSQL reads *through* the page cache, so its vendor rule is a
   25% `shared_buffers` plus a 75% `effective_cache_size` — the latter is a
   **planner hint describing memory Postgres does not allocate.** Db2 exposes no
   number at all; STMM sizes it at runtime. Forcing these to the same literal
   would be the actual methodological error: `shared_buffers=5GB` would
   double-buffer against the page cache and perform *worse*.
2. **Injection mechanism.** PostgreSQL / MySQL / MariaDB accept `-c key=val` on
   the entrypoint; SQL Server takes an env var; Oracle and Db2 expose no
   command-flag config at all and need a `flow-prepend:` step running
   `ALTER SYSTEM` / `db2 update db cfg`. Pure plumbing, zero methodology — see
   "How T1 is injected per engine" below.
3. **Effective limit `M`.** Oracle Free is sized against its 2-GB licence cap,
   every other engine against the 8-GB cgroup. This is the one difference that
   genuinely threatens comparability, and it is a property of the *edition*, not
   of how hard we tuned. See "Threats to validity".

### How each T1 number is derived

Every literal in every `*.t1.yml` is recomputable from `(M, cores) = (8 GB, 4)` —
or `(2 GB, 2)` for Oracle Free — plus the vendor's published rule. Nothing below
was hand-picked or search-tuned; there is no per-engine trial-and-error in T1
(that is what T3 is for).

| Engine | `M` | Vendor rule | Arithmetic | Literal in `*.t1.yml` |
|--------|-----|-------------|-----------|----------------------|
| PostgreSQL | 8 GB | `shared_buffers` = 25% of RAM; `effective_cache_size` = 75% (planner hint, not an allocation) | 0.25 × 8 GB; 0.75 × 8 GB | `shared_buffers=2GB`, `effective_cache_size=6GB` |
| MySQL | 8 GB | InnoDB buffer pool 50–75% of RAM under `O_DIRECT` (sole cache) | 0.625 × 8 GB (mid-band) | `innodb_buffer_pool_size=5G` |
| MySQL | 8 GB | ≥ 1 GB per buffer-pool instance | 5 G ÷ 4 = 1.25 GB each | `innodb_buffer_pool_instances=4` |
| MariaDB | 8 GB | same InnoDB rule (instances are a no-op on modern MariaDB) | 0.625 × 8 GB | `innodb_buffer_pool_size=5G` |
| SQL Server | 8 GB | "max server memory", leaving 25–35% to OS/SQLOS | 0.625 × 8192 MB, leaving **37.5%** ¹ | `MSSQL_MEMORY_LIMIT_MB=5120` |
| Oracle Free | **2 GB** | fill the licensed database RAM, keeping headroom; SGA:PGA ≈ 70:30 mixed | 1300 + 500 = 1800 MB of 2048 MB (~88%, ~250 MB headroom) | `sga_target=1300M`, `pga_aggregate_target=500M` |
| Db2 | 8 GB | leave STMM on, memory areas `AUTOMATIC` | none — sized at runtime ² | `SELF_TUNING_MEM ON`, `DATABASE_MEMORY/SORTHEAP/SHEAPTHRES_SHR AUTOMATIC` |

Core-derived and storage-derived knobs use the same treatment: parallelism is set
to the 4-core count (`max_worker_processes=4`, `max_parallel_workers=4`), and all
engines assume the same SSD-class storage (`random_page_cost=1.1`,
`effective_io_concurrency=200`, `innodb_io_capacity=2000/4000`).

**Deviations, stated explicitly** (a reviewer should be able to find every place
the arithmetic does *not* follow the vendor band):

- ¹ **SQL Server leaves 37.5%, not the recommended 25–35%.** Deliberate: the
  vendor band assumes a host that swaps under pressure, whereas a hard cgroup
  limit turns an over-commit into a silent OOM-kill that ruins the run.
- ² **Db2 has no derivable literal** because its vendor rule *is* "leave it
  automatic". The one lever that would pin STMM to the cgroup (`INSTANCE_MEMORY`)
  requires an instance restart and ships commented-out and opt-in.
- **Oracle sizes to 88% of `M`, not ~62%.** Its 2-GB cap applies to SGA+PGA only
  (process and OS overhead sit outside it), so the fraction is not comparable
  with the InnoDB/SQL Server percentages, which are fractions of a cgroup that
  must *also* hold the server process.

### How T1 is injected per engine

- **PostgreSQL / MySQL / MariaDB** — config flags passed via the service
  `command:` (the official entrypoints forward `-c key=val` / `--key=val`).
  *Verified locally: each image boots to "ready to accept connections" with the
  exact T1 flags.*
- **SQL Server** — `max server memory` via the `MSSQL_MEMORY_LIMIT_MB` env var.
- **Oracle / Db2** — no command-flag config, so a `flow-prepend:` step runs
  `ALTER SYSTEM` (Oracle, in `oracle_container`) / `db2 update db cfg` (Db2, in
  `db2_container`) before the workload. These steps retry until the DB answers,
  echo the applied config to stdout, and never fail the run.

## T2 settings and provenance

T2 is **workload-aware** and builds on T1. Per the chosen policy it has two
sub-tiers: **T2 (common)** = same logical row-store design for every engine;
**T2+ (columnar)** = the strongest columnar design each capable engine offers, on
the analytical benchmarks only. Tuning is **curated workload-aware best-practice
for all engines, plus each engine's native advisor where one runs** (see table).

T2 touches **three injection points** (vs T1's single config point):

1. **DB config** (same mechanism as T1). OLAP (TPC-H, CH-benCHmark): large
   `work_mem`/sort memory, per-query parallelism = core count, higher statistics
   target, JIT. OLTP/serving (TPC-C, YCSB, Wikipedia): mostly T1 + stats, small
   deltas. *Verified: the pg OLAP config boots.*
2. **Driver settings** — HammerDB `*.t2.tcl` / `*.t2col.tcl` script variants
   (`db/<db>/<bench>/`): parallel degree / MAXDOP raised to the 4-core count;
   columnstore (`mssqls_colstore true`) for T2+. BenchBase has no driver knobs to
   vary (the workload is fixed in the XML), so its T2 is config-only for
   Wikipedia/YCSB and config-only HTAP balancing for CH-benCHmark.
3. **Post-load "optimize" step** — a mid-flow step in the DB container (after the
   load, before the measured run): `ANALYZE` / `UPDATE STATISTICS` / `runstats`,
   curated indexes, and the native advisor where available. This is used where
   the benchmark has a shipped post-load DDL/statistics step; config-only T2
   scenarios keep the base `flow:` include.

**Parallelism is treated as a per-tier-fair tuning lever**, not a fixed fairness
invariant: every engine's T2 uses degree = core count, so the comparison stays
fair *within* the tier. `check_repo.py` was made **tier-aware** (it buckets driver
scripts by the filename suffix — `base`/`t1`/`t2`/`t2col` — and checks fairness
knobs within each tier) so raising the degree in T2 no longer trips it.

File naming: `benchmarks/<bench>/<db>.t2.yml` (common), `…<db>.t2col.yml`
(columnar); driver variants `…_<role>.t2.tcl` / `…_<role>.t2col.tcl`.

**Native advisor availability (Linux containers):**

| Engine | Native advisor | Usable here? |
|--------|----------------|--------------|
| PostgreSQL | none built-in | curated only |
| MySQL / MariaDB | MySQLTuner (config) | yes (perl script) |
| SQL Server | Database Engine Tuning Advisor | **no — Windows-only** → curated only |
| Oracle Free | SQL Tuning Advisor / ADDM | **no — Tuning Pack + Free caps** → curated only |
| Db2 | `db2advis` (Design Advisor) | yes (CLP) |

**Columnar (T2+) support:** SQL Server clustered columnstore — shipped (TPC-H);
Db2 BLU column-organized — planned; PostgreSQL / MySQL / MariaDB / Oracle Free —
none in core/edition, so they get the row-store T2 only.

**Shipped & validated across the matrix** — 29 `.t2`/`.t2col` files; all 83
scenarios pass GMT's SchemaChecker and `check_repo.py` (tier-aware); the pg OLAP
config boots; TCL variants diff cleanly from the working T0.

- **TPC-H** (analytical, the lever-rich tier): pg/maria/mysql/oracle/db2 T2
  (OLAP config; degree=4 where the engine parallelises — pg, oracle; MySQL/MariaDB
  use big session buffers instead; a post-load optimize step adds curated indexes +
  stats) and **T2+ columnar** for SQL Server (columnstore) and Db2 (BLU).
- **TPC-C** (OLTP): config-only T2 (pg aggressive autovacuum; MySQL/MariaDB
  write-path tuning), shares the T0 flow.
- **Wikipedia / YCSB** (serving) & **CH-benCHmark** (HTAP): config-delta T2
  (CH gets OLAP-leaning config), shares the T0 flow.

What's intentionally **thin or deferred** (honest findings, documented per file):

- **OLTP/serving T2 ≈ T1 for SQL Server / Oracle Free / Db2** — those engines have
  no injectable workload-specific lever there (SQL Server config needs `sqlcmd`,
  absent in the Linux image; Oracle Free is capped; Db2 already self-tunes).
- **CH-benCHmark columnar** (SQL Server NCCI) is **deferred** — creating it
  post-load needs `sqlcmd`, which the image lacks.
- **Native advisor steps** (`db2advis`, MySQLTuner) are **not yet wired in** — they
  remain the documented next supplement; current T2 is curated tuning.

⚠️ VERIFY-on-first-run items (all optimize steps are non-fatal so they can't break
a run): the curated `CREATE INDEX` names assume HammerDB's standard TPC-H schema;
Oracle/Db2 optimize + Db2 BLU enablement (`DB2_WORKLOAD=ANALYTICS` + restart)
could not be exercised offline. Check each "Optimize schema"/"Tune"/"Enable" step's
stdout in the run log.

## Threats to validity / caveats

- **Edition caps confound cross-engine comparison — this is the headline caveat.**
  Oracle Database **Free** is licence-capped at ~**2 GB RAM / 2 CPU threads** — it
  *cannot* use the 8-GB / 4-CPU envelope, so its T0→T1 delta will be small (near
  noise) and its **absolute J/op is not comparable on equal-hardware terms** with
  the other engines. This, not the differing knob values, is the real limit on
  cross-engine comparability: the tuning *procedure* is uniform (see "How each T1
  number is derived"), but Oracle's effective limit `M` is 4× smaller. Db2
  **Community** (16 GB / 4 cores) and SQL Server **Developer** (full) fit the
  envelope; PostgreSQL/MySQL/MariaDB are unrestricted. Disclose this in the paper,
  and prefer within-engine T0→T1→T2 deltas over cross-engine absolutes wherever
  Oracle Free is in the comparison.
- **Oracle / Db2 T1 are best-effort and need one VERIFY run.** Could not be
  executed offline. Check the "Tune …" flow step's stdout in the run log to
  confirm the parameters actually applied:
  - Oracle: under Automatic Memory Management (`memory_target>0`) the SGA/PGA
    `ALTER`s are skipped (would need a restart).
  - Db2: default already self-tunes (STMM). The meaningful envelope lever —
    capping `INSTANCE_MEMORY` to the cgroup so STMM doesn't size against
    mis-detected host RAM — needs an instance restart and is left as a commented,
    opt-in block in `*/db2.t1.yml`.
- **OOM risk.** With a hard cgroup limit, an oversized buffer triggers an
  OOM-kill that silently ruins a run. If MySQL/MariaDB/MSSQL get killed, drop the
  buffer to ~4 G / 4096 MB.
- **Idle load-driver container.** The unused driver is left running in some
  scenarios — `benchbase` idles in the HammerDB TPC-C/TPC-H scenarios (they don't
  remove it). It adds a small constant to every such measurement: it cancels in
  the T0→T1 delta but inflates absolute numbers. Add an empty `benchbase:` key to
  those scenarios if absolute energy matters.
- **`compose.yml` is duplicated** into every benchmark dir (`benchmarks/tpcc/`,
  `benchmarks/tpch/`, `benchmarks/wikipedia/`, `benchmarks/ycsb/`,
  `benchmarks/chbenchmark/`) because GMT only allows `!include` of files in the
  scenario's own directory (it rejects `../compose.yml`). Treat the root
  `compose.yml` as the source of truth and keep the copies in sync:
  `for d in tpcc tpch wikipedia ycsb chbenchmark; do cp compose.yml "benchmarks/$d/compose.yml"; done`
  (`check_repo.py` enforces they stay byte-identical).

## Running a tier

Scenarios are auto-discovered by `run_on_cluster.py`; filter by tier:

```sh
# Postgres TPC-H across tiers: default -> envelope -> workload-aware
./run_on_cluster.py --machine-id N -t 0 --filter 'tpch/pg.yml'
./run_on_cluster.py --machine-id N -t 1 --filter 'tpch/pg.t1.yml'
./run_on_cluster.py --machine-id N -t 2 --filter 'tpch/pg.t2.yml'

# every T2/T2+ scenario, or just the columnar sub-tier
./run_on_cluster.py --machine-id N -t 2
./run_on_cluster.py --machine-id N --filter 'benchmarks/*/*.t2col.yml'

# preview selected runs without submitting
./run_on_cluster.py --machine-id N -t 0 -n
```

## Roadmap

- **T2** — see "T2 settings and provenance" above: reference shipped for TPC-H
  (pg + mssql, common + columnar); remaining engines/benchmarks per the scale-out
  plan there.
- **T3** — one Optuna/SMAC loop over the common knob space, objective = wall-meter
  J/op, fixed trial budget per (engine × benchmark), reusing the GMT submit
  `APIClient` from `run_on_cluster.py`. Because each trial is a full cluster run
  (git-gated, async, minutes each), use a sample-efficient optimiser and a small
  (~8–12 knob) search space.
