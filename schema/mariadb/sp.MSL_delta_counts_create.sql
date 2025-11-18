DELIMITER $$

DROP PROCEDURE IF EXISTS MSL_delta_counts $$

CREATE PROCEDURE MSL_delta_counts(IN msl_or_tree INT)
BEGIN
    -- Declare variables
    DECLARE msl INT;

    -- Set msl to the maximum msl_release_num based on the input parameter
    SELECT MAX(msl_release_num) INTO msl
    FROM taxonomy_toc
    WHERE msl_or_tree IS NULL OR msl_release_num = msl_or_tree OR tree_id = msl_or_tree;

    -- Output 'TARGET MSL:' plus msl
    SELECT CONCAT('TARGET MSL:', RTRIM(msl)) AS target_msl;

    -- Main SELECT statement to compute delta counts
    SELECT 
        -- RANK
        tax_level.name AS `rank`,
        -- PREV MSL
        msl - 1 AS old_msl,
        (
            SELECT COUNT(*)
            FROM taxonomy_node tn
            WHERE tn.msl_release_num = msl - 1
              AND tn.level_id = tax_level.id
        ) AS old_msl_ct,
        -- CHANGES
        '+' AS `plus`,
        (
            SELECT COUNT(*)
            FROM taxonomy_node_delta tax_delta
            JOIN taxonomy_node tnode ON tnode.taxnode_id = tax_delta.new_taxid
            WHERE tnode.msl_release_num = msl
              AND tax_delta.is_new = 1
              AND tnode.level_id = tax_level.id
        ) AS `create`,
        (
            SELECT COUNT(*)
            FROM taxonomy_node_delta tax_delta
            JOIN taxonomy_node tnode ON tnode.taxnode_id = tax_delta.new_taxid
            WHERE tnode.msl_release_num = msl
              AND tax_delta.is_promoted = 1
              AND tnode.level_id = tax_level.id
        ) AS create_by_promote,
        (
            SELECT COUNT(*)
            FROM taxonomy_node_delta tax_delta
            JOIN taxonomy_node tnode ON tnode.taxnode_id = tax_delta.new_taxid
            WHERE tnode.msl_release_num = msl
              AND tax_delta.is_demoted = 1
              AND tnode.level_id = tax_level.id
        ) AS create_by_demote,
        (
            SELECT COUNT(DISTINCT delta.new_taxid) - COUNT(DISTINCT delta.prev_taxid)
            FROM taxonomy_node_delta delta
            WHERE delta.prev_taxid IN (
                SELECT tn.taxnode_id
                FROM taxonomy_node tn
                JOIN taxonomy_node_delta tax_delta ON tax_delta.prev_taxid = tn.taxnode_id
                WHERE tn.msl_release_num = msl - 1
                  AND tax_delta.is_split = 1
                  AND tn.level_id = tax_level.id
            )
        ) AS create_by_split,
        '-' AS `minus`,
        (
            SELECT -COUNT(*)
            FROM taxonomy_node_delta tax_delta
            JOIN taxonomy_node tnode ON tnode.taxnode_id = tax_delta.prev_taxid
            WHERE tnode.msl_release_num = msl - 1
              AND tax_delta.is_deleted = 1
              AND tnode.level_id = tax_level.id
        ) AS abolish,
        (
            SELECT COUNT(DISTINCT delta.new_taxid) - COUNT(DISTINCT delta.prev_taxid)
            FROM taxonomy_node_delta delta
            WHERE delta.new_taxid IN (
                SELECT tn.taxnode_id
                FROM taxonomy_node tn
                JOIN taxonomy_node_delta tax_delta ON tax_delta.new_taxid = tn.taxnode_id
                WHERE tn.msl_release_num = msl
                  AND tax_delta.is_merged = 1
                  AND tn.level_id = tax_level.id
            )
        ) AS abolish_by_merge,
        (
            SELECT -COUNT(*)
            FROM taxonomy_node_delta tax_delta
            JOIN taxonomy_node tnode ON tnode.taxnode_id = tax_delta.prev_taxid
            WHERE tnode.msl_release_num = msl - 1
              AND tax_delta.is_promoted = 1
              AND tnode.level_id = tax_level.id
        ) AS abolish_by_promote,
        (
            SELECT -COUNT(*)
            FROM taxonomy_node_delta tax_delta
            JOIN taxonomy_node tnode ON tnode.taxnode_id = tax_delta.prev_taxid
            WHERE tnode.msl_release_num = msl - 1
              AND tax_delta.is_demoted = 1
              AND tnode.level_id = tax_level.id
        ) AS abolish_by_demote,
        '~' AS `same`,
        (
            SELECT COUNT(*)
            FROM taxonomy_node_delta tax_delta
            JOIN taxonomy_node tnode ON tnode.taxnode_id = tax_delta.new_taxid
            WHERE tnode.msl_release_num = msl
              AND tax_delta.is_moved = 1
              AND tnode.level_id = tax_level.id
        ) AS action_move,
        (
            SELECT COUNT(*)
            FROM taxonomy_node_delta tax_delta
            JOIN taxonomy_node tnode ON tnode.taxnode_id = tax_delta.new_taxid
            WHERE tnode.msl_release_num = msl
              AND tax_delta.is_renamed = 1
              AND tnode.level_id = tax_level.id
        ) AS action_rename,
        (
            SELECT COUNT(*)
            FROM taxonomy_node_delta tax_delta
            JOIN taxonomy_node tnode ON tnode.taxnode_id = tax_delta.new_taxid
            WHERE tnode.msl_release_num = msl
              AND tax_delta.is_lineage_updated = 1
              AND tnode.level_id = tax_level.id
        ) AS action_lineage_update,
        -- NEW MSL
        '=' AS `eq`,
        (
            SELECT COUNT(*)
            FROM taxonomy_node tn
            WHERE tn.msl_release_num = msl
              AND tn.level_id = tax_level.id
        ) AS new_msl_ct,
        msl AS new_msl
    FROM taxonomy_level tax_level
    WHERE tax_level.name <> 'tree'
    ORDER BY tax_level.id;

    -- Generate a complete, detailed change list, including all unchanged taxa
    SELECT  
        p.msl,
        p.rank,
        p.name,
        p.taxnode_id,
        '<PREV<' AS `PREV`,
        d.*,
        '>NEXT>' AS `NEXT`,
        n.taxnode_id,
        n.name,
        n.rank,
        n.msl
    FROM taxonomy_node_delta d
    LEFT JOIN taxonomy_node_names p ON p.taxnode_id = d.prev_taxid
    LEFT JOIN taxonomy_node_names n ON n.taxnode_id = d.new_taxid
    WHERE d.msl = msl
      AND (p.msl IS NOT NULL OR n.msl IS NOT NULL)
    ORDER BY IFNULL(n.lineage, p.lineage);
END $$

DELIMITER ;
