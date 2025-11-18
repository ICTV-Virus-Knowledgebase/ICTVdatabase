DELIMITER $$

DROP PROCEDURE IF EXISTS initializeJsonColumn $$

CREATE PROCEDURE initializeJsonColumn(IN treeID INT)
BEGIN

    -- Variable declarations
    DECLARE current_id INT;
    DECLARE rankIndex INT;
    DECLARE taxNodeID INT;
    DECLARE childJSON LONGTEXT;
    DECLARE done INT DEFAULT 0;
    DECLARE group_concat_max_len_value INT;

    -- Cursor declaration
    DECLARE ranked_node_cursor CURSOR FOR
        SELECT 
            tj.id,
            tj.rank_index,
            tj.taxnode_id
        FROM taxonomy_json tj
        WHERE tj.tree_id = treeID
        ORDER BY tj.rank_index DESC;

    -- Handler for cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Set group_concat_max_len unconditionally at the start
    SET SESSION group_concat_max_len = 10000000;

    -- LRM 11-18-2024: Setting this at the beginning to avoid a row being truncated when populateTaxonomyJsonForAllReleases is
    -- Increase group_concat_max_len if necessary
    -- SELECT @@group_concat_max_len INTO group_concat_max_len_value;
    -- IF group_concat_max_len_value < 1000000 THEN
    --     SET SESSION group_concat_max_len = 1000000;
    -- END IF;

    -- ==========================================================================================================
    -- Populate the JSON column of every taxonomy_json record.
    -- ==========================================================================================================
    UPDATE taxonomy_json tj
    JOIN taxonomy_json_rank tr ON (
        tr.rank_index = tj.rank_index
        AND tr.tree_id = treeID
    )
    LEFT JOIN taxonomy_node tn ON tn.taxnode_id = tj.taxnode_id
    SET tj.json = CONCAT(
        '"child_counts":', CASE
            WHEN tj.child_counts IS NULL OR CHAR_LENGTH(tj.child_counts) < 1 THEN 'null' ELSE CONCAT('"', tj.child_counts, '"')
        END, ',',
        '"has_assigned_siblings":', CASE
            WHEN IFNULL(tj.has_assigned_siblings, 0) = 0 THEN 'false' ELSE 'true'
        END, ',',
        '"has_species":', CAST(IFNULL(tj.has_species, 0) AS CHAR), ',',
        '"is_assigned":', CASE
            WHEN tj.is_ghost_node = 1 THEN 'false' ELSE 'true'
        END, ',',
        '"has_unassigned_siblings":', CASE
            WHEN IFNULL(tj.has_unassigned_siblings, 0) = 0 THEN 'false' ELSE 'true'
        END, ',',
        -- Uncomment the following lines if needed
        -- '"json_id":', CAST(tj.id AS CHAR(12)), ',',
        -- '"json_lineage":"', IFNULL(tj.json_lineage, ''), '",',
        '"name":', CASE
            WHEN tn.name IS NULL THEN '"Unassigned"' ELSE CONCAT('"', tn.name, '"')
        END, ',',
        '"parentDistance":', CAST(IFNULL(tj.parent_distance, 1) AS CHAR), ',',
        '"parentTaxNodeID":', CASE
            WHEN tj.parent_taxnode_id IS NULL THEN 'null' ELSE CAST(tj.parent_taxnode_id AS CHAR(12))
        END, ',',
        '"rankIndex":', CAST(tj.rank_index AS CHAR), ',',
        '"rankName":"', tr.rank_name, '",',
        '"taxNodeID":', CASE
            WHEN tj.taxnode_id IS NULL THEN 'null' ELSE CAST(tj.taxnode_id AS CHAR(12))
        END, ','
    )
    WHERE tj.tree_id = treeID;

    -- ==========================================================================================================
    -- Iterate over all ranks from the lowest (species) to the highest level rank (realm).
    -- ==========================================================================================================
    OPEN ranked_node_cursor;
    read_loop: LOOP
        FETCH ranked_node_cursor INTO current_id, rankIndex, taxNodeID;
        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        -- Populate the taxonomy_json's "child JSON"
        SELECT GROUP_CONCAT(nodeJSON ORDER BY rank_index ASC, is_ghost_node ASC, node_name ASC SEPARATOR ',') INTO childJSON
        FROM (
            SELECT 
                CONCAT(
                    '{',
                    tj.json,
                    '"children":', CASE
                        WHEN tj.child_json IS NULL OR CHAR_LENGTH(tj.child_json) < 1 THEN 'null' ELSE CONCAT('[', tj.child_json, ']')
                    END,
                    '}'
                ) AS nodeJSON,
                tj.rank_index,
                tj.is_ghost_node,
                tn.name AS node_name
            FROM taxonomy_json tj
            LEFT JOIN taxonomy_node tn ON tn.taxnode_id = tj.taxnode_id
            WHERE tj.parent_id = current_id
              AND tj.tree_id = treeID
        ) childJSON_table;

        -- Update the taxonomy_json's child_json column
        UPDATE taxonomy_json SET child_json = childJSON WHERE id = current_id;

    END LOOP read_loop;

    CLOSE ranked_node_cursor;

END $$
DELIMITER ;
