#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db ora
dbset bm TPC-C
diset connection system_user system
diset connection system_password manager
diset connection instance //oracle_container:1521/freepdb1
diset tpcc tpcc_user tpcc
diset tpcc tpcc_pass tpcc
puts "DROP SCHEMA STARTED"
deleteschema
puts "DROP SCHEMA COMPLETED"
