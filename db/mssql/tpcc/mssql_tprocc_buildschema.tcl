#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db mssqls
dbset bm TPC-C

diset connection mssqls_tcp true
diset connection mssqls_port 1433
diset connection mssqls_azure false
diset connection mssqls_encrypt_connection true
diset connection mssqls_trust_server_cert true
diset connection mssqls_authentication windows
diset connection mssqls_server {(local)}
diset connection mssqls_linux_server mssql_container
diset connection mssqls_uid sa
diset connection mssqls_pass Hammerdb_2024
diset connection mssqls_linux_authent sql
diset connection mssqls_linux_odbc {ODBC Driver 18 for SQL Server}

set vu 4
# EDBT 2027 paper: 10 warehouses per virtual user (40 in total, about 4 GB). Halves the
# unmeasured build time and lets a tuned buffer pool hold the data set at T1 and T2.
set warehouse [ expr {$vu * 10} ]
diset tpcc mssqls_count_ware $warehouse
diset tpcc mssqls_num_vu $vu
diset tpcc mssqls_dbase tpcc
# bulk-load via bcp (much faster than INSERTs). bcp ships at
# /opt/mssql-tools18/bin/bcp but is not on PATH, so the build command
# in mssql.yml prepends it to PATH before invoking hammerdbcli. bcp also
# stages intermediate .dat files in $TMP, which is unset in the hammerdb
# image, so mssql.yml exports TMP=/tmp on the same command line (without
# it every worker VU dies with: can't read "::env(TMP)": no such variable).
diset tpcc mssqls_use_bcp true

puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
