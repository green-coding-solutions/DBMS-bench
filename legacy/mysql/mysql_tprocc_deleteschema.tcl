#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db mysql
dbset bm TPC-C

diset connection mysql_host mysql_container
diset connection mysql_port 3306

diset tpcc mysql_user mysql
diset tpcc mysql_pass mysql
# The only change to the 2023 script. `mysql` is MySQL's own system schema, so HammerDB
# refuses to build into it. `tpcc` is created empty by MYSQL_DATABASE in legacy/compose.yml.
diset tpcc mysql_dbase tpcc
diset tpcc mysql_raiseerror true


puts " DROP SCHEMA STARTED"
deleteschema
puts "DROP SCHEMA COMPLETED"