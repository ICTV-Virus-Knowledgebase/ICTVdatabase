/* ================================================================
   Stored procedure  : QC_module_taxonomy_toc_needs_reindex
   Purpose           : Report trees still flagged for reindexing
   Behaviour         : Returns no rows when no trees are flagged
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_taxonomy_toc_needs_reindex $$
CREATE PROCEDURE QC_module_taxonomy_toc_needs_reindex
(
    IN p_filter VARCHAR(1000) DEFAULT NULL
)
BEGIN
    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;

    SELECT
        'QC_module_taxonomy_toc_needs_reindex' AS qc_module,
        '[taxonomy_toc]' AS table_name,
        'ERROR: tree needs reindex' AS qc_mesg,
        t.tree_id,
        t.msl_release_num,
        t.version_tag,
        t.needs_reindex
    FROM taxonomy_toc AS t
    WHERE t.needs_reindex = 1
      AND 'ERROR: tree needs reindex' LIKE p_filter
    ORDER BY t.tree_id;
END$$

DELIMITER ;

-- Show only flagged trees (default)
-- CALL QC_module_taxonomy_toc_needs_reindex();

-- Show all rows that match your filter string
-- CALL QC_module_taxonomy_toc_needs_reindex('%');
