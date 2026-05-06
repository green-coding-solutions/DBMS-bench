#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db mysql
dbset bm TPC-C
diset connection mysql_host mysql_container
diset connection mysql_port 3307
diset tpcc mysql_user mysql
diset tpcc mysql_pass mysql
diset tpcc mysql_dbase mysql
diset tpcc mysql_driver timed
diset tpcc mysql_rampup 0
diset tpcc mysql_duration 1
diset tpcc mysql_allwarehouse true
diset tpcc mysql_timeprofile true
diset tpcc mysql_raiseerror true
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
set of [ open /tmp/mysql_tprocc w ]
puts $of $jobid
close $of
