/* ================================================================
   Stored procedure  : QC_module_taxonomy_node_orphan_taxa
   Converted from    : SQL-Server to MariaDB
   Preserves         : Original comments & behaviour
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_taxonomy_node_orphan_taxa $$
CREATE PROCEDURE QC_module_taxonomy_node_orphan_taxa
(
    IN p_filter VARCHAR(1000)        -- pass NULL ⇒ 'ERROR%'
)
BEGIN
    /* --------------------------------------------------------------
       Default parameter (same as T-SQL header)
       -------------------------------------------------------------- */
    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;

    /* --------------------------------------------------------------
       Emit identical result-set
       -------------------------------------------------------------- */
    SELECT
        'QC_module_taxonomy_node_orphan_taxa'   AS qc_module,     -- OBJECT_NAME(@@PROCID)
        src.msl_release_num,
        src.taxnode_id,
        src.name,
        src.level_id,
        src.left_idx,
        src.right_idx,
        src.parent_id,
        src.parent_name,
        src.rank,
        src.mesg
    FROM
    (
        SELECT
              tn.msl_release_num,
              tn.taxnode_id,
              tn.name,
              tn.level_id,
              tn.left_idx,
              tn.right_idx,
              tn.parent_id,
              p.name                                          AS parent_name,
              lvl.name                                        AS rank,
              /* --------------------------------------------------
                 Build message exactly like SQL-Server version
                 -------------------------------------------------- */
              CASE
                  WHEN tn.left_idx  IS NULL THEN 'ERROR: left_idx = NULL'
                  WHEN tn.right_idx IS NULL THEN 'ERROR: right_idx = NULL'
                  ELSE 'OK: left and right idx'
              END                                             AS mesg
        FROM taxonomy_node  AS tn
        JOIN taxonomy_level AS lvl ON lvl.id = tn.level_id
        LEFT JOIN taxonomy_node AS p ON p.taxnode_id = tn.parent_id
        WHERE tn.msl_release_num IS NOT NULL
    ) AS src
    WHERE src.mesg LIKE p_filter
    ORDER BY src.msl_release_num DESC,
             src.left_idx;
END$$
DELIMITER ;

-- /* List only problems (default) */
-- CALL QC_module_taxonomy_node_orphan_taxa();

-- /* Show every node, including OK ones */
-- CALL QC_module_taxonomy_node_orphan_taxa('%');