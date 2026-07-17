# DBMS-bench
A tool that benchmarks various DBMS systems agains each other and looks at energy usage

The `compose.yml` defines all the containers we want to use to benchmark. We use the std containers provided by the
various DBMS plus a load-driver container per benchmark family:

- [HammerDB](https://www.hammerdb.com/) drives the TPC-C and TPC-H benchmarks.
- [BenchBase](https://github.com/cmu-db/benchbase) (CMU; the maintained OLTP-Bench successor) drives the Wikipedia,
  YCSB and CH-benCHmark benchmarks. One image bakes in a distribution per engine, so the same driver runs every
  database in a benchmark — see [BenchBase setup](#benchbase-setup).

Currently we support:

- IBM Db2 (needs a one-time image build — see [Db2 setup](#db2-setup))
- MariaDB
- Microsoft SQL Server
- MySql
- Oracle Database Free
- PostgreSQL

The repo is split into two trees: `benchmarks/` holds the GMT usage scenarios (one folder per benchmark), and `db/`
holds the per-engine driver scripts (one folder per database engine).

For each DB vendor and benchmark we have a `benchmarks/<benchmark>/<db>.yml` (e.g. `benchmarks/tpcc/pg.yml`,
`benchmarks/tpch/oracle.yml`) that you can execute with the Green Metrics Tool to get energy readings. The driver's
per-DB scripts live under `db/<db>/<benchmark>/`: HammerDB TCL scripts for TPC-C/TPC-H (e.g. `db/pg/tpcc/`), BenchBase
config XMLs for Wikipedia/YCSB/CH-benCHmark (e.g. `db/pg/wikipedia/pg_wikipedia_config.xml`).

Each benchmark directory keeps its **own copy of `compose.yml`** (`benchmarks/tpcc/compose.yml`,
`benchmarks/tpch/compose.yml`, …): GMT's `!include` only resolves files inside the scenario's own directory, so
`!include ../compose.yml` is rejected. Treat the root `compose.yml` as the source of truth and re-sync the copies
whenever it changes:

```sh
for d in tpcc tpch wikipedia ycsb chbenchmark; do cp compose.yml "benchmarks/$d/compose.yml"; done
```

We currently run five benchmarks:

- [TPC-C](https://en.wikipedia.org/wiki/TPC-C) (HammerDB TPROC-C) — write-heavy OLTP; recorded metric is NOPM
- [TPC-H](https://en.wikipedia.org/wiki/TPC-H) (HammerDB TPROC-H) — analytical query workload; the SCI functional unit
  is the number of queries completed (i.e. carbon per query)
- [Wikipedia](https://github.com/cmu-db/benchbase) (BenchBase) — read-mostly web-serving workload over real Wikipedia
  article traces; the SCI functional unit is the number of requests completed
- [YCSB](https://github.com/cmu-db/benchbase) (BenchBase) — cloud key-value serving (point reads/writes/scans); the
  SCI functional unit is the number of requests completed
- [CH-benCHmark](https://github.com/cmu-db/benchbase) (BenchBase, composite `tpcc,chbenchmark`) — HTAP:
  TPC-C transactions and 22 TPC-H-style analytical queries run *concurrently* on one schema; the SCI functional unit is
  the number of requests completed (OLTP txns + OLAP queries — see the per-transaction CSVs to split them)

The three BenchBase benchmarks cover **5** engines — there is no Db2 BenchBase profile, so Db2 has TPC-C/TPC-H only.

## Tuning tiers

To study energy vs. tuning effort, each scenario comes in tiers. Tier files sit next to the default and share the
default's flow (only the *engine configuration* changes between tiers), so `run_on_cluster.py` discovers them
automatically:

- **T0 — default**: `benchmarks/<benchmark>/<db>.yml` (stock container).
- **T1 — envelope-sized**: `benchmarks/<benchmark>/<db>.t1.yml` — each vendor's own rules-of-thumb sized to the fixed
  4-CPU / 8-GB container; durability left at default so the T0→T1 delta is pure resource sizing.

```sh
# default vs. envelope-sized, Postgres TPC-C
./run_on_cluster.py --machine-id N --filter 'tpcc/pg.yml'
./run_on_cluster.py --machine-id N --filter 'tpcc/pg.t1.yml'
./run_on_cluster.py --machine-id N -t 0                    # every T0 scenario
./run_on_cluster.py --machine-id N -t 1                    # every T1 scenario
./run_on_cluster.py --machine-id N -t 0 -n                 # preview without submitting
```

See [TUNING.md](TUNING.md) for per-engine settings, provenance, threats to validity (Oracle Free / Db2 Community
edition caps, OOM headroom, Oracle/Db2 verify-on-first-run), and the planned T2 (advisor) and T3 (auto-tuner) tiers.

## Db2 setup

Db2 needs a one-time prep the other engines don't. The `tpcorg/hammerdb` image has no Db2 client, and
HammerDB's `db2tcl` binding needs the *full* Db2 client (the free CLI driver lacks the `sqlefrce_api`
symbol). HammerDB also talks to Db2 through a *catalogued* database, so the client needs a real Db2
instance. `db/db2/build-image.sh` handles this: it lifts the Db2 install + an initialised client instance out
of the `icr.io/db2_community/db2` image and bakes them onto the hammerdb (Ubuntu) base, then pushes the
result to Docker Hub as `ribalba/hammerdb-db2`, which the Db2 usage scenarios reference.

Before running the Db2 scenarios (one-time):

```sh
docker login                 # as the account that owns the image (ribalba)
./db/db2/build-image.sh      # builds and pushes ribalba/hammerdb-db2:latest
```

Notes:

- The Db2 server container requires `privileged: true`, and the host must allow it.
- Db2 is slow to start (minutes) and loads via INSERTs, so it builds slower than the bulk-loaded engines.

## BenchBase setup

The Wikipedia, YCSB and CH-benCHmark scenarios are driven by a `benchbase` container. BenchBase builds one
self-contained distribution per database (each bundles that engine's JDBC driver), so `benchmarks/benchbase/build-image.sh` builds
every engine's profile into a single image and pushes it to Docker Hub as `ribalba/benchbase:latest`, which the
scenarios pull. Each profile lands in `/benchbase/benchbase-<profile>/` and the scenario `cd`s into the right one.

Before running the Wikipedia/YCSB/CH-benCHmark scenarios (one-time):

```sh
docker login                                   # as the account that owns the image (ribalba)
./benchmarks/benchbase/build-image.sh                      # builds + pushes ribalba/benchbase:latest
BENCHBASE_REF=<commit-sha> ./benchmarks/benchbase/build-image.sh   # pin a commit for a reproducible paper build
```

Notes:

- Each scenario runs three flow steps: create the `benchbase` database/user on the DB container, then BenchBase
  `--create --load` (schema + data), then `--execute` (the measured run). The functional-unit metric
  (`wikipedia_requests` / `ycsb_requests` / `chbenchmark_requests`) is parsed from BenchBase's `measuredRequests` on
  the execute step.
- CH-benCHmark is the composite `-b tpcc,chbenchmark` with a single config: the `tpcc` plugin supplies the OLTP schema
  and transactions, the `chbenchmark` plugin adds the TPC-H tables and the 22 analytical queries. OLTP and OLAP run in
  *separate terminal pools* (`<terminals bench="tpcc">` vs `<terminals bench="chbenchmark">`) — that split is the HTAP
  knob. The execute step reports one combined `measuredRequests`; for the OLTP-vs-OLAP breakdown read BenchBase's
  per-transaction `results/*.results.<Txn>.csv` files (TPC-C's five vs `Q1`…`Q22`).
- The workload (scalefactor, terminals, isolation, weights) is fixed in `db/<db>/<benchmark>/<db>_<benchmark>_config.xml`
  so only the *database* configuration is the variable when comparing default vs. tuned. Defaults: Wikipedia
  `scalefactor=10`, YCSB `scalefactor=1000` (≈1 GB), CH-benCHmark `scalefactor=10` (TPC-C warehouses, ≈1 GB) — all
  deliberately larger than default buffer pools so tuning shows.
- BenchBase requires Java 23 to build; the image handles this. It has no Db2 profile.

## Some background reading

- https://www.hammerdb.com/about.html
- https://www.hammerdb.com/blog/uncategorized/how-to-deploy-hammerdb-cli-fast-with-docker/
- https://www.tpc.org/tpcc/default5.asp
- https://www.hammerdb.com/blog/uncategorized/how-to-run-a-fixed-throughput-workloads/
- https://github.com/cmu-db/benchbase (BenchBase)
- OLTP-Bench paper (BenchBase lineage): https://www.vldb.org/pvldb/vol7/p277-difallah.pdf
- CH-benCHmark paper (Cole et al., DBTest 2011): https://doi.org/10.1145/1988842.1988850
