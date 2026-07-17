#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db ora
dbset bm TPC-C

diset connection system_user system
diset connection system_password oracle
diset connection instance oracle_container:1521/FREEPDB1

set vu 4
set warehouse [ expr {$vu * 20} ]
diset tpcc count_ware $warehouse
diset tpcc num_vu $vu
diset tpcc tpcc_user tpcc
diset tpcc tpcc_pass tpcc
diset tpcc tpcc_def_tab users
diset tpcc tpcc_ol_tab users
diset tpcc tpcc_def_temp temp

if { $warehouse >= 200 } {
diset tpcc partition true
	} else {
diset tpcc partition false
	}
puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
