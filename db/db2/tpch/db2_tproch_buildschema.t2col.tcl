#!/bin/tclsh
# maintainer: Pooja Jain
# T2+ (COLUMNAR sub-tier) build for Db2 TPC-H: builds the tables as BLU
# column-organized (db2_tpch_organizeby COLUMN) instead of row (NONE) — Db2's
# strongest analytical design. Requires the instance in analytic mode
# (DB2_WORKLOAD=ANALYTICS); the t2col scenario sets that before this build.

puts "SETTING CONFIGURATION"
dbset db db2
dbset bm TPC-H

diset connection db2_def_user db2inst1
diset connection db2_def_pass ibmdb2
diset connection db2_def_dbase tpch

diset tpch db2_scale_fact 1
diset tpch db2_num_tpch_threads 4
diset tpch db2_tpch_user db2inst1
diset tpch db2_tpch_pass ibmdb2
diset tpch db2_tpch_dbase tpch
diset tpch db2_tpch_def_tab USERSPACE1
diset tpch db2_tpch_organizeby COLUMN

puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
