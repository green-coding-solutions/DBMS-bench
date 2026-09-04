#!/bin/tclsh
# Warm-up run for the EDBT 2027 paper: identical to the timed run but 2 minutes long,
# no ramp-up inside HammerDB and no time profile. Its result is discarded; it only
# brings the engine into steady state before the measured phase.
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
diset tpcc maria_rampup 0
diset tpcc maria_duration 2
diset tpcc maria_allwarehouse true
diset tpcc maria_timeprofile false
diset tpcc maria_raiseerror true

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
set of [ open /tmp/maria_tprocc_warmup w ]
puts $of $jobid
close $of