#!/bin/tclsh
# maintainer: Pooja Jain

puts "SETTING CONFIGURATION"
dbset db maria
dbset bm TPC-H

diset connection maria_host mariadb_container
diset connection maria_port 3306

diset tpch maria_scale_fact 1
diset tpch maria_tpch_user root
diset tpch maria_tpch_pass maria
diset tpch maria_tpch_dbase tpch
diset tpch maria_tpch_storage_engine innodb
diset tpch maria_total_querysets 1

loadscript
puts "TEST STARTED"
vuset vu 1
vucreate
set jobid [ vurun ]
vudestroy
puts "TEST COMPLETE"
set of [ open /tmp/maria_tproch w ]
puts $of $jobid
close $of
