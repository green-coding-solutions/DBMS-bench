#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db db2
dbset bm TPC-H

diset connection db2_def_user db2inst1
diset connection db2_def_pass ibmdb2
diset connection db2_def_dbase tpch

diset tpch db2_tpch_user db2inst1
diset tpch db2_tpch_pass ibmdb2
diset tpch db2_tpch_dbase tpch
diset tpch db2_total_querysets 1
# HammerDB opens every TPROC-H connection with "SET CURRENT DEGREE '<n>'". The Db2 image
# ships with INTRA_PARALLEL=NO, so that statement came back as SQL1530W ("degree of
# parallelism will be ignored because the system is not enabled for intra-partition
# parallelism") - db2tcl surfaces the warning as an error, and the virtual user died before
# running a single query. Set explicitly to 2 to match Oracle/PostgreSQL/MSSQL (a fairness
# invariant enforced by check_repo.py); the scenario enables INTRA_PARALLEL on the server so
# the request is honoured instead of rejected.
diset tpch db2_degree_of_parallel 2

loadscript
puts "TEST STARTED"
vuset vu 1
vucreate
set jobid [ vurun ]
vudestroy
puts "TEST COMPLETE"
set of [ open /tmp/db2_tproch w ]
puts $of $jobid
close $of
