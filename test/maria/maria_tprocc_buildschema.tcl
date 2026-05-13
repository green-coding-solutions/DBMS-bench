#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db maria
dbset bm TPC-C
diset connection maria_host mariadb_container
diset connection maria_port 3306
diset tpcc maria_count_ware 1
diset tpcc maria_num_vu 1
diset tpcc maria_user maria
diset tpcc maria_pass maria
diset tpcc maria_dbase maria
diset tpcc maria_storage_engine innodb
diset tpcc maria_partition false
diset tpcc maria_raiseerror true
puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
