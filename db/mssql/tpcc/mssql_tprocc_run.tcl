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

diset tpcc mssqls_dbase tpcc
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup 2
diset tpcc mssqls_duration 5
diset tpcc mssqls_checkpoint false
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true

# hammerdbcli tears the Virtual Users down rampup+duration+keepalive_margin seconds after
# vurun, and the 60s default was too tight for Oracle's monitor VU to finish its end-of-run
# AWR snapshot - it was killed mid-query and the run reported no result. Widened here too as
# cheap insurance: the timer returns as soon as all VUs complete, so it costs no runtime.
giset commandline keepalive_margin 300

loadscript
puts "TEST STARTED"
vuset vu 4
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
