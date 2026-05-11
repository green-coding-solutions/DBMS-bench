#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db pg
dbset bm TPC-C
diset connection pg_host cockroachdb_container
diset connection pg_port 26257
diset connection pg_sslmode disable
diset tpcc pg_superuser root
diset tpcc pg_superuserpass ""
diset tpcc pg_defaultdbase defaultdb
diset tpcc pg_user root
diset tpcc pg_pass ""
diset tpcc pg_dbase defaultdb
diset tpcc pg_raiseerror true
puts "DROP SCHEMA STARTED"
deleteschema
puts "DROP SCHEMA COMPLETED"
