DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_taxonomy_node_suffixes $$

CREATE PROCEDURE QC_module_taxonomy_node_suffixes(IN filter VARCHAR(1000))
BEGIN
    -- If no filter is provided or it's NULL/empty, set it to 'ERROR%'
--     IF filter IS NULL OR filter = '' THEN
--         SET filter = 'ERROR%';
--     END IF;

    SELECT
        'QC_module_taxonomy_node_suffixes' AS qc_module,
        src.*
    FROM (
        SELECT
            tn.msl_release_num,
            tn.left_idx,
            tn.tree_id,
            tn.taxnode_id,
            tn.name,
            tn.level_id,
            lvl.name AS `rank`,
            lvl.suffix,
            lvl.suffix_viroid,
            lvl.suffix_nuc_acid,
            lvl.suffix_viriform,
            CASE
                WHEN tn.name LIKE CONCAT('%', lvl.suffix) THEN CONCAT('OK: suffix = ', lvl.suffix)
                WHEN tn.name LIKE CONCAT('%', lvl.suffix_viroid) THEN CONCAT('OK: suffix_viriod = ', lvl.suffix_viroid)
                WHEN tn.name LIKE CONCAT('%', lvl.suffix_nuc_acid) THEN CONCAT('OK: suffix_nuc_acid = ', lvl.suffix_nuc_acid)
                WHEN tn.name LIKE CONCAT('%', lvl.suffix_viriform) THEN CONCAT('OK: suffix_viriform = ', lvl.suffix_viriform)
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('genus') AND tn.name LIKE '%virus _' THEN 'OK: (historic pre-MSL32) "Influenza virus *" genus'
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('genus') AND tn.name LIKE '%viruses' THEN 'OK: (historic pre-MSL32) "*viruses"'
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('genus','family') AND tn.name LIKE '%phages' THEN 'OK: (historic pre-MSL32) "*phages"'
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('genus') AND tn.name LIKE '%phage' THEN 'OK: (historic pre-MSL32) "*phage"'
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('genus') AND tn.name LIKE '%genus%' THEN 'OK: (historic pre-MSL32) "*genus*"'
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('family') AND tn.name LIKE '%family' THEN 'OK: (historic pre-MSL32) "*family"'
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('genus','family') AND tn.name LIKE '%group%' THEN 'OK: (historic pre-MSL32) "*group*"'
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('genus') AND tn.name LIKE '%viroids%' THEN 'OK: (historic pre-MSL32) "*viroids*"'
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('family') AND tn.name LIKE '%viroids%' THEN 'OK: (historic pre-MSL32) "*viroids*"'
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('genus') AND tn.name = 'Influenza virus A and B' THEN 'OK: (historic pre-MSL32) "Influenza virus A and B"'
                WHEN tn.msl_release_num < 32 AND lvl.name IN ('genus') AND tn.name = 'Lipid phage PM2' THEN 'OK: (historic pre-MSL32) "Lipid phage PM2"'
                WHEN tn.msl_release_num < 38 AND lvl.name IN ('genus') AND tn.name = 'Tunggulviirus' THEN 'OK: (historic pre-MSL38) "Tunggulviirus" (typo)'
                WHEN tn.msl_release_num < 38 AND lvl.name IN ('genus') AND tn.name = 'Incheonvrus' THEN 'OK: (historic pre-MSL38) "Incheonvrus" (typo)'
                ELSE 'ERROR: SUFFIX MISMATCH - look in taxonomy_level for legal suffix lists'
            END AS mesg
        FROM taxonomy_node tn
        JOIN taxonomy_level lvl ON lvl.id = tn.level_id
        WHERE tn.msl_release_num IS NOT NULL
          AND tn.name IS NOT NULL
          AND tn.name NOT IN ('Unassigned')
          AND lvl.suffix IS NOT NULL
    ) AS src
    WHERE src.mesg LIKE filter
    ORDER BY msl_release_num DESC, left_idx;

END$$

DELIMITER ;