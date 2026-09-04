#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db mysql
dbset bm TPC-C

diset connection mysql_host mysql_container
diset connection mysql_port 3306

diset tpcc mysql_user mysql
diset tpcc mysql_pass mysql
diset tpcc mysql_dbase tpcc
diset tpcc mysql_driver timed
diset tpcc mysql_rampup 0
diset tpcc mysql_duration 5
diset tpcc mysql_allwarehouse true
diset tpcc mysql_timeprofile true
diset tpcc mysql_raiseerror true

# hammerdbcli tears the Virtual Users down rampup+duration+keepalive_margin seconds after
# vurun, and the 60s default was too tight for Oracle's monitor VU to finish its end-of-run
# AWR snapshot - it was killed mid-query and the run reported no result. Widened here too as
# cheap insurance: the timer returns as soon as all VUs complete, so it costs no runtime.
giset commandline keepalive_margin 300

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
set of [ open /tmp/mysql_tprocc w ]
puts $of $jobid
close $of