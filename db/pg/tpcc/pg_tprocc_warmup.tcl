#!/bin/tclsh
# Warm-up run for the EDBT 2027 paper: identical to the timed run but 2 minutes long,
# no ramp-up inside HammerDB and no time profile. Its result is discarded; it only
# brings the engine into steady state before the measured phase.
# maintainer: Pooja Jain

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
diset tpcc pg_raiseerror true

diset tpcc pg_driver timed

diset tpcc pg_rampup 0
diset tpcc pg_duration 2

diset tpcc pg_vacuum true
diset tpcc pg_timeprofile false
diset tpcc pg_allwarehouse true

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
set of [ open /tmp/pg_tprocc_warmup w ]
puts $of $jobid
close $of