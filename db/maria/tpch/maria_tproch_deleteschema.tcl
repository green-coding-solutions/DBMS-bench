#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db maria
dbset bm TPC-H

diset connection maria_host mariadb_container
diset connection maria_port 3306

diset tpch maria_tpch_user root
diset tpch maria_tpch_pass maria
diset tpch maria_tpch_dbase tpch

puts " DROP SCHEMA STARTED"
deleteschema
puts "DROP SCHEMA COMPLETED"
