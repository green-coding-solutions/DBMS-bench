#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db mysql
dbset bm TPC-C

diset connection mysql_host mysql_container
diset connection mysql_port 3306

set vu [ numberOfCPUs ]
set warehouse [ expr {$vu * 20} ]
diset tpcc mysql_count_ware $warehouse
diset tpcc mysql_num_vu $vu
diset tpcc mysql_user mysql
diset tpcc mysql_pass mysql
# The only change to the 2023 script. `mysql` is MySQL's own system schema, so HammerDB
# refuses to build into it. `tpcc` is created empty by MYSQL_DATABASE in legacy/compose.yml.
diset tpcc mysql_dbase tpcc
diset tpcc mysql_storage_engine innodb
diset tpcc mysql_raiseerror true

if { $warehouse >= 200 } {
diset tpcc mysql_partition true
	} else {
diset tpcc mysql_partition false
	}
puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"