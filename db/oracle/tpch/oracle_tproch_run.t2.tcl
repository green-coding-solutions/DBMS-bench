#!/bin/tclsh
# maintainer: Pooja Jain
# T2 (workload-aware) variant of oracle_tproch_run.tcl: raises the query parallel
# degree from 2 to 4. NOTE: Oracle Database Free is capped at ~2 CPU threads, so
# the effective degree is bounded by the edition regardless of this setting.

puts "SETTING CONFIGURATION"
dbset db ora
dbset bm TPC-H

diset connection system_user system
diset connection system_password oracle
diset connection instance oracle_container:1521/FREEPDB1

diset tpch scale_fact 1
diset tpch num_tpch_threads 4
diset tpch tpch_user tpch
diset tpch tpch_pass tpch
diset tpch tpch_def_tab users
diset tpch total_querysets 1
diset tpch degree_of_parallel 4

loadscript
puts "TEST STARTED"
vuset vu 1
vucreate
set jobid [ vurun ]
vudestroy
puts "TEST COMPLETE"
set of [ open /tmp/oracle_tproch w ]
puts $of $jobid
close $of
