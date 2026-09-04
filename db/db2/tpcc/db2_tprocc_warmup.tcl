#!/bin/tclsh
# Warm-up run for the EDBT 2027 paper: identical to the timed run but 2 minutes long,
# no ramp-up inside HammerDB and no time profile. Its result is discarded; it only
# brings the engine into steady state before the measured phase.
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
diset tpcc db2_rampup 0
diset tpcc db2_duration 2
diset tpcc db2_allwarehouse true
diset tpcc db2_timeprofile false

# hammerdbcli tears the Virtual Users down rampup+duration+keepalive_margin seconds after
# vurun, and the 60s default was too tight for Oracle's monitor VU to finish its end-of-run
# AWR snapshot - it was killed mid-query and the run reported no result. Widened here too as
# cheap insurance: the timer returns as soon as all VUs complete, so it costs no runtime.
giset commandline keepalive_margin 300

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
set of [ open /tmp/db2_tprocc_warmup w ]
puts $of $jobid
close $of
