/* ================================================================
   Stored procedure  : QC_module_vmr_export_species_count
   Converted from    : SQL-Server to MariaDB
   Preserves         : All original comments and behaviour
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_vmr_export_species_count $$
CREATE PROCEDURE QC_module_vmr_export_species_count
(
    IN p_filter VARCHAR(1000)   -- pass NULL ⇒ default 'ERROR%'
)
BEGIN
    DECLARE v_curr_msl INT;
    /* --------------------------------------------------------------
       Default like the original header
       -------------------------------------------------------------- */
    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;

    /* --------------------------------------------------------------
       Current (latest) MSL release – re-used in several sub-selects
       -------------------------------------------------------------- */
    SELECT MAX(msl_release_num) INTO v_curr_msl FROM taxonomy_toc;

    /* --------------------------------------------------------------
       Main SELECT – identical UNION branches, just MySQL/MariaDB syntax
       -------------------------------------------------------------- */
    SELECT
        'QC_module_vmr_export_species_count'  AS qc_module,    -- OBJECT_NAME(@@PROCID)
        '[vmr_export]'                        AS table_name,
        t.*                                                    -- same columns as before
    FROM
    (
        /* ---------- species missing from VMR ---------------------- */
        SELECT
              'ERROR: species missing from [vmr_export]' AS qc_mesg,
              n.msl_release_num,
              n.lineage,
              1 AS ct
        FROM taxonomy_node AS n
        WHERE n.msl_release_num = v_curr_msl
          AND n.level_id = 600
          AND n.name NOT IN (SELECT `species` FROM vmr_export)

        UNION ALL

        /* ---------- extra species in VMR -------------------------- */
        SELECT
              'ERROR: extra species in [vmr_export] (missing from taxonomy_node)' AS qc_mesg,
              v_curr_msl                                          AS msl_release_num,
              vmr.`species`                                       AS lineage,
              1                                                   AS ct
        FROM vmr_export AS vmr
        WHERE vmr.`species` NOT IN (
                SELECT name
                FROM taxonomy_node
                WHERE msl_release_num = v_curr_msl
                  AND level_id = 600
        )

        UNION ALL

        /* ---------- wrong count of E-records per species ---------- */
        SELECT
              'ERROR: too many/too few E records  in [vmr_export]' AS qc_mesg,
              v_curr_msl                          AS msl_release_num,
              vmr.`species`                       AS lineage,
              COUNT(*)                            AS ct
        FROM vmr_export AS vmr
        GROUP BY vmr.`species`
        HAVING
            1 <> COUNT(CASE WHEN `Exemplar or additional isolate` = 'E' THEN 1 END)

        UNION ALL

        /* ---------- duplicate GenBank accession numbers ----------- */
        SELECT
              'ERROR: two isolates have same accession [vmr_export]' AS qc_mesg,
              v_curr_msl                          AS msl_release_num,
              CASE
                  WHEN vmr.`Virus GENBANK accession` = ''
                       THEN 'MSL40: no accession; N=151'
                  ELSE CONCAT(
                          vmr.`Virus GENBANK accession`,
                          ' [',
                          MIN(CONCAT(`Species`,':',`Exemplar or additional isolate`,':',`Virus name(s)`)),
                          ' | ',
                          MAX(CONCAT(`Species`,':',`Exemplar or additional isolate`,':',`Virus name(s)`)),
                          ']'
                       )
              END                                    AS lineage,
              COUNT(*)                              AS ct
        FROM vmr_export AS vmr
        GROUP BY vmr.`Virus GENBANK accession`
        HAVING COUNT(*) > 1

        UNION ALL

        /* ---------- E-record whose Isolate-Sort <> 1 -------------- */
        SELECT
              'ERROR: E record is not isolate_sort=1 [vmr_export]' AS qc_mesg,
              v_curr_msl                          AS msl_release_num,
              vmr.`Species`                       AS lineage,
              COUNT(*)                            AS ct
        FROM vmr_export AS vmr
        WHERE vmr.`Isolate Sort` <> 1
          AND vmr.`Exemplar or additional isolate` = 'E'
        GROUP BY vmr.`Species`

        UNION ALL

        /* ---------- NULL Isolate-Sort field ----------------------- */
        SELECT
              'ERROR: NULL isolate_sort [vmr_export]' AS qc_mesg,
              v_curr_msl                          AS msl_release_num,
              vmr.`Species`                       AS lineage,
              COUNT(*)                            AS ct
        FROM vmr_export AS vmr
        WHERE vmr.`Isolate Sort` IS NULL
        GROUP BY vmr.`Species`
    ) AS t
    /* --------------------------------------------------------------
       Apply caller’s filter
       -------------------------------------------------------------- */
    WHERE t.qc_mesg LIKE p_filter
    ORDER BY t.msl_release_num DESC, t.qc_mesg, t.lineage;
END$$
DELIMITER ;

-- /* Show only problems (default) */
-- CALL QC_module_vmr_export_species_count();

-- /* Show everything, including OK rows (none in this module) */
-- CALL QC_module_vmr_export_species_count('%');