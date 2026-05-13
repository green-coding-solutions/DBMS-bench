#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db pg
dbset bm TPC-C
diset connection pg_host postgres_container
diset connection pg_port 5432
diset connection pg_sslmode disable
diset tpcc pg_superuser postgres
diset tpcc pg_superuserpass postgres
diset tpcc pg_defaultdbase postgres
diset tpcc pg_user postgres
diset tpcc pg_pass postgres
diset tpcc pg_dbase postgres
diset tpcc pg_count_ware 1
diset tpcc pg_num_vu 1
diset tpcc pg_partition false
diset tpcc pg_raiseerror true
puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
