#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db mysql
dbset bm TPC-C

diset connection mysql_host mysql_container
diset connection mysql_port 3306

diset tpcc mysql_user mysql
diset tpcc mysql_pass mysql
# The only change to the 2023 script. `mysql` is MySQL's own system schema, so HammerDB
# refuses to build into it. `tpcc` is created empty by MYSQL_DATABASE in legacy/compose.yml.
diset tpcc mysql_dbase tpcc
diset tpcc mysql_driver timed
diset tpcc mysql_rampup 2
diset tpcc mysql_duration 5
diset tpcc mysql_allwarehouse true
diset tpcc mysql_timeprofile true
diset tpcc mysql_raiseerror true


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
set of [ open /tmp/mysql_tprocc w ]
puts $of $jobid
close $of