#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db pg
dbset bm TPC-C
diset connection pg_host cockroachdb_container
diset connection pg_port 26257
diset connection pg_sslmode disable
diset tpcc pg_superuser root
diset tpcc pg_superuserpass ""
diset tpcc pg_defaultdbase defaultdb
diset tpcc pg_user root
diset tpcc pg_pass ""
diset tpcc pg_dbase defaultdb
diset tpcc pg_driver timed
diset tpcc pg_rampup 2
diset tpcc pg_duration 5
diset tpcc pg_allwarehouse true
diset tpcc pg_timeprofile true
diset tpcc pg_keyandthink true
diset tpcc pg_raiseerror true
loadscript
puts "TEST STARTED"
vuset vu vcpu
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open /tmp/cockroach_tprocc w ]
puts $of $jobid
close $of
