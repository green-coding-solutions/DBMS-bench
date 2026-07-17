#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db ora
dbset bm TPC-C

diset connection system_user system
diset connection system_password oracle
diset connection instance oracle_container:1521/FREEPDB1

diset tpcc tpcc_user tpcc
diset tpcc tpcc_pass tpcc
diset tpcc ora_driver timed
diset tpcc rampup 2
diset tpcc duration 5
diset tpcc allwarehouse true
diset tpcc ora_timeprofile true
diset tpcc raiseerror true


loadscript
puts "TEST STARTED"
vuset vu 4
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open /tmp/oracle_tprocc w ]
puts $of $jobid
close $of
