#!/bin/tclsh
# maintainer: Pooja Jain
# T2+ (COLUMNAR sub-tier) build for SQL Server TPC-H: enables HammerDB's
# clustered columnstore option (mssqls_colstore true) so the TPC-H tables are
# built as columnstore — the strongest analytical design SQL Server offers.
# MAXDOP raised to 4. This is the columnar counterpart to the row-store
# mssql_tproch_buildschema.t2.tcl.

puts "SETTING CONFIGURATION"
dbset db mssqls
dbset bm TPC-H

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

diset tpch mssqls_scale_fact 1
diset tpch mssqls_maxdop 4
diset tpch mssqls_num_tpch_threads 4
diset tpch mssqls_tpch_dbase tpch
diset tpch mssqls_colstore true
# load via INSERTs, not bcp: the hammerdb image has the ODBC driver but no bcp binary
diset tpch mssqls_tpch_use_bcp false

puts "SCHEMA BUILD STARTED"
buildschema
puts "SCHEMA BUILD COMPLETED"
