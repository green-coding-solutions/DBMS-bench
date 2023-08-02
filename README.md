# DBMS-bench
A tool that benchmarks various DBMS systems agains each other and looks at energy usage

echo "BUILD HAMMERDB SCHEMA"
./hammerdbcli auto ./scripts/tcl/postgres/tprocc/pg_tprocc_buildschema.tcl

echo "RUN HAMMERDB TEST"
./hammerdbcli auto ./scripts/tcl/postgres/tprocc/pg_tprocc_run.tcl

echo "DROP HAMMERDB SCHEMA"
./hammerdbcli auto ./scripts/tcl/postgres//tprocc/pg_tprocc_deleteschema.tcl


 docker cp  pg_tprocc_buildschema.tcl hammerdb_container:/home/HammerDB-4.8/scripts/python/postgres/tprocc/pg_tprocc_buildschema.tcl
 docker exec hammerdb_container ./hammerdbcli tcl auto /home/HammerDB-4.8/scripts/python/postgres/tprocc/pg_tprocc_buildschema.tcl


 /scripts/tcl/maria/tprocc