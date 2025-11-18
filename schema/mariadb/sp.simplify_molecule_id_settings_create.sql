DELIMITER $$

DROP PROCEDURE IF EXISTS sp_simplify_molecule_id_settings $$

CREATE PROCEDURE sp_simplify_molecule_id_settings(
    IN in_msl INT
)
BEGIN
    DECLARE current_msl INT;
    DECLARE tree_id INT;
    DECLARE affected_rows INT;

    -- Determine the MSL using udf_getMSL if needed
    IF in_msl IS NULL OR in_msl < 1 THEN
        SET current_msl = udf_getMSL(NULL);
    ELSE
        SET current_msl = in_msl;
    END IF;

    SELECT MAX(tree_id), MAX(msl_release_num) INTO tree_id, current_msl
    FROM taxonomy_toc
    WHERE tree_id = current_msl 
       OR msl_release_num = current_msl 
       OR (msl_release_num IS NOT NULL AND in_msl IS NULL);

    SELECT CONCAT('TARGET MSL=', current_msl, ' TARGET TREE=', tree_id) AS debug_info;

    -- First WHILE loop (label: loop1)
    loop1: WHILE 1=1 DO
        UPDATE taxonomy_node tn
        JOIN (
            SELECT 
                t.left_idx, t.taxnode_id, t.`rank`, t.lineage, t.molecule_id, t.inher_molecule_id,
                COUNT(n.taxnode_id) AS n_ct, COUNT(n.inher_molecule_id) AS im_ct,
                MIN(n.inher_molecule) AS im_min, MAX(n.inher_molecule) AS im_max,
                MIN(n.inher_molecule_id) AS consensus_mol_id
            FROM taxonomy_node_names t
            JOIN taxonomy_node_names n ON n.left_idx BETWEEN t.left_idx AND t.right_idx 
                                       AND n.tree_id = t.tree_id 
                                       AND n.taxnode_id <> t.taxnode_id
            WHERE t.msl_release_num = current_msl 
              AND (
                    (t.level_id >= 200 AND (t.`order` <> 'Bunyavirales' OR t.`order` IS NULL))
                    OR
                    (t.level_id >= 500 AND t.`order` = 'Bunyavirales')
                  )
            GROUP BY t.left_idx, t.taxnode_id, t.`rank`, t.lineage, t.molecule_id, t.inher_molecule_id
            HAVING COUNT(n.taxnode_id) = COUNT(n.inher_molecule_id)
              AND MIN(n.inher_molecule_id) = MAX(n.inher_molecule_id)
              AND (
                   t.molecule_id IS NULL
                   AND (
                        t.inher_molecule_id IS NULL
                        OR t.inher_molecule_id <> MIN(n.inher_molecule_id)
                      )
                  )
            ORDER BY t.left_idx
            LIMIT 1000000
        ) AS src ON src.taxnode_id = tn.taxnode_id
        SET tn.molecule_id = src.consensus_mol_id;

        SET affected_rows = ROW_COUNT();
        IF affected_rows = 0 THEN
            LEAVE loop1;
        END IF;
    END WHILE loop1;

    -- Second WHILE loop (label: loop2)
    loop2: WHILE 1=1 DO
        UPDATE taxonomy_node tn
        JOIN taxonomy_node p ON p.taxnode_id = tn.parent_id
        SET tn.molecule_id = NULL
        WHERE tn.molecule_id = p.inher_molecule_id
          AND tn.msl_release_num = current_msl;

        SET affected_rows = ROW_COUNT();
        IF affected_rows = 0 THEN
            LEAVE loop2;
        END IF;
    END WHILE loop2;

    -- Optional: If you need stats output, you can do so here:
    -- SELECT msl, CASE WHEN tag_csv='' THEN 'UNCHANGED' ELSE tag_csv END AS change_type, COUNT(*) AS counts
    -- FROM taxonomy_node_delta
    -- WHERE msl = current_msl
    -- GROUP BY msl, tag_csv
    -- ORDER BY msl, tag_csv;

    -- SELECT msl, CASE WHEN tag_csv2='' THEN 'UNCHANGED' ELSE tag_csv2 END AS change_type, COUNT(*) AS counts
    -- FROM taxonomy_node_delta
    -- WHERE msl = current_msl
    -- GROUP BY msl, tag_csv2
    -- ORDER BY msl, tag_csv2;

END$$

DELIMITER ;