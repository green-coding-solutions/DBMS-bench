# Legacy TPC-C time series

This folder holds the compose file and HammerDB scripts for the TPC-C benchmarks
that have been measured on the GMT cluster since August 2023. They predate the
`benchmarks/` + `db/` layout and are intentionally kept separate from it. The rest of
the repo is free to change for the EDBT study. These files are not, because every
change here shows up as a step in a multi-year time series.

The usage scenarios themselves stay in the repo root under their original names.
GMT's timeline and Energy ID match runs on the exact filename, so moving them would
cut the new runs off from the history. They load `legacy/compose.yml` and the
scripts in `legacy/<db>/`.

| Watchlist | Name | Scenario | Machine | Schedule |
| --- | --- | --- | --- | --- |
| 13 | TPC-C Benchmark - MariaDB (20 Warehouses - HammerDB) | `usage_scenario_maria.yml` | 7, CO2 Profiling Esprimo P956 | commit-variance |
| 14 | TPC-C Benchmark - PostgreSQL (20 Warehouses - HammerDB) | `usage_scenario_pg.yml` | 7, CO2 Profiling Esprimo P956 | commit-variance |
| none yet | MySQL | `usage_scenario_mysql.yml` | 7 (ran daily 2023-08 to 2024-01) | |

## The workload (frozen)

The TCL scripts in `pg/` and `maria/` are byte-identical to the ones that ran from
2023 to 2026 (`git show cb4295c^:pg/pg_tprocc_run.tcl` and so on). Do not edit them,
and do not point the scenarios at `db/*/tpcc/` instead. Those scripts belong to the
study and have already diverged (fixed VU count, larger `keepalive_margin`).

- Virtual users are `numberOfCPUs`, so 4 on machine 7 (i5-6500, 4 cores, no HT).
- 20 warehouses per VU, so 80 warehouses. The "20 Warehouses" in the names is per VU.
- Timed driver, 2 min ramp-up, 5 min measured, all-warehouse and time profiling on.
- No `cpus` / `mem_limit` on any container.
- Exactly three flow steps named `Build Warehouses`, `Query Warehouses` and
  `Drop Warehouses`. The phase names are what the dashboard and the Energy ID
  software tasks match on.
- The PostgreSQL drop step has always failed inside HammerDB with "cannot drop the
  currently open database". It is left that way so the phase stays comparable.

## MySQL

None of the 57 MySQL runs from 2023-08-26 to 2024-01-02 measured TPC-C. Every one
of them failed in the schema build, either with `caching_sha2_password ... requires
secure connection` or because MySQL was not up yet, and the run step then failed
on the missing tables. HammerDB exits 0 in that case, so GMT stored them as
successful runs. There is no valid MySQL history to stay comparable with.

The MySQL scripts in `mysql/` are the 2023 ones with a single change. The schema is
built in a `tpcc` database instead of `mysql`, which is MySQL's own system schema.
The server side follows what the root `compose.yml` proved to work. One TLS login
during BOOT primes the password cache, so HammerDB can then connect over plaintext
(see the comment in `compose.yml`).

## What is allowed to change

- **DB versions.** The image tags in `compose.yml` are pinned, and Dependabot bumps
  them (`/legacy` is listed in `.github/dependabot.yml`). The watchlist runs in
  commit-variance mode, so each bump commit triggers a measurement of the new
  release. That is the point of the series. Do not switch to `:latest`, or new
  releases stop triggering runs.
- **HammerDB.** `tpcorg/hammerdb:latest`, as it has always been.

## Port of October 2026

The refactor in `cb4295c` (2026-08-25) removed the old files, and the watchlist jobs
failed with `FileNotFoundError` from then on. They were restored and brought up to
date with the current GMT without touching the workload.

- The NOPM metric is now printed as `<µs timestamp> sqlop=<NOPM>`. The old
  `GMT_SCI_R=<NOPM>` line stopped being parsed with the switch to `custom_metrics`
  on 2026-05-20, and the GMT version on the cluster failed the 2026-08-18 runs over
  it ("Custom metric 'sqlop' yielded no results"). SCI was stored as
  `software_carbon_intensity_global` up to 2026-03-04. It is now `custom_sqlop` and
  `custom_sqlop_sci_global`.
- `bash` instead of `sh`, and Build and Run fail when HammerDB logs a virtual-user
  error, so a broken run can no longer be stored as a valid measurement.
- `hammerdb` waits for the DB healthcheck before the flow starts. The probes run
  every 2s during startup only and then every 24h, so nothing execs into the DB
  containers during the measured phases, just like before.
- Published host ports removed. All traffic is container to container.
- Images. `postgres:18.6-trixie` is unchanged from the last successful runs. MariaDB
  moved from `12.3.x-noble` to `13.0.2-resolute` and MySQL to `26.7.0-oraclelinux9`,
  the current `latest` of each.
