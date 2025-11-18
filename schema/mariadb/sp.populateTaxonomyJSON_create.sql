DELIMITER $$

DROP PROCEDURE IF EXISTS populateTaxonomyJSON $$

CREATE PROCEDURE populateTaxonomyJSON(IN treeID INT)
BEGIN
    -- Variable declarations
    DECLARE errorCode INT DEFAULT 50000;
    DECLARE speciesRankIndex INT;
    DECLARE errorMsg VARCHAR(200);

    -- Exception handling
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 errorMsg = MESSAGE_TEXT;
        -- Rethrow the error with a custom message
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = errorMsg;
    END;

    -- ==========================================================================================================
    -- Delete any existing nodes associated with the tree ID.
    -- ==========================================================================================================
    DELETE FROM taxonomy_json WHERE tree_id = treeID;

    -- ==========================================================================================================
    -- Get the rank index of "species".
    -- ==========================================================================================================
    SELECT rank_index INTO speciesRankIndex
    FROM taxonomy_json_rank
    WHERE rank_name = 'species'
      AND tree_id = treeID
    LIMIT 1;

    IF speciesRankIndex IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid species rank index';
    END IF;

    -- ==========================================================================================================
    -- Create taxonomy_json records for all taxonomy nodes with the specified tree ID.
    -- ==========================================================================================================
    CALL initializeTaxonomyJSONFromTaxonomyNode(treeID);

    -- ==========================================================================================================
    -- Create intermediate and parent ghost (hidden/unassigned) nodes.
    -- ==========================================================================================================
    CALL createGhostNodes(speciesRankIndex, treeID);

    -- ==========================================================================================================
    -- Populate the "has_assigned_siblings" and "has_unassigned_siblings" columns.
    -- ==========================================================================================================
    UPDATE taxonomy_json tj
    SET 
        has_assigned_siblings = CASE
            WHEN (
                SELECT COUNT(*)
                FROM taxonomy_json assigned
                WHERE assigned.tree_id = treeID
                  AND assigned.parent_id = tj.parent_id
                  AND assigned.is_ghost_node = 0
                  AND assigned.id <> tj.id
                  AND assigned.rank_index = tj.rank_index
            ) = 0 THEN 0 ELSE 1
        END,
        has_unassigned_siblings = CASE
            WHEN (
                SELECT COUNT(*)
                FROM taxonomy_json unassigned
                WHERE unassigned.tree_id = treeID
                  AND unassigned.parent_id = tj.parent_id
                  AND unassigned.is_ghost_node = 1
                  AND unassigned.id <> tj.id
                  AND unassigned.rank_index = tj.rank_index
            ) = 0 THEN 0 ELSE 1
        END
    WHERE tj.tree_id = treeID;

    -- ==========================================================================================================
    -- Populate the "has_species" column for all ghost nodes.
    -- ==========================================================================================================
    UPDATE taxonomy_json ghostNode
    SET has_species = CASE
        WHEN (
            SELECT COUNT(*)
            FROM taxonomy_json ctj
            WHERE ctj.parent_id = ghostNode.id
              AND ctj.rank_index = speciesRankIndex
              AND ctj.tree_id = treeID
        ) > 0 THEN 1 ELSE 0
    END
    WHERE ghostNode.tree_id = treeID
      AND ghostNode.is_ghost_node = 1;

    -- ==========================================================================================================
    -- Populate the JSON lineage column from the top to the bottom of the tree.
    -- ==========================================================================================================
    -- CALL initializeJsonLineageColumn(treeID);

    -- ==========================================================================================================
    -- Populate the JSON column from the bottom to the top of the tree.
    -- ==========================================================================================================
    CALL initializeJsonColumn(treeID);

END$$
DELIMITER ;
