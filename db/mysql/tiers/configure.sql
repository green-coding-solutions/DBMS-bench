-- Printed by the `Configure DBMS` flow step (paper tier branches). The tier itself is
-- applied through the server command line in the scenario; this only proves it took effect.
SELECT '=== TIER CONFIGURATION CHECK ===';
SELECT CONCAT('CONFIG ', LOWER(variable_name), '=', variable_value) FROM performance_schema.global_variables WHERE variable_name IN ('innodb_buffer_pool_size', 'innodb_redo_log_capacity', 'innodb_buffer_pool_instances', 'innodb_page_cleaners', 'innodb_purge_threads', 'innodb_log_buffer_size', 'innodb_io_capacity', 'innodb_io_capacity_max', 'innodb_change_buffering', 'innodb_adaptive_hash_index', 'innodb_spin_wait_delay', 'innodb_flush_method') ORDER BY 1;
SELECT '=== EFFECTIVE CONFIGURATION (SHOW GLOBAL VARIABLES) ===';
SHOW GLOBAL VARIABLES;
