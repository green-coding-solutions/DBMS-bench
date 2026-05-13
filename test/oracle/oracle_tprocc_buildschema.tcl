#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db ora
dbset bm TPC-C
diset connection system_user system
diset connection system_password manager
diset connection instance //oracle_container:1521/freepdb1
diset tpcc count_ware 1
diset tpcc num_vu 1
diset tpcc tpcc_user tpcc
diset tpcc tpcc_pass tpcc
diset tpcc tpcc_def_tab users
diset tpcc tpcc_def_temp temp
diset tpcc partition false
diset tpcc hash_clusters false
puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
