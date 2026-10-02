# Configuration tier T0 for the EDBT 2027 paper

Branch `t0` is the base of every tier and host branch of the paper and measures
**T0: the configuration as shipped**. Every image is pinned to its content digest and started
with environment variables only (credentials, the database name, and for SQL Server the licence
acceptance and the edition); no configuration file is mounted and no start-up argument is
passed. The flow has no `Configure DBMS` step: nothing is changed, so nothing is printed.

Schema, indexes, storage engine, scale factor, client count and driver scripts are the same on
every tier branch; the tiers `t1`, `t2` and `t3` change server parameters only (see their
`TIERS.md`).

## Shipped values

The values below are the shipped values of every parameter that T1 or T2 changes, read back from
the pinned images started locally under the same limits of 4 CPU / 8192 MB (5 September 2026).
They are the `T0 (shipped)` column of the knob tables on branches `t1` and `t2`. The parameters
that only the energy search of T3 changes are listed per cell in the `TIERS.md` of branch `t3`.

### PostgreSQL

| Parameter | T0 (shipped) |
|---|---|
| shared_buffers | 128MB |
| effective_cache_size | 4GB |
| maintenance_work_mem | 64MB |
| work_mem | 4MB |
| max_worker_processes | 8 |
| max_parallel_workers | 8 |
| max_parallel_workers_per_gather | 2 |
| max_parallel_maintenance_workers | 2 |
| max_connections | 100 |
| checkpoint_completion_target | 0.9 |
| wal_buffers | 4MB |
| default_statistics_target | 100 |
| random_page_cost | 4 |
| effective_io_concurrency | 16 |
| min_wal_size | 80MB |
| max_wal_size | 1GB |
| huge_pages | try |
| wal_compression | off |
| jit | on |

### MariaDB

| Parameter | T0 (shipped) |
|---|---|
| innodb_buffer_pool_size | 128M |
| innodb_log_file_size | 96M |
| innodb_purge_threads | 4 |
| innodb_log_buffer_size | 16M |
| innodb_io_capacity | 200 |
| innodb_io_capacity_max | 2000 |
| innodb_adaptive_hash_index | OFF |
| innodb_spin_wait_delay | 4 |
| innodb_flush_method | O_DIRECT |

### MySQL

| Parameter | T0 (shipped) |
|---|---|
| innodb_buffer_pool_size | 128M |
| innodb_redo_log_capacity | 100M |
| innodb_buffer_pool_instances | 1 |
| innodb_page_cleaners | 1 |
| innodb_purge_threads | 1 |
| innodb_log_buffer_size | 64M |
| innodb_io_capacity | 10000 |
| innodb_io_capacity_max | 20000 |
| innodb_change_buffering | all |
| innodb_adaptive_hash_index | OFF |
| innodb_spin_wait_delay | 6 |
| innodb_flush_method | O_DIRECT |

### Oracle Database Free

| Parameter | T0 (shipped) |
|---|---|
| sga_max_size | 1536M |
| sga_target | 1536M |
| pga_aggregate_target | 512M |
| filesystemio_options | none |
| log_checkpoints_to_alert | FALSE |
| log_checkpoint_timeout | 1800 |
| log_checkpoint_interval | 0 |
| fast_start_mttr_target | 0 |
| redo log groups | 3 x 200M |
| optimizer_dynamic_sampling | 2 |

### SQL Server

| Parameter | T0 (shipped) |
|---|---|
| max degree of parallelism | 0 |
| process affinity | none (5 schedulers = cpuset) |
| min server memory (MB) | 16 |
| max server memory (MB) | 2147483647 |
| default trace enabled | 1 |
| model RECOVERY | FULL |
| recovery interval (min) | 0 |
| Engine | Setting |
| PostgreSQL | `synchronous_commit=off` |
| PostgreSQL | `wal_level=minimal` |
| PostgreSQL | `autovacuum=off` |
| PostgreSQL | `huge_pages=on` |
| PostgreSQL | `io_method=io_uring` |
| MySQL | `innodb_flush_log_at_trx_commit=0` |
| MySQL | `innodb_doublewrite=0` |
| MySQL | `innodb_checksum_algorithm=none` |
| MySQL | `innodb_flush_method=O_DIRECT_NO_FSYNC` |
| MySQL | `innodb_read_io_threads=16, innodb_write_io_threads=16` |
| MySQL | `innodb_dedicated_server=ON` |
| SQL Server | `lightweight pooling=1` |
| SQL Server | `priority boost=1` |
| SQL Server | `TORN_PAGE_DETECTION OFF, PAGE_VERIFY NONE` |
| SQL Server | `max worker threads=3000` |
| SQL Server | `DELAYED_DURABILITY` |
| Oracle Database Free | `commit_logging=BATCH, commit_wait=NOWAIT` |
| Oracle Database Free | `db_block_checksum / db_block_checking changes` |
| Oracle Database Free | `use_large_pages / huge pages` |
| Oracle Database Free | `inmemory_size, in-memory column store` |
| Oracle Database Free | `parallel_max_servers` |
| MariaDB | `ColumnStore (InfiniDB) parameters` |
