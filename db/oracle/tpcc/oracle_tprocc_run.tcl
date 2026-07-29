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

# hammerdbcli tears the Virtual Users down rampup+duration+keepalive_margin seconds after
# vurun - 120+300+60 = 480s with the 60s default. That budget also has to cover the two AWR
# snapshots the monitor VU takes, and on this container the START snapshot alone measured
# 60-90s, which pushed the end of the timing loop to (or past) the deadline. The monitor was
# killed while taking the END snapshot, so it reported FINISHED FAILED and never printed the
# "System achieved ... NOPM" line the scenario parses - failing both observed Oracle runs.
# 300s covers both snapshots plus the DBA_HIST_SYSSTAT query; the timer returns as soon as
# all VUs complete, so a wide margin costs no extra runtime when things go well.
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
set of [ open /tmp/oracle_tprocc w ]
puts $of $jobid
close $of
