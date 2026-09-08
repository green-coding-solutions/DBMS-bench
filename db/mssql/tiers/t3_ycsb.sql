-- T3: energy search trial, class ycsb. Applied by the `Configure DBMS` flow step through sqlcmd -b (any error fails
-- the run). Every parameter here is dynamic, so no restart is needed. Provenance: TIERS.md.
SET NOCOUNT ON;
SELECT '=== SHIPPED CONFIGURATION (before the tier is applied) ===';
SELECT 'CONFIG ' + name + '=' + CONVERT(varchar(30), value_in_use) FROM sys.configurations WHERE name IN ('max degree of parallelism', 'min server memory (MB)', 'max server memory (MB)', 'default trace enabled', 'recovery interval (min)', 'cost threshold for parallelism', 'optimize for ad hoc workloads') ORDER BY name;
SELECT 'CONFIG process affinity=' + CONVERT(varchar(10), COUNT(*)) + ' online schedulers' FROM sys.dm_os_schedulers WHERE status = 'VISIBLE ONLINE';
SELECT 'CONFIG model RECOVERY=' + recovery_model_desc FROM sys.databases WHERE name = 'model';
SELECT 'INFO cpu_count=' + CONVERT(varchar(10), cpu_count) + ' scheduler_count=' + CONVERT(varchar(10), scheduler_count) + ' physical_memory_mb=' + CONVERT(varchar(20), physical_memory_kb / 1024) + ' committed_target_mb=' + CONVERT(varchar(20), committed_target_kb / 1024) + ' max_workers_count=' + CONVERT(varchar(10), max_workers_count) FROM sys.dm_os_sys_info;
SELECT 'INFO tempdb file ' + name + ' size_mb=' + CONVERT(varchar(20), size * 8 / 1024) FROM tempdb.sys.database_files;

SELECT '=== APPLYING T3: energy search trial, class ycsb ===';
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;
EXEC sp_configure 'max degree of parallelism', 3;
ALTER SERVER CONFIGURATION SET PROCESS AFFINITY CPU = AUTO;
EXEC sp_configure 'default trace enabled', 0;
ALTER DATABASE model SET RECOVERY SIMPLE;
EXEC sp_configure 'recovery interval (min)', 1;
EXEC sp_configure 'cost threshold for parallelism', 100;
EXEC sp_configure 'optimize for ad hoc workloads', 0;
-- Buffer pool cap as a fraction of the process memory limit the engine reports
-- (physical_memory_kb, 80 percent of the cgroup). min is lowered first so that a
-- max below the previous min is accepted.
EXEC sp_configure 'min server memory (MB)', 16;
RECONFIGURE WITH OVERRIDE;
DECLARE @phys int = (SELECT physical_memory_kb / 1024 FROM sys.dm_os_sys_info);
DECLARE @maxmem int = CAST(@phys * 0.4000 AS int);
EXEC sp_configure 'max server memory (MB)', @maxmem;
EXEC sp_configure 'min server memory (MB)', @maxmem;
RECONFIGURE WITH OVERRIDE;

SELECT '=== TIER CONFIGURATION CHECK ===';
SELECT 'CONFIG ' + name + '=' + CONVERT(varchar(30), value_in_use) FROM sys.configurations WHERE name IN ('max degree of parallelism', 'min server memory (MB)', 'max server memory (MB)', 'default trace enabled', 'recovery interval (min)', 'cost threshold for parallelism', 'optimize for ad hoc workloads') ORDER BY name;
SELECT 'CONFIG process affinity=' + CONVERT(varchar(10), COUNT(*)) + ' online schedulers' FROM sys.dm_os_schedulers WHERE status = 'VISIBLE ONLINE';
SELECT 'CONFIG model RECOVERY=' + recovery_model_desc FROM sys.databases WHERE name = 'model';
SELECT 'INFO cpu_count=' + CONVERT(varchar(10), cpu_count) + ' scheduler_count=' + CONVERT(varchar(10), scheduler_count) + ' physical_memory_mb=' + CONVERT(varchar(20), physical_memory_kb / 1024) + ' committed_target_mb=' + CONVERT(varchar(20), committed_target_kb / 1024) + ' max_workers_count=' + CONVERT(varchar(10), max_workers_count) FROM sys.dm_os_sys_info;
SELECT 'INFO tempdb file ' + name + ' size_mb=' + CONVERT(varchar(20), size * 8 / 1024) FROM tempdb.sys.database_files;

SELECT '=== EFFECTIVE CONFIGURATION (sys.configurations) ===';
SELECT name + '=' + CONVERT(varchar(30), value_in_use) FROM sys.configurations ORDER BY name;
