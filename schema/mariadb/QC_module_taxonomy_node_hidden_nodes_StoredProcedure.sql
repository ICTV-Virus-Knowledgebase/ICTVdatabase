/* ================================================================
   Stored procedure  : QC_module_taxonomy_node_hidden_nodes
   Converted from    : SQL-Server to MariaDB
   Preserves         : Original comments & behaviour
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_taxonomy_node_hidden_nodes $$
CREATE PROCEDURE QC_module_taxonomy_node_hidden_nodes
(
    IN p_filter VARCHAR(1000)          -- pass NULL ⇒ 'ERROR%'
)
BEGIN
    /* -----------------------------------------------------------------
       Provide same default that the T-SQL header supplied
       ----------------------------------------------------------------- */
    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;

    /* -----------------------------------------------------------------
       Main query (one CTE-less nesting level instead of SQL-Server sub-SELECTs)
       ----------------------------------------------------------------- */
    SELECT
        'QC_module_taxonomy_node_hidden_nodes' AS qc_module,   -- OBJECT_NAME(@@PROCID) in T-SQL
        '[taxonomy_node]'                      AS table_name,
        src.msl_release_num                    AS msl,
        src.taxnode_id,
        src.left_idx,
        src.rank,
        src.name,
        src.is_hidden,
        src.is_deleted,
        src.is_typo,
        src.is_obsolete,
        src.notes,
        /* prepend 'OK' / 'ERROR:' exactly like the original */
        CASE
            WHEN src.errors = '' THEN 'OK'
            ELSE CONCAT('ERROR:', src.errors)
        END                                              AS qc_mesg
    FROM
    (
        /* ------------------------------------------------------------
           Underlying analysis identical to SQL-Server logic
           ------------------------------------------------------------ */
        SELECT
            n.msl_release_num,
            n.taxnode_id,
            n.left_idx,
            r.name                                            AS rank,
            n.name,
            n.is_hidden,
            n.is_deleted,
            n.is_typo,
            n.is_obsolete,
            n.notes,
            /* build error string when node is wrongly hidden */
            CASE
                WHEN n.is_hidden = 1
                     AND n.level_id <> 100
                     AND (n.is_deleted + n.is_typo + n.is_obsolete) = 0
                THEN CONCAT('HIDDEN[', r.name, ':', n.name, '];')
                ELSE ''
            END                                              AS errors
        FROM taxonomy_node  AS n
        JOIN taxonomy_level AS r  ON r.id = n.level_id
        WHERE n.msl_release_num IS NOT NULL
    ) AS src
    /* -----------------------------------------------------------------
       Caller’s filter (default 'ERROR%')
       ----------------------------------------------------------------- */
    WHERE (CASE
               WHEN src.errors = '' THEN 'OK'
               ELSE CONCAT('ERROR:', src.errors)
           END) LIKE p_filter
    ORDER BY src.msl_release_num DESC,
             src.left_idx,
             qc_mesg;
END$$
DELIMITER ;

-- /* Default – show only “ERROR” rows */
-- CALL QC_module_taxonomy_node_hidden_nodes();

-- /* Show every row (OK + ERROR) */
-- CALL QC_module_taxonomy_node_hidden_nodes('%');

-- /* Show only rows whose qc_mesg starts with 'OK' */
-- CALL QC_module_taxonomy_node_hidden_nodes('OK%');