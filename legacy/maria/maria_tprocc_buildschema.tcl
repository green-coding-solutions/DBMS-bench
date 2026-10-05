#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db maria
dbset bm TPC-C

diset connection maria_host mariadb_container
diset connection maria_port 3306

set vu [ numberOfCPUs ]
set warehouse [ expr {$vu * 20} ]
diset tpcc maria_count_ware $warehouse
diset tpcc maria_num_vu $vu
diset tpcc maria_user maria
diset tpcc maria_pass maria
diset tpcc maria_dbase maria
diset tpcc maria_storage_engine innodb
diset tpcc maria_raiseerror true

if { $warehouse >= 200 } {
diset tpcc maria_partition true
	} else {
diset tpcc maria_partition false
	}
puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"