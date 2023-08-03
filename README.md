# DBMS-bench
A tool that benchmarks various DBMS systems agains each other and looks at energy usage

The `compose.yml` defines all the containers we want to use to benchmark. We use the std containers provided by the
various DBMS and the [hammerdb](https://www.hammerdb.com/) container. For benchmarking we use the
hammerDB system.

Currently we support:

- MariaDB
- MySql
- PostgreSQL

For each DB vendor we have a benchmarking `usage_scenario_xxx.yml` that you can execute with the Green Metrics Tool to
get energy readings.

We are currently only using the [TPC-C benchmark](https://en.wikipedia.org/wiki/TPC-C)

## Some background reading

- https://www.hammerdb.com/about.html
- https://www.hammerdb.com/blog/uncategorized/how-to-deploy-hammerdb-cli-fast-with-docker/
- https://www.tpc.org/tpcc/default5.asp
- https://www.hammerdb.com/blog/uncategorized/how-to-run-a-fixed-throughput-workloads/
