#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db mysql
dbset bm TPC-H

diset connection mysql_host mysql_container
diset connection mysql_port 3306

diset tpch mysql_scale_fact 1
diset tpch mysql_tpch_user root
diset tpch mysql_tpch_pass mysql
diset tpch mysql_tpch_dbase tpch
diset tpch mysql_tpch_storage_engine innodb
diset tpch mysql_total_querysets 1

loadscript
puts "TEST STARTED"
vuset vu 1
vucreate
set jobid [ vurun ]
vudestroy
puts "TEST COMPLETE"
set of [ open /tmp/mysql_tproch w ]
puts $of $jobid
close $of
