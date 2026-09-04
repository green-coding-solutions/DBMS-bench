-- T2: workload-tuned for throughput, class olap. Applied by the `Configure DBMS` flow step through sqlplus as SYSDBA.
-- sga_max_size is static, so the instance is restarted inside the container (about 10 s);
-- WHENEVER SQLERROR makes any failure fail the run. Provenance: TIERS.md.
WHENEVER SQLERROR EXIT SQL.SQLCODE
set pagesize 0 linesize 250 feedback off heading off
select '=== SHIPPED CONFIGURATION (before the tier is applied) ===' from dual;
select 'CONFIG '||name||'='||value from v$parameter where name in ('sga_max_size', 'sga_target', 'pga_aggregate_target', 'filesystemio_options', 'log_checkpoints_to_alert', 'log_checkpoint_timeout', 'log_checkpoint_interval', 'fast_start_mttr_target', 'parallel_max_servers', 'optimizer_dynamic_sampling') order by name;
select 'CONFIG redo log groups='||count(*)||' x '||min(bytes/1024/1024)||'M' from v$log;
select 'INFO redo group '||group#||' '||bytes/1024/1024||'M '||status from v$log order by group#;
select 'INFO SGA '||name||'='||value from v$sga;
select 'INFO PDB '||name||' '||open_mode from v$pdbs;

select '=== APPLYING T2: workload-tuned for throughput, class olap ===' from dual;
ALTER SYSTEM SET sga_max_size=1024M SCOPE=SPFILE;
ALTER SYSTEM SET sga_target=1024M SCOPE=SPFILE;
ALTER SYSTEM SET pga_aggregate_target=1024M SCOPE=SPFILE;
ALTER SYSTEM SET filesystemio_options=SETALL SCOPE=SPFILE;
ALTER SYSTEM SET log_checkpoints_to_alert=TRUE SCOPE=SPFILE;
ALTER SYSTEM SET log_checkpoint_timeout=0 SCOPE=SPFILE;
ALTER SYSTEM SET log_checkpoint_interval=0 SCOPE=SPFILE;
ALTER SYSTEM SET fast_start_mttr_target=0 SCOPE=SPFILE;
ALTER SYSTEM SET parallel_max_servers=4 SCOPE=SPFILE;
ALTER SYSTEM SET optimizer_dynamic_sampling=4 SCOPE=SPFILE;
-- Redo log capacity: three new groups of 1024M, then the shipped 200 MB groups are dropped.
ALTER DATABASE ADD LOGFILE GROUP 4 '/opt/oracle/oradata/FREE/redo04.log' SIZE 1024M;
ALTER DATABASE ADD LOGFILE GROUP 5 '/opt/oracle/oradata/FREE/redo05.log' SIZE 1024M;
ALTER DATABASE ADD LOGFILE GROUP 6 '/opt/oracle/oradata/FREE/redo06.log' SIZE 1024M;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
ALTER DATABASE DROP LOGFILE GROUP 1;
ALTER DATABASE DROP LOGFILE GROUP 2;
ALTER DATABASE DROP LOGFILE GROUP 3;
SHUTDOWN IMMEDIATE
STARTUP
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER SYSTEM REGISTER;
select '=== TIER CONFIGURATION CHECK ===' from dual;
select 'CONFIG '||name||'='||value from v$parameter where name in ('sga_max_size', 'sga_target', 'pga_aggregate_target', 'filesystemio_options', 'log_checkpoints_to_alert', 'log_checkpoint_timeout', 'log_checkpoint_interval', 'fast_start_mttr_target', 'parallel_max_servers', 'optimizer_dynamic_sampling') order by name;
select 'CONFIG redo log groups='||count(*)||' x '||min(bytes/1024/1024)||'M' from v$log;
select 'INFO redo group '||group#||' '||bytes/1024/1024||'M '||status from v$log order by group#;
select 'INFO SGA '||name||'='||value from v$sga;
select 'INFO PDB '||name||' '||open_mode from v$pdbs;

select '=== EFFECTIVE CONFIGURATION (v$parameter) ===' from dual;
select name||'='||value||' [default='||isdefault||']' from v$parameter order by name;
exit
