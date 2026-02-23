DELIMITER $$

DROP PROCEDURE IF EXISTS QC_run_modules $$
CREATE PROCEDURE QC_run_modules(IN module_filter VARCHAR(200))
BEGIN
    -- All DECLAREs must come first
    DECLARE done INT DEFAULT 0;
    DECLARE sp_name VARCHAR(200);
    DECLARE sql_statement TEXT;
    DECLARE v_filter VARCHAR(200);

    DECLARE qc_module_cursor CURSOR FOR
        SELECT ROUTINE_NAME
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE ROUTINE_TYPE = 'PROCEDURE'
          AND ROUTINE_SCHEMA = DATABASE()
          AND ROUTINE_NAME NOT LIKE 'dt_%'
          AND ROUTINE_NAME NOT LIKE 'sp_%diagram%'
          AND ROUTINE_NAME LIKE CONCAT(
                'QC_module_',
                IF(module_filter IS NULL OR module_filter = '', '%', module_filter),
                '%'
              )
        ORDER BY ROUTINE_NAME;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Normalize the filter once
    -- NULL means pass NULL through to modules (use each module's default behavior)
    -- Empty string means "ERROR%" (legacy behavior)
    SET v_filter := IF(
        module_filter IS NULL,
        NULL,
        IF(module_filter = '', 'ERROR%', module_filter)
    );

    OPEN qc_module_cursor;

    read_loop: LOOP
        FETCH qc_module_cursor INTO sp_name;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Special-case the proc that needs 2 params (filter, target_name)
        IF sp_name = 'QC_module_taxonomy_node_ictv_resurrection' THEN
            IF v_filter IS NULL THEN
                SET sql_statement := CONCAT('CALL `', sp_name, '`(NULL, NULL)');
            ELSE
                SET sql_statement := CONCAT('CALL `', sp_name, '`(', QUOTE(v_filter), ', NULL)');
            END IF;
        ELSE
            -- Everyone else: single-parameter signature (filter)
            IF v_filter IS NULL THEN
                SET sql_statement := CONCAT('CALL `', sp_name, '`(NULL)');
            ELSE
                SET sql_statement := CONCAT('CALL `', sp_name, '`(', QUOTE(v_filter), ')');
            END IF;
        END IF;

        -- Optional: show what we’re about to run
        SELECT CONCAT('SQL: ', sql_statement) AS debug_output;

        PREPARE stmt FROM sql_statement;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP read_loop;

    CLOSE qc_module_cursor;
END$$

DELIMITER ;

-- call QC_run_modules('%'); to get all okay records.
-- call QC_run_modules('') or QC_run_modules(NULL) to get all records with errors.
