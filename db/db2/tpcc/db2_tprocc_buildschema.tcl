#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db db2
dbset bm TPC-C

diset connection db2_def_user db2inst1
diset connection db2_def_pass ibmdb2
diset connection db2_def_dbase tpcc

set vu 4
set warehouse [ expr {$vu * 20} ]
# Fixed 4-vCPU workload, matching the other engines and the container's `cpus`
# limit. 4 loader connections is also a safe count for Db2, which runs over the
# network and drops a burst against the freshly-started server (SQL30081N).
diset tpcc db2_count_ware $warehouse
diset tpcc db2_num_vu $vu
diset tpcc db2_user db2inst1
diset tpcc db2_pass ibmdb2
diset tpcc db2_dbase tpcc
diset tpcc db2_def_tab USERSPACE1
diset tpcc db2_tab_list {C "" D "" H "" I "" W "" S "" NO "" OR "" OL ""}
# single-node Db2 (community) has no DPF, so leave the schema unpartitioned
diset tpcc db2_partition false

puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
