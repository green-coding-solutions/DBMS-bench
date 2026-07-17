#!/bin/tclsh
# maintainer: Pooja Jain
# T2 (workload-aware) variant of pg_tproch_run.tcl: raises the per-query parallel
# degree from 2 to 4 (= the container's core count) for the analytical workload.
# Everything else is identical to T0.

puts "SETTING CONFIGURATION"
dbset db pg
dbset bm TPC-H

diset connection pg_host postgres_container
diset connection pg_port 5432
diset connection pg_sslmode disable

diset tpch pg_scale_fact 1
diset tpch pg_tpch_user tpch
diset tpch pg_tpch_pass tpch
diset tpch pg_tpch_dbase tpch
diset tpch pg_total_querysets 1
diset tpch pg_degree_of_parallel 4

loadscript
puts "TEST STARTED"
vuset vu 1
vucreate
set jobid [ vurun ]
vudestroy
puts "TEST COMPLETE"
set of [ open /tmp/pg_tproch w ]
puts $of $jobid
close $of
