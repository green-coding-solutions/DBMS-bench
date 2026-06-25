#!/bin/tclsh
# maintainer: Pooja Jain

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
diset tpcc pg_tspace pg_default
diset tpcc pg_raiseerror true



puts "DROP SCHEMA STARTED"
deleteschema
puts "DROP SCHEMA COMPLETED"