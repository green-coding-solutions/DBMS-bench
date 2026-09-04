# DBMS-bench
A tool that benchmarks various DBMS systems agains each other and looks at energy usage

The `compose.yml` defines all the containers we want to use to benchmark. We use the std containers provided by the
various DBMS plus a load-driver container per benchmark family:

- [HammerDB](https://www.hammerdb.com/) drives the TPC-C and TPC-H benchmarks.
- [BenchBase](https://github.com/cmu-db/benchbase) (CMU; the maintained OLTP-Bench successor) drives the Wikipedia,
  YCSB and CH-benCHmark benchmarks. One image bakes in a distribution per engine, so the same driver runs every
  database in a benchmark — see [BenchBase setup](#benchbase-setup).

Currently we support:

- CockroachDB (BenchBase benchmarks only — see [CockroachDB support](#cockroachdb-support))
- IBM Db2 (needs a one-time image build — see [Db2 setup](#db2-setup))
- MariaDB
- Microsoft SQL Server
- MySql (needs an auth-cache warmup — see [MySQL authentication](#mysql-authentication))
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

### Image tags

Every image is on a **floating tag** (`:latest`), not a pinned digest or patch version. The scenarios are scheduled
weekly in the [GMT watchlist](https://metrics.green-coding.io/watchlist.html), GMT re-pulls the tag on every run, and
it records the resolved image and the installed OS/DB packages alongside the measurement — so the version under test
is captured *in the run*, which is where it is actually needed, instead of being frozen in this repo by a stream of
Dependabot commits.

Every database image floats, MySQL included. That needed one extra step to keep HammerDB working — see
[MySQL authentication](#mysql-authentication).

The one exception is not a measured image at all: `benchmarks/benchbase/Dockerfile` builds on a pinned
`eclipse-temurin:23-jdk`. That is a build-time toolchain, and `eclipse-temurin:latest` (JDK 25+) does not build
BenchBase — its `fmt-maven-plugin` (google-java-format) reaches into internal javac APIs and fails with
`NoSuchMethodError`. See the comment in that Dockerfile.

Because the tags float, **runs are not reproducible across weeks by construction** — that is deliberate for the
watchlist trend, but for a paper build pin the tags (and `BENCHBASE_REF`) on a branch first.

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

### Engine / benchmark coverage

Not every engine runs every benchmark. What exists today:

| Engine | TPC-C (HammerDB) | TPC-H (HammerDB) | Wikipedia | YCSB | CH-benCHmark |
|---|---|---|---|---|---|
| PostgreSQL | ✅ | ✅ | ✅ | ✅ | ✅ |
| MariaDB | ✅ | ✅ | ✅ | ✅ | ✅ |
| MySQL | ✅ | ✅ | ✅ | ✅ | ✅ |
| Oracle Free | ✅ | ✅ | ✅ | ✅ | ✅ |
| SQL Server | ✅ | ✅ | ✅ | ✅ | ✅ |
| Db2 | ✅ | ✅ | ❌ no profile | ❌ | ❌ |
| CockroachDB | ❌ see below | ❌ see below | ⚠️ loader hangs | ✅ | ✅ schema only |

Db2 has no BenchBase profile upstream, so it is TPC-C/TPC-H only. The CockroachDB ❌/⚠️ is explained below.

## CockroachDB support

CockroachDB is PostgreSQL-wire compatible, so it needs no driver of its own: BenchBase drives it through its
upstream `COCKROACHDB` profile (which reuses `org.postgresql.Driver`) on port 26257.

**The BenchBase image must be rebuilt** before the CockroachDB scenarios can run — `cockroachdb` was added to
`BENCHBASE_PROFILES`, and the published `ribalba/benchbase:latest` predates it. See
[BenchBase setup](#benchbase-setup).

**It runs as a secure node, not `--insecure`.** The `cockroach` service in `compose.yml` generates self-signed
certs on boot and starts with `--accept-sql-without-tls`, then sets a root password and writes a readiness flag
that the healthcheck waits on. `--accept-sql-without-tls` is the important part: it keeps the SQL session on
plaintext TCP like every other engine here, so TLS on a single engine does not skew the energy comparison,
while still allowing normal password auth.

**Neither HammerDB benchmark works on CockroachDB**, which is why there is no `benchmarks/tpcc/cockroach.yml`
or `benchmarks/tpch/cockroach.yml`. Both get all the way through loading their data and then fail on DDL that
CockroachDB does not implement:

- **TPC-C** — HammerDB emits the transaction bodies as PL/pgSQL functions using the old `DECLARE x ALIAS FOR $1`
  form:

  ```
  Vuser 1:CREATING TPCC FUNCTIONS
  Error in Virtual User 1: ERROR:  at or near "$": syntax error
  ```

  Not a configuration problem: `pg_storedprocs false` only changes what the *driver* calls at run time, the
  build creates the functions either way.

- **TPC-H** — HammerDB creates the tables with nullable columns and adds the primary keys afterwards. PostgreSQL
  implicitly promotes such a column to `NOT NULL`; CockroachDB refuses:

  ```
  Vuser 1:CREATING TPCH INDEXES
  Error in Virtual User 1: ERROR:  cannot use nullable column "r_regionkey" in primary key
  ```

Fixing either would mean patching HammerDB's own schema DDL, so CockroachDB is BenchBase-only for now.
TPC-C-style OLTP coverage still exists through CH-benCHmark, which runs the composite `tpcc,chbenchmark`
workload — but those are BenchBase requests, not HammerDB NOPM, so they are **not** comparable with the other
engines' TPC-C numbers.

**Verification status (2026-09-03, CockroachDB v26.2.6).** YCSB is confirmed end to end: schema created, ~1M
rows loaded, the 60 s measured run completed and the scenario's `measuredRequests` parse produced
`ycsb_requests=187406`. CH-benCHmark's schema (`-b tpcc,chbenchmark --create`, 12 tables) builds cleanly, but its
load and measured run have not been exercised yet. **Wikipedia does not currently complete**: the schema builds
and the loader gets through `page`, `text`/`revision` and part of `watchlist`, then deadlocks — every database
session closes, the JVM sits at ~0 % CPU and no error is printed. That is worth a look before trusting
`benchmarks/wikipedia/cockroach.yml`; the other two are the ones to run first.

**One cluster setting is raised at boot.** `sql.conn.max_read_buffer_message_size` goes from its 16 MiB default
to 64 MiB, because BenchBase's Wikipedia loader batches 128 rows of real article text into a single `INSERT` and
overruns it — the load dies with `Batch entry 4 INSERT INTO text ...`. That is a wire-protocol ceiling rather
than a performance knob; the alternative would be shrinking `<batchsize>` for CockroachDB alone, which
`check_repo.py` rejects because it would make the workload different from every other engine's.

Also note the BenchBase configs use `TRANSACTION_READ_COMMITTED` like every other engine, not the
`SERIALIZABLE` of CockroachDB's own sample configs — READ COMMITTED has been available since v23.2 and is
enabled by default (verified on v26.2), which keeps the cross-engine comparison honest.

## MySQL authentication

MySQL is on `mysql:latest` (currently 26.7) like everything else. MySQL 9.0 removed
`mysql_native_password`, so every account now uses `caching_sha2_password`, which **refuses to authenticate
over a plaintext connection**:

```
Error in Virtual User 1: mysqlconnect/db server: Authentication plugin 'caching_sha2_password'
reported error: Authentication requires secure connection.
```

BenchBase never noticed — its JDBC driver negotiates `caching_sha2_password` fine — but it stopped HammerDB
dead, because the bundled `mysqltcl` has no RSA key-exchange path (no `--get-server-public-key`).

**The fix, in one line: prime the server's password cache once over TLS, then everything else works over
plaintext.** `caching_sha2_password` has two modes. Full authentication needs a secure channel (TLS) or RSA
key exchange. But once the server has the password in its in-memory cache, *fast* authentication kicks in — a
plain challenge/response scramble that is safe, and allowed, over an unencrypted connection. So the `mysql`
service in `compose.yml` runs a `setup-commands` block that makes exactly one TLS connection per account before
the benchmark starts:

```yaml
setup-commands:
  - shell: bash
    command: |
      timeout 300 bash -c "until mysqladmin ping -h 127.0.0.1 -uroot -pmysql --silent >/dev/null 2>&1; do sleep 2; done"
      MYSQL_PWD=mysql mysql -h mysql_container --protocol=TCP -uroot --ssl-mode=REQUIRED -e "SELECT 1" >/dev/null
      MYSQL_PWD=mysql mysql -h mysql_container --protocol=TCP -umysql --ssl-mode=REQUIRED -e "SELECT 1" >/dev/null
```

Why it is built this way:

- **Two accounts.** TPC-C connects as `mysql`, TPC-H as `root` (see `db/mysql/*/`), and the cache is per
  account, so both are primed. As it happens `root` is usually already cached because the image's own
  entrypoint authenticates as root during initialisation — but relying on that would be fragile.
- **Not `127.0.0.1`.** The warmup connects to `mysql_container`, its own network name. `root` exists as both
  `root@localhost` and `root@'%'`; a loopback connection matches the *localhost* account and would prime the
  wrong cache entry.
- **`setup-commands`, not a flow step.** These run before the measured flow, so MySQL keeps exactly the same
  phase structure as every other engine. They run right after `docker run` and *before* the healthcheck, which
  is why the explicit wait loop is there. Cost is about 8 s on a cold container.
- **The measured workload is still plaintext.** TLS is used only for the one-connection warmup, so MySQL is
  measured over plaintext TCP exactly like every other engine and the energy comparison stays honest. This is
  the reason for preferring the cache warmup over simply turning on `mysql_ssl` in the HammerDB scripts.

The cache lives in memory and is dropped by a server restart or `FLUSH PRIVILEGES`. Neither happens inside a
run, but that is the thing to check first if `Authentication requires secure connection` ever comes back.

Verified 2026-09-04 against `mysql:latest` (26.7.0): TPC-C builds and runs (NOPM extracted normally), with the
warmup removed the same build fails on the error above.

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

- The Db2 server container requires the `CAP_IPC_OWNER` capability (granted via `--cap-add IPC_OWNER` in
  `docker-run-args`), and the host must allow it. Full `privileged: true` is not needed.
- Db2 is slow to start (minutes) and loads via INSERTs, so it builds slower than the bulk-loaded engines.

## BenchBase setup

The Wikipedia, YCSB and CH-benCHmark scenarios are driven by a `benchbase` container. BenchBase builds one
self-contained distribution per database (each bundles that engine's JDBC driver), so `benchmarks/benchbase/build-image.sh` builds
every engine's profile into a single image and pushes it to Docker Hub as `ribalba/benchbase:latest`, which the
scenarios pull. Each profile lands in `/benchbase/benchbase-<profile>/` and the scenario `cd`s into the right one.

> **Rebuild required for CockroachDB.** `cockroachdb` was added to `BENCHBASE_PROFILES`, but the image currently
> published as `ribalba/benchbase:latest` was built before that. Until it is rebuilt and pushed, the three
> `benchmarks/*/cockroach.yml` scenarios will fail at `cd /benchbase/benchbase-cockroachdb`. Every other engine is
> unaffected.

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

## EDBT 2027 paper branches

The paper measures configuration tiers T0 (as shipped) to T3 on pinned images. Branch `t0`
is the base of every tier and host branch and differs from `main` in these points:

- Every measured image is pinned to the manifest digest of 2026-09-04:

| Tag on main | Digest on `t0` | Version |
|---|---|---|
| `postgres:latest` | `sha256:4ef4dbc939d61acea57712655ddb4b4ab27419c913f94cca0cd57cb3ea3c2280` | PostgreSQL 18.6 (Debian 18.6-1.pgdg13+2) |
| `mariadb:latest` | `sha256:dd9b303aed4f4890ed09f766d8ca9ddfd176c0c6f6267feff53b3192ec65a979` | MariaDB 12.3.3 |
| `mysql:latest` | `sha256:66aec17cd21a956029b83f083b813073859e8355dc1a00e55df6ba02f0e32345` | MySQL Community Server 26.7.0 |
| `container-registry.oracle.com/database/free:latest` | `sha256:f988b0c04c4c386cd306a2a914c0d7a9702d83acc31b064a28ad8eb6278a8fba` | Oracle AI Database 26ai Free 23.26.3.0.0 |
| `mcr.microsoft.com/mssql/server:latest` | `sha256:4bab24f36c1ecd48e85f7d37df26e6bf301641d84c3fe652f9a0dcc947d512e1` | SQL Server 2025 RTM-CU8 17.0.4075.5 |
| `tpcorg/hammerdb:latest` | `sha256:66cd92a3af15d62b2e59cf51017c7b1ab9119046d8c5264ef2585348a1b1408a` | HammerDB load driver |
| `ribalba/benchbase:latest` | `sha256:f7a0f21e8bfc16d2759b8160d23535e684a44a090846bb0b5d2a02948b54829b` | BenchBase load driver (built 3 September 2026) |

- Db2 and CockroachDB scenarios are removed (out of scope for the paper).
- Warm-up is a separate flow phase (`Warm up`), so the measured phase (`Run TPC-C`,
  `Run TPC-H`, `Run YCSB`, `Run Wikipedia`, `Run CH-benCHmark`) holds only the timed window:
  HammerDB TPC-C runs 2 min warm-up then 5 min measured with `rampup 0`; BenchBase runs 120 s
  warm-up then 300 s measured. TPC-H stays one power run of 22 queries.
- The HammerDB time profile (`/tmp/hdbxtprofile.log`) and the BenchBase `*.summary.json` are
  printed into the run log, so p95 latency is recoverable from GMT.
- HammerDB scenarios remove the idle BenchBase container.
- `run_on_cluster.py` names runs `DBMS-bench <branch> <bench>/<db>` on paper branches.
- TPC-C builds 40 warehouses (10 per virtual user) instead of 80: the unmeasured build halves and a
  tuned buffer pool can hold the roughly 4 GB data set at T1 and T2.
- The SQL Server BenchBase load steps inject `useBulkCopyForBatchInsert=true` into the JDBC URL, so the
  loader uses the bulk-copy API (YCSB load 365 s to 128 s in a local A/B test). The warm-up and measured
  steps keep the plain URL on purpose: the same setting could slow single-statement transactions, and a
  local check could not rule that out because run-to-run throughput varied by a factor of 8.7 from warm-up.

## Paper branch `t2`: T2: workload-tuned for throughput

Forks from `t0`. Every scenario applies the tier configuration to the DBMS (see `TIERS.md` for
every parameter, its value, its source and what was deliberately not applied) and starts with a
`Configure DBMS` flow step that prints the effective configuration into the run log. The SQL of
that step is in `db/<engine>/tiers/`. Generated by `scripts/dbms_bench_tier_branch.py` of the
paper repository; regenerate rather than edit by hand.
