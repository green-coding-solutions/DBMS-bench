#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db mysql
dbset bm TPC-C

diset connection mysql_host mysql_container
diset connection mysql_port 3307
diset connection mysql_socket /tmp/mysql.sock

diset tpcc mysql_user mysql
diset tpcc mysql_pass mysql
diset tpcc mysql_dbase mysql
puts " DROP SCHEMA STARTED"
deleteschema
puts "DROP SCHEMA COMPLETED"