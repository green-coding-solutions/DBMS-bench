-- Printed by the `Configure DBMS` flow step (paper tier branches). The tier itself is
-- applied through the server command line in the scenario; this only proves it took effect.
\echo === TIER CONFIGURATION CHECK ===
select 'CONFIG '||name||'='||current_setting(name) from pg_settings where name in ('shared_buffers', 'effective_cache_size', 'maintenance_work_mem', 'work_mem', 'max_worker_processes', 'max_parallel_workers', 'max_parallel_workers_per_gather', 'max_parallel_maintenance_workers', 'max_connections', 'checkpoint_completion_target', 'wal_buffers', 'default_statistics_target', 'random_page_cost', 'effective_io_concurrency', 'min_wal_size', 'max_wal_size', 'huge_pages', 'wal_compression', 'jit') order by name;
\echo === EFFECTIVE CONFIGURATION (pg_settings) ===
select name||'='||setting||coalesce(' '||unit,'')||' ['||source||']' from pg_settings order by name;
