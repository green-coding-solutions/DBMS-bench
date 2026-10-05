#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db maria
dbset bm TPC-C

diset connection maria_host mariadb_container
diset connection maria_port 3306

diset tpcc maria_user maria
diset tpcc maria_pass maria
diset tpcc maria_dbase maria
diset tpcc maria_driver timed
diset tpcc maria_rampup 2
diset tpcc maria_duration 5
diset tpcc maria_allwarehouse true
diset tpcc maria_timeprofile true
diset tpcc maria_raiseerror true

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
set of [ open /tmp/maria_tprocc w ]
puts $of $jobid
close $of