#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db maria
dbset bm TPC-C

diset connection maria_host mariadb_container
diset connection maria_port 3306

diset tpcc maria_user maria
diset tpcc maria_pass maria
diset tpcc maria_dbase maria
diset tpcc maria_raiseerror true

puts " DROP SCHEMA STARTED"
deleteschema
puts "DROP SCHEMA COMPLETED"