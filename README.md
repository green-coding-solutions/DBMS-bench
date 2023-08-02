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

 -- URLS for blog

 https://www.hammerdb.com/about.html
https://www.hammerdb.com/blog/uncategorized/how-to-deploy-hammerdb-cli-fast-with-docker/

https://www.tpc.org/tpcc/default5.asp

The TPC-C benchmark is more complex because of its multiple transaction types, more complex database, and overall execution structure. It was approved by the TPC council in 1992 as an OLTP benchmark. The benchmark involves a mix of five concurrent transactions of different types and complexity either executed online or queued for deferred execution. In this post, we will talk about how we’ve performed TPC-C benchmarking with PostgreSQL using the widely accepted open-source benchmarking tool HammerDB. HammerDB has become so popular that the open-source project is now being hosted under TPC-C council’s GitHub repository.

