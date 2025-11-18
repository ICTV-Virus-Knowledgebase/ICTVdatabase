DELIMITER $$

DROP PROCEDURE IF EXISTS createGhostNodes $$

CREATE PROCEDURE createGhostNodes(
    IN speciesRankIndex INT,
    IN treeID INT
)
BEGIN
    -- Variable declarations
    DECLARE childCounts VARCHAR(1000);
    DECLARE tj_id INT;         -- Renamed from 'id' to 'tj_id'
    DECLARE rankIndex INT;
    DECLARE taxNodeID INT;
    DECLARE done BOOL DEFAULT FALSE;

    -- Declare the cursor
    DECLARE taxon_cursor CURSOR FOR
        SELECT
            child_counts,
            id,
            rank_index,
            taxnode_id
        FROM taxonomy_json tj
        WHERE tj.tree_id = treeID
            AND tj.is_ghost_node = 0
            AND tj.rank_index < speciesRankIndex
            AND tj.taxnode_id <> treeID
        ORDER BY tj.rank_index ASC;

    -- Declare cursor not found handler
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Error handling
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Declare variables to hold diagnostics area information
        DECLARE err_msg TEXT;
        DECLARE err_code INT;
        GET DIAGNOSTICS CONDITION 1
            err_code = MYSQL_ERRNO,
            err_msg = MESSAGE_TEXT;
        -- Raise an error
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = err_msg;
    END;

    -- Start of procedure logic

    -- Call createParentGhostNodes
    CALL createParentGhostNodes(treeID);

    -- Open the cursor
    OPEN taxon_cursor;

    -- Cursor loop
    read_loop: LOOP
        FETCH taxon_cursor INTO childCounts, tj_id, rankIndex, taxNodeID;  -- Changed 'id' to 'tj_id'
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Call createIntermediateGhostNodes
        CALL createIntermediateGhostNodes(
            childCounts,
            tj_id,            -- Use 'tj_id' variable
            rankIndex,
            taxNodeID,
            speciesRankIndex,
            treeID
        );
    END LOOP;

    -- Close the cursor
    CLOSE taxon_cursor;

END $$
DELIMITER ;