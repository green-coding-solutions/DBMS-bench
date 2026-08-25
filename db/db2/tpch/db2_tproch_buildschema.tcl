#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db db2
dbset bm TPC-H

diset connection db2_def_user db2inst1
diset connection db2_def_pass ibmdb2
diset connection db2_def_dbase tpch

diset tpch db2_scale_fact 1
# keep the thread count modest: Db2 runs over the network and drops a burst of
# connections from a freshly-started server (SQL30081N)
diset tpch db2_num_tpch_threads 4
diset tpch db2_tpch_user db2inst1
diset tpch db2_tpch_pass ibmdb2
diset tpch db2_tpch_dbase tpch
diset tpch db2_tpch_def_tab USERSPACE1
diset tpch db2_tpch_organizeby NONE

puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
