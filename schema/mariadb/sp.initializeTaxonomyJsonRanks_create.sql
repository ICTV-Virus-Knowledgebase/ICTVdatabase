DELIMITER $$

DROP PROCEDURE IF EXISTS initializeTaxonomyJsonRanks $$

CREATE PROCEDURE initializeTaxonomyJsonRanks()
BEGIN
    -- Variable declarations
    DECLARE treeID INT;
    DECLARE done INT DEFAULT 0;

    -- Cursor declaration
    DECLARE tree_cursor CURSOR FOR
        SELECT DISTINCT tree_id 
        FROM taxonomy_toc 
        WHERE msl_release_num IS NOT NULL
          AND tree_id NOT IN (
              SELECT tree_id
              FROM taxonomy_json_rank
          );

    -- Handler for cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- ==========================================================================================================
    -- Delete all existing records.
    -- ==========================================================================================================
    DELETE FROM taxonomy_json_rank;

    -- ==========================================================================================================
    -- Open the cursor and iterate over each tree_id.
    -- ==========================================================================================================
    OPEN tree_cursor;

    read_loop: LOOP
        FETCH tree_cursor INTO treeID;
        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        -- Create a record for every taxonomy level associated with this tree ID.
        INSERT INTO taxonomy_json_rank (
            level_id,
            rank_index,
            rank_name,
            tree_id
        )
        SELECT 
            levels.level_id,
            rn.rank_index,
            tl.name AS rank_name,
            treeID AS tree_id
        FROM (
            SELECT DISTINCT tn.level_id
            FROM taxonomy_node tn
            WHERE tn.tree_id = treeID
        ) levels
        JOIN taxonomy_level tl ON tl.id = levels.level_id
        JOIN (
            SELECT
                level_id,
                (ROW_NUMBER() OVER (ORDER BY level_id ASC) - 1) AS rank_index
            FROM (
                SELECT DISTINCT tn.level_id
                FROM taxonomy_node tn
                WHERE tn.tree_id = treeID
            ) tn_levels
        ) rn ON rn.level_id = levels.level_id
        ORDER BY levels.level_id;

    END LOOP read_loop;

    CLOSE tree_cursor;

END$$
DELIMITER ;
