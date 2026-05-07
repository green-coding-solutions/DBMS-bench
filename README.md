# DBMS-bench

A tool that benchmarks various DBMS systems against each other and looks at energy usage.

The `compose.yml` defines all the containers use to benchmark. it uses the std containers provided by the various DBMS and the __[hammerdb](https://www.hammerdb.com/)__ container. For benchmarking we use the hammerDB system.

## Supported Databases

* MariaDB
* MySQL
* PostgreSQL
* Microsoft SQL Server
* Oracle Free Edition
* CockroachDB (Distributed)

## Structure

- `production/` — Full benchmark scripts (rampup 2, duration 5, all VUs)
- `test/` — Minimal test scripts (rampup 0, duration 1, 1 VU)
- `usage_scenario_<db>.yml` — Production GMT scenarios
- `usage_scenario_<db>_test.yml` — Minimal test GMT scenarios

## Usage

Run a benchmark with the Green Metrics Tool:

    python3 runner.py --uri /path/to/DBMS-bench --filename usage_scenario_maria_test.yml --allow-unsafe

## Benchmarks

We are currently only using the TPC-C benchmark.

## Notes

### Credentials
All database credentials are dummy credentials for local Docker containers only. Never use these in production.

### Oracle
Oracle requires the freepdb1 Pluggable Database instead of the default CDB. The connection string is //oracle_container:1521/freepdb1. Oracle needs ~120 seconds to start up, handled via a sleep in the usage scenario. To pull the Oracle image you need a free Oracle account and must accept the license at container-registry.oracle.com.

### SQL Server
SQL Server needs ~30 seconds to start up, handled via a sleep in the usage scenario.
## Some background reading

- https://www.hammerdb.com/about.html
- https://www.hammerdb.com/blog/uncategorized/how-to-deploy-hammerdb-cli-fast-with-docker/
- https://www.tpc.org/tpcc/default5.asp
- https://www.hammerdb.com/blog/uncategorized/how-to-run-a-fixed-throughput-workloads/
