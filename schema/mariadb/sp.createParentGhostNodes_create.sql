DELIMITER $$

DROP PROCEDURE IF EXISTS createParentGhostNodes $$

CREATE PROCEDURE createParentGhostNodes(
    IN treeID INT
)
BEGIN
    -- Variable declarations
    DECLARE errorCode INT DEFAULT 50000;
    DECLARE treeJsonID INT;
    DECLARE lowestRankToCreate INT;
    DECLARE currentRankIndex INT DEFAULT 1;
    DECLARE previousID INT;
    DECLARE tj_id INT;         -- Renamed from 'id' to 'tj_id'
    DECLARE parentID INT;
    DECLARE done INT DEFAULT 0;

    -- Cursor declaration
    DECLARE top_level_cursor CURSOR FOR
        SELECT
            notghost.id,
            (
                SELECT id
                FROM taxonomy_json ghost
                WHERE ghost.is_ghost_node = 1
                    AND ghost.source = 'P'             -- This is a "parent" ghost node
                    AND ghost.rank_index = notghost.rank_index - 1
                    AND ghost.parent_taxnode_id = treeID
                    AND ghost.tree_id = treeID
                LIMIT 1
            ) AS parentID
        FROM taxonomy_json notghost
        WHERE notghost.parent_taxnode_id = treeID     -- Child nodes of the tree node.
            AND notghost.taxnode_id <> treeID         -- Exclude the tree node
            AND notghost.is_ghost_node = 0            -- No ghost nodes
            AND notghost.rank_index > 1               -- Exclude realm (and tree)
            AND notghost.tree_id = treeID;

    -- Handler declarations
    -- Cursor not found handler
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Error handling
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Declare variables to hold diagnostics area information
        DECLARE err_msg TEXT;
        DECLARE err_code INT;
        GET DIAGNOSTICS CONDITION 1
            err_code = MYSQL_ERRNO,
            err_msg = MESSAGE_TEXT;
        -- Rollback transaction if necessary
        ROLLBACK;
        -- Raise an error
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = err_msg;
    END;

    -- Start transaction
    START TRANSACTION;

    -- ==========================================================================================================
    -- Get the taxonomy_json.id of the tree node
    -- ==========================================================================================================
    SELECT id INTO treeJsonID
    FROM taxonomy_json tj
    WHERE tj.tree_id = treeID
        AND tj.rank_index = 0
    LIMIT 1;

    IF treeJsonID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid taxonomy_json.id for tree node';
    END IF;

    -- What is the maximum rank index among all non-ghost nodes that are directly under the tree node?
    SELECT MAX(rank_index) - 1 INTO lowestRankToCreate
    FROM taxonomy_json
    WHERE parent_taxnode_id = treeID      -- Direct children of the tree node
        AND taxnode_id <> treeID          -- Exclude the tree node
        AND tree_id = treeID              -- Constrain the tree ID
        AND is_ghost_node = 0             -- Not a ghost node
        AND rank_index > 1                -- Exclude realm (and tree)
        AND rank_index IS NOT NULL;       -- Ensure rank_index is not NULL

    IF lowestRankToCreate IS NULL THEN
        SET lowestRankToCreate = 0;
    END IF;

    SET previousID = treeJsonID;

    -- ==========================================================================================================
    -- Create parent ghost nodes
    -- ==========================================================================================================
    WHILE currentRankIndex <= lowestRankToCreate DO

        -- Create a ghost node for this rank.
        INSERT INTO taxonomy_json (
            is_ghost_node,
            parent_distance,
            parent_taxnode_id,
            parent_id,
            rank_index,
            source,
            taxnode_id,
            tree_id
        ) VALUES (
            1,              -- This is a ghost node.
            1,              -- Ghost nodes are always 1 rank away from their parent node.
            treeID,
            previousID,
            currentRankIndex,
            'P',            -- parent ghost node
            NULL,
            treeID
        );

        -- The ID of the taxonomy_json record we just created.
        SET previousID = LAST_INSERT_ID();

        SET currentRankIndex = currentRankIndex + 1;
    END WHILE;

    -- ==========================================================================================================
    -- Update top-level nodes to connect them to their parent ghost nodes
    -- ==========================================================================================================
    -- Open the cursor
    OPEN top_level_cursor;

    -- Cursor loop
    read_loop: LOOP
        FETCH top_level_cursor INTO tj_id, parentID;  -- Changed 'id' to 'tj_id'
        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        -- Connect the "top-level" node to its parent ghost node.
        UPDATE taxonomy_json
        SET parent_id = parentID
        WHERE `id` = tj_id;  -- Use 'tj_id' variable

    END LOOP;

    -- Close the cursor
    CLOSE top_level_cursor;

    -- Commit transaction
    COMMIT;

END $$
DELIMITER ;
