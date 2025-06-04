/* ================================================================
   Stored procedure  : QC_module_taxonomy_node_delta
   Converted from    : SQL-Server to MariaDB
   Preserves         : Original comments & behaviour
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_taxonomy_node_delta $$
CREATE PROCEDURE QC_module_taxonomy_node_delta
(
    IN p_filter VARCHAR(1000)               -- NULL ⇒ 'ERROR%'
)
BEGIN
    /* -----------------------------------------------------------------
       Provide the same default that SQL-Server had in its header
       ----------------------------------------------------------------- */
    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;

    /* -----------------------------------------------------------------
       Main query (structurally identical to original T-SQL)
       ----------------------------------------------------------------- */
    SELECT
        'QC_module_taxonomy_node_delta'  AS qc_module,
        '[taxonomy_node_delta]'          AS table_name,
        src.*                            /* all original columns */
    FROM
    (
        /* =============================================================
           UNDERLYING ANALYSIS – two UNION branches
           =============================================================*/
        SELECT
            'ERROR: new_taxid=NULL, but not an ABOLISH'       AS qc_mesg,
            d.msl,
            d.prev_taxid,
            d.new_taxid,
            d.tag_csv2,
            n.lineage,
            n.out_target                                      AS target
        FROM taxonomy_node_delta AS d
        LEFT JOIN taxonomy_node  AS n  ON n.taxnode_id = d.prev_taxid
        WHERE d.new_taxid IS NULL
          AND d.is_deleted = 0

        UNION ALL

        SELECT
            'ERROR: prev_taxid=NULL, but not a NEW'           AS qc_mesg,
            d.msl,
            d.prev_taxid,
            d.new_taxid,
            d.tag_csv2,
            n.lineage,
            n.in_target                                       AS target
        FROM taxonomy_node_delta AS d
        LEFT JOIN taxonomy_node  AS n  ON n.taxnode_id = d.new_taxid
        WHERE d.prev_taxid IS NULL
          AND d.is_new = 0
    ) AS src
    /* -----------------------------------------------------------------
       Apply caller’s filter (default 'ERROR%')
       ----------------------------------------------------------------- */
    WHERE src.qc_mesg LIKE p_filter
    ORDER BY msl DESC, lineage, qc_mesg;
END$$
DELIMITER ;

-- /* Default – show only “ERROR” rows */
-- CALL QC_module_taxonomy_node_delta();

-- /* Show everything */
-- CALL QC_module_taxonomy_node_delta('%');

-- /* Show only rows whose message starts with 'OK' (there are none in this module) */
-- CALL QC_module_taxonomy_node_delta('OK%');