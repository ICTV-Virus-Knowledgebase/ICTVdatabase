/* ================================================================
   Stored procedure  : QC_module_vmr_export_species_count
   Converted from    : SQL-Server to MariaDB
   Accession QC      : Normalized individual accessions, distinct isolates
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
       Main SELECT – species, exemplar, accession and sort checks
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

        /* Individual GenBank/RefSeq accessions, ignoring labels, versions
           and repeats within one isolate. Restrict to exported isolates. */
        SELECT
              'ERROR: two isolates have same accession [vmr_export]' AS qc_mesg,
              v_curr_msl AS msl_release_num,
              CONCAT(a.accession, ' [',
                  GROUP_CONCAT(DISTINCT CONCAT(a.species_name, ':', a.isolate_type,
                      ':', a.isolate_id) ORDER BY a.isolate_id SEPARATOR ' | '),
                  ']') AS lineage,
              COUNT(DISTINCT a.isolate_id) AS ct
        FROM (
            SELECT DISTINCT si.isolate_id, si.species_name, si.isolate_type,
                acc.accession
            FROM species_isolates si
            JOIN taxonomy_node_names tn ON tn.taxnode_id = si.taxnode_id
            JOIN JSON_TABLE(
                CONCAT('["', REGEXP_REPLACE(REGEXP_REPLACE(
                    UPPER(CONCAT_WS(';', si.genbank_accessions, si.refseq_accessions)),
                    '\\.[0-9]*', ''), '[^A-Z0-9_]+', '","'), '"]'),
                '$[*]' COLUMNS (accession VARCHAR(32) PATH '$')
            ) acc
            WHERE tn.species <> 'abolished'
              AND COALESCE(si.update_change, '') <> 'abolished'
              AND acc.accession REGEXP '^[A-Z]{1,6}_?[0-9]{5,}$'
        ) a
        GROUP BY a.accession
        HAVING COUNT(DISTINCT a.isolate_id) > 1

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