#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db mysql
dbset bm TPC-C
diset connection mysql_host mysql_container
diset connection mysql_port 3307
diset tpcc mysql_count_ware 1
diset tpcc mysql_num_vu 1
diset tpcc mysql_user mysql
diset tpcc mysql_pass mysql
diset tpcc mysql_dbase mysql
diset tpcc mysql_storage_engine innodb
diset tpcc mysql_partition false
diset tpcc mysql_raiseerror true
puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
