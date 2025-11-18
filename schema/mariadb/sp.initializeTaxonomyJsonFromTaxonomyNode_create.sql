DELIMITER $$

DROP PROCEDURE IF EXISTS initializeTaxonomyJsonFromTaxonomyNode $$

CREATE PROCEDURE initializeTaxonomyJsonFromTaxonomyNode(IN treeID INT)
BEGIN
    -- Variable declarations
    DECLARE speciesLevelID INT;
    DECLARE errorMsg VARCHAR(200);
    DECLARE errorCode INT DEFAULT 50000;

    -- Handler for exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 errorMsg = MESSAGE_TEXT;
        -- Rethrow the error with a custom message
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = errorMsg;
    END;

    -- ==========================================================================================================
    -- Get the species level_id from taxonomy_level.
    -- ==========================================================================================================
    SELECT id INTO speciesLevelID
    FROM taxonomy_level
    WHERE name = 'species'
    LIMIT 1;

    IF speciesLevelID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid level_id for species';
    END IF;

    -- ==========================================================================================================
    -- Add taxonomy node records to the taxonomy_json table.
    -- ==========================================================================================================
    INSERT INTO taxonomy_json (
        child_counts,
        child_json,
        has_species,
        is_ghost_node,
        json,
        parent_distance,
        parent_id,
        parent_taxnode_id,
        rank_index,
        source,
        taxnode_id,
        tree_id
    )
    SELECT
        IFNULL(child_counts, '') AS child_counts,
        NULL AS child_json,
        has_species,
        0 AS is_ghost_node,
        NULL AS json,
        rank_index - IFNULL(parent_rank_index, 0) AS parent_distance,
        NULL AS parent_id,
        parent_taxnode_id,
        rank_index,
        'T' AS source,
        taxnode_id,
        tree_id
    FROM (
        SELECT
            tn.taxa_desc_cts AS child_counts,
            CASE
                WHEN 0 < (
                    SELECT COUNT(*)
                    FROM taxonomy_node species
                    WHERE species.parent_id = tn.taxnode_id
                      AND species.level_id = speciesLevelID
                      AND species.tree_id = treeID
                ) THEN 1 ELSE 0
            END AS has_species,
            parentRank.rank_index AS parent_rank_index,
            tn.parent_id AS parent_taxnode_id,
            tr.rank_index AS rank_index,
            tn.taxnode_id,
            tn.tree_id
        FROM taxonomy_node tn
        JOIN taxonomy_json_rank tr ON (
            tr.level_id = tn.level_id
            AND tr.tree_id = treeID
        )
        LEFT JOIN taxonomy_node parentTN ON (
            parentTN.taxnode_id = tn.parent_id
            AND parentTN.tree_id = treeID
        )
        LEFT JOIN taxonomy_json_rank parentRank ON (
            parentRank.level_id = parentTN.level_id
            AND parentRank.tree_id = treeID
        )
        WHERE tn.tree_id = treeID
    ) taxa;

    -- ==========================================================================================================
    -- Populate the parent_id of all nodes initialized from taxonomy_node.
    -- ==========================================================================================================
    UPDATE taxonomy_json tj
    JOIN taxonomy_json parent_tj ON parent_tj.taxnode_id = tj.parent_taxnode_id
    SET tj.parent_id = parent_tj.id
    WHERE tj.tree_id = treeID
      AND parent_tj.tree_id = treeID
      AND tj.is_ghost_node = 0
      AND parent_tj.is_ghost_node = 0;

    -- Uncomment and adjust the following sections if needed
    /*
    -- Additional updates can be added here as per your requirements.
    */

END$$
DELIMITER ;
