#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db mysql
dbset bm TPC-H

diset connection mysql_host mysql_container
diset connection mysql_port 3306

diset tpch mysql_tpch_user root
diset tpch mysql_tpch_pass mysql
diset tpch mysql_tpch_dbase tpch

puts " DROP SCHEMA STARTED"
deleteschema
puts "DROP SCHEMA COMPLETED"
