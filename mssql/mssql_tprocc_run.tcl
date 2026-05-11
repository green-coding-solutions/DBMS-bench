#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db mssqls
dbset bm TPC-C
diset connection mssqls_tcp true
diset connection mssqls_port 1433
diset connection mssqls_azure false
diset connection mssqls_encrypt_connection true
diset connection mssqls_trust_server_cert true
diset connection mssqls_linux_server mssql_container
diset connection mssqls_uid sa
diset connection mssqls_pass Mssql1234!
diset connection mssqls_linux_authent sql
diset connection mssqls_linux_odbc {ODBC Driver 18 for SQL Server}
diset tpcc mssqls_dbase tpcc
diset tpcc mssqls_driver timed
diset tpcc mssqls_rampup 2
diset tpcc mssqls_duration 5
diset tpcc mssqls_allwarehouse true
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_raiseerror true
loadscript
puts "TEST STARTED"
vuset vu vcpu
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "TEST COMPLETE"
set of [ open /tmp/mssql_tprocc w ]
puts $of $jobid
close $of
