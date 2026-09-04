-- Printed by the `Configure DBMS` flow step (paper tier branches). The tier itself is
-- applied through the server command line in the scenario; this only proves it took effect.
SELECT '=== TIER CONFIGURATION CHECK ===';
SELECT CONCAT('CONFIG ', LOWER(variable_name), '=', variable_value) FROM information_schema.global_variables WHERE variable_name IN ('innodb_buffer_pool_size', 'innodb_log_file_size', 'innodb_purge_threads', 'innodb_log_buffer_size', 'innodb_io_capacity', 'innodb_io_capacity_max', 'innodb_adaptive_hash_index', 'innodb_spin_wait_delay', 'innodb_flush_method') ORDER BY 1;
SELECT '=== EFFECTIVE CONFIGURATION (SHOW GLOBAL VARIABLES) ===';
SHOW GLOBAL VARIABLES;
