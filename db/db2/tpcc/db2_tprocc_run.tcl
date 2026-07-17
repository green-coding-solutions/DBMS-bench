#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db db2
dbset bm TPC-C

diset connection db2_def_user db2inst1
diset connection db2_def_pass ibmdb2
diset connection db2_def_dbase tpcc

diset tpcc db2_user db2inst1
diset tpcc db2_pass ibmdb2
diset tpcc db2_dbase tpcc
diset tpcc db2_driver timed
diset tpcc db2_rampup 2
diset tpcc db2_duration 5
diset tpcc db2_allwarehouse true
diset tpcc db2_timeprofile true

loadscript
puts "TEST STARTED"
# Fixed 4-vCPU workload, matching the other engines (see buildschema).
vuset vu 4
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open /tmp/db2_tprocc w ]
puts $of $jobid
close $of
