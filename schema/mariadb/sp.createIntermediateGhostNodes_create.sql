DELIMITER $$

DROP PROCEDURE IF EXISTS createIntermediateGhostNodes $$

CREATE PROCEDURE createIntermediateGhostNodes(
    IN childCounts VARCHAR(1000),
    IN parentID INT,
    IN parentRankIndex INT,
    IN parentTaxnodeID INT,
    IN speciesRankIndex INT,
    IN treeID INT
)
BEGIN
    -- Variable declarations
    DECLARE errorCode INT DEFAULT 50000;
    DECLARE maxChildRankIndex INT;
    DECLARE currentRankIndex INT;
    DECLARE currentID INT;
    DECLARE previousID INT;
    DECLARE childID INT;
    DECLARE childRankIndex INT;
    DECLARE childTaxnodeID INT;
    DECLARE done INT DEFAULT 0;

    -- Cursor declaration
    DECLARE child_cursor CURSOR FOR
        SELECT 
            id,
            rank_index,
            taxnode_id
        FROM taxonomy_json tj
        WHERE tj.parent_taxnode_id = parentTaxnodeID
            AND tj.is_ghost_node = 0
            AND tj.rank_index > parentRankIndex + 1
        ORDER BY tj.rank_index ASC;

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

    -- If childCounts IS NULL, set to empty string
    IF childCounts IS NULL THEN
        SET childCounts = '';
    END IF;

    -- Start transaction
    START TRANSACTION;

    -- ==========================================================================================================
    -- What's the maximum child rank index we need to create?
    -- ==========================================================================================================
    SELECT MAX(rank_index) INTO maxChildRankIndex
    FROM taxonomy_json tj
    WHERE tj.parent_taxnode_id = parentTaxnodeID
        AND tj.is_ghost_node = 0
        AND tj.rank_index <= speciesRankIndex
        AND tj.rank_index > parentRankIndex + 1;

    -- If a maximum child rank index wasn't found, we don't need to create intermediate ghost nodes.
    IF maxChildRankIndex IS NOT NULL THEN

        -- Variables used by the WHILE loop.
        SET currentRankIndex = parentRankIndex + 1;
        SET previousID = parentID;

        -- ==========================================================================================================
        -- Create the intermediate ghost nodes between the parent and farthest child.
        -- ==========================================================================================================
        WHILE currentRankIndex < maxChildRankIndex DO

            INSERT INTO taxonomy_json (
                child_counts,
                is_ghost_node,
                parent_distance,
                parent_id,
                parent_taxnode_id,
                rank_index,
                source,
                taxnode_id,
                tree_id
            ) VALUES (
                childCounts,
                1,              -- This is a ghost node.
                1,              -- Ghost nodes are always 1 rank away from their parent node.
                previousID,
                parentTaxnodeID,
                currentRankIndex,
                'I',            -- "Intermediate" ghost node
                NULL,
                treeID
            );

            -- The ID of the taxonomy_json record we just created.
            SET currentID = LAST_INSERT_ID();
            SET previousID = currentID;

            SET currentRankIndex = currentRankIndex + 1;
        END WHILE;

        -- Open the cursor
        OPEN child_cursor;

        -- Cursor loop
        read_loop: LOOP
            FETCH child_cursor INTO childID, childRankIndex, childTaxnodeID;
            IF done = 1 THEN
                LEAVE read_loop;
            END IF;

            -- ==========================================================================================================
            -- Update the child to point to a newly-created ghost node.
            -- ==========================================================================================================
            UPDATE taxonomy_json
            SET parent_id = (
                SELECT id
                FROM taxonomy_json
                WHERE parent_taxnode_id = parentTaxnodeID
                    AND is_ghost_node = 1
                    AND rank_index = childRankIndex - 1
                    AND tree_id = treeID
                LIMIT 1
            )
            WHERE id = childID;

        END LOOP;

        -- Close the cursor
        CLOSE child_cursor;

    END IF;

    -- Commit transaction
    COMMIT;

END $$
DELIMITER ;
