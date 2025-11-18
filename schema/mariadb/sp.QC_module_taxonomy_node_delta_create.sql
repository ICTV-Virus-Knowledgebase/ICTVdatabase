/* ================================================================
   Stored procedure : QC_module_taxonomy_node_delta
   Converted        : SQL-Server ➜ MariaDB 10.11          (2025-06-18)
   Purpose          : QC – flag unexpected NULLs / missing rows in
                      taxonomy_node_delta
   Notes            : OBJECT_NAME(@@PROCID) has no analogue in MariaDB,
                      so the literal module name is returned instead.
   ================================================================ */

DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_taxonomy_node_delta $$
CREATE PROCEDURE QC_module_taxonomy_node_delta
(
    IN  p_filter VARCHAR(1000)   -- what to keep
)
BEGIN

    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;
    /* -------------------------------------------------------------
       Core query (unchanged logic – two UNION-ed branches)
       ------------------------------------------------------------- */
    WITH qc_src AS (
        /* --- branch #1 : new_taxid is NULL but row is NOT an ABOLISH --- */
        SELECT
            'ERROR: new_taxid=NULL, but not an ABOLISH'            AS qc_mesg,
            d.msl,
            d.prev_taxid,
            n.ictv_id,
            d.new_taxid,
            d.tag_csv2,
            n.lineage,
            n.out_target                                            AS target
        FROM   taxonomy_node_delta AS d
        LEFT   JOIN taxonomy_node        AS n ON n.taxnode_id = d.prev_taxid
        WHERE  d.new_taxid IS NULL
          AND  d.is_deleted = 0

        UNION ALL

        /* --- branch #2 : prev_taxid is NULL but row is NOT a NEW ------- */
        SELECT
            'ERROR: prev_taxid=NULL, but not a NEW'                 AS qc_mesg,
            d.msl,
            d.prev_taxid,
            n.ictv_id,
            d.new_taxid,
            d.tag_csv2,
            n.lineage,
            n.in_target                                             AS target
        FROM   taxonomy_node_delta AS d
        LEFT   JOIN taxonomy_node        AS n ON n.taxnode_id = d.new_taxid
        WHERE  d.prev_taxid IS NULL
          AND  d.is_new = 0
    )

    /* -------------------------------------------------------------
       Final select with module / table id & optional filter
       ------------------------------------------------------------- */
    SELECT
        'QC_module_taxonomy_node_delta'         AS qc_module,
        '[taxonomy_node_delta]'                 AS table_name,
        qs.*
    FROM   qc_src AS qs
    WHERE  qs.qc_mesg LIKE p_filter
    ORDER  BY qs.msl DESC,
              qs.lineage,
              qs.qc_mesg;
END$$
DELIMITER ;

-- only errors (default)
-- CALL QC_module_taxonomy_node_delta();

-- show everything
-- CALL QC_module_taxonomy_node_delta('%');