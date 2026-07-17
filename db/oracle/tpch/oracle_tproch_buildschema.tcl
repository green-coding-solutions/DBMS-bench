#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db ora
dbset bm TPC-H

diset connection system_user system
diset connection system_password oracle
diset connection instance oracle_container:1521/FREEPDB1

diset tpch scale_fact 1
diset tpch num_tpch_threads 4
diset tpch tpch_user tpch
diset tpch tpch_pass tpch
diset tpch tpch_def_tab users
diset tpch tpch_def_temp temp

puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
