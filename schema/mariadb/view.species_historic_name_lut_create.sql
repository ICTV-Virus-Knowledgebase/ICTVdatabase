DROP VIEW IF EXISTS `species_historic_name_lut`;

CREATE VIEW `species_historic_name_lut` AS
SELECT
    MIN(old.msl_release_num) AS first_msl,
    MAX(old.msl_release_num) AS last_msl,
    old.name AS old_name,
    old.ictv_id AS old_ictv_id,
    CASE 
        WHEN MAX(new.taxnode_id) IS NULL THEN 'abolished'
        WHEN old.name = MAX(new.name) AND old.name = MIN(new.name) THEN 'same'
        WHEN old.name <> MAX(new.name) AND MAX(new.name) = MIN(new.name) AND MAX(is_merged) = 1 THEN 'renamed/merged'
        WHEN old.name <> MAX(new.name) AND MAX(new.name) = MIN(new.name) AND MAX(is_merged) = 0 THEN 'renamed'
        WHEN MAX(new.name) <> MIN(new.name) THEN 'split'
        ELSE 'error'
    END AS action,
    MAX(new.msl_release_num) AS new_msl,
    MAX(new.name) AS new_name,
    MAX(new.taxnode_id) AS new_taxnode_id,
    CASE 
        WHEN MAX(new.name) = MIN(new.name) THEN '===='
        ELSE CONCAT('<', RTRIM(COUNT(DISTINCT new.name)), '>')
    END AS sep2,
    MAX(ms.is_merged) AS is_merge,
    MAX(ms.is_split) AS is_split,
    MIN(new.name) AS new_name2,
    MIN(new.taxnode_id) AS new_taxnode_id2,
    MAX(new.left_idx) AS new_sort
FROM taxonomy_node_names old
LEFT OUTER JOIN taxonomy_node_merge_split ms 
    ON ms.prev_ictv_id = old.ictv_id 
    AND ms.rev_count = 0
LEFT OUTER JOIN taxonomy_node_names new 
    ON ms.next_ictv_id = new.ictv_id 
    AND new.msl_release_num = (SELECT MAX(msl_release_num) FROM taxonomy_toc)
    AND new.rank = 'species'
WHERE old.msl_release_num IS NOT NULL 
AND old.level_id = 600
GROUP BY old.name, old.ictv_id;
