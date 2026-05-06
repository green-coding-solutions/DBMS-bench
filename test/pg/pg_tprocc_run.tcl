#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db pg
dbset bm TPC-C
diset connection pg_host postgres_container
diset connection pg_port 5432
diset connection pg_sslmode disable
diset tpcc pg_superuser postgres
diset tpcc pg_superuserpass postgres
diset tpcc pg_defaultdbase postgres
diset tpcc pg_user postgres
diset tpcc pg_pass postgres
diset tpcc pg_dbase postgres
diset tpcc pg_driver timed
diset tpcc pg_rampup 0
diset tpcc pg_duration 1
diset tpcc pg_allwarehouse true
diset tpcc pg_timeprofile true
diset tpcc pg_keyandthink true
diset tpcc pg_raiseerror true
loadscript
puts "TEST STARTED"
vuset vu 1
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open /tmp/pg_tprocc w ]
puts $of $jobid
close $of
