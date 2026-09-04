-- T1: resource-sized, workload-blind. Applied by the `Configure DBMS` flow step through sqlplus as SYSDBA.
-- sga_max_size is static, so the instance is restarted inside the container (about 10 s);
-- WHENEVER SQLERROR makes any failure fail the run. Provenance: TIERS.md.
WHENEVER SQLERROR EXIT SQL.SQLCODE
set pagesize 0 linesize 250 feedback off heading off
select '=== SHIPPED CONFIGURATION (before the tier is applied) ===' from dual;
select 'CONFIG '||name||'='||value from v$parameter where name in ('sga_max_size', 'sga_target', 'pga_aggregate_target', 'filesystemio_options', 'log_checkpoints_to_alert', 'log_checkpoint_timeout', 'log_checkpoint_interval', 'fast_start_mttr_target', 'optimizer_dynamic_sampling') order by name;
select 'CONFIG redo log groups='||count(*)||' x '||min(bytes/1024/1024)||'M' from v$log;
select 'INFO redo group '||group#||' '||bytes/1024/1024||'M '||status from v$log order by group#;
select 'INFO SGA '||name||'='||value from v$sga;
select 'INFO PDB '||name||' '||open_mode from v$pdbs;

select '=== APPLYING T1: resource-sized, workload-blind ===' from dual;
ALTER SYSTEM SET sga_max_size=1632M SCOPE=SPFILE;
ALTER SYSTEM SET sga_target=1632M SCOPE=SPFILE;
ALTER SYSTEM SET pga_aggregate_target=416M SCOPE=SPFILE;
SHUTDOWN IMMEDIATE
STARTUP
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER SYSTEM REGISTER;
select '=== TIER CONFIGURATION CHECK ===' from dual;
select 'CONFIG '||name||'='||value from v$parameter where name in ('sga_max_size', 'sga_target', 'pga_aggregate_target', 'filesystemio_options', 'log_checkpoints_to_alert', 'log_checkpoint_timeout', 'log_checkpoint_interval', 'fast_start_mttr_target', 'optimizer_dynamic_sampling') order by name;
select 'CONFIG redo log groups='||count(*)||' x '||min(bytes/1024/1024)||'M' from v$log;
select 'INFO redo group '||group#||' '||bytes/1024/1024||'M '||status from v$log order by group#;
select 'INFO SGA '||name||'='||value from v$sga;
select 'INFO PDB '||name||' '||open_mode from v$pdbs;

select '=== EFFECTIVE CONFIGURATION (v$parameter) ===' from dual;
select name||'='||value||' [default='||isdefault||']' from v$parameter order by name;
exit
