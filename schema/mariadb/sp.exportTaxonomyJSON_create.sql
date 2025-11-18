DELIMITER $$

DROP PROCEDURE IF EXISTS exportTaxonomyJSON $$

CREATE PROCEDURE exportTaxonomyJSON(IN treeID INT)
BEGIN
    -- Variable declarations
    DECLARE legendJSON LONGTEXT DEFAULT '';
    DECLARE jsonResult LONGTEXT DEFAULT '';
    DECLARE tempJSON LONGTEXT DEFAULT '';
    DECLARE tempEndJSON LONGTEXT DEFAULT '';
    DECLARE group_concat_max_len_value INT;

    -- Increase group_concat_max_len if necessary
    SELECT @@group_concat_max_len INTO group_concat_max_len_value;
    IF group_concat_max_len_value < 1000000 THEN
        SET SESSION group_concat_max_len = 1000000;
    END IF;

    -- ==========================================================================================================
    -- Create JSON for the "legend" (ordered rank data for this release).
    -- ==========================================================================================================
    SELECT
        GROUP_CONCAT(rankJSON ORDER BY rank_index SEPARATOR '') INTO tempJSON
    FROM (
        SELECT
            CONCAT(
                '{',
                '"child_counts":null,',
                '"has_assigned_siblings":false,',
                '"has_species":false,',
                '"is_assigned":false,',
                '"has_unassigned_siblings":false,',
                '"name":"Unassigned",',
                '"parentDistance":1,',
                '"parentTaxNodeID":null,',
                '"rankIndex":', CAST(tr.rank_index AS CHAR), ',',
                '"rankName":"', tr.rank_name, '",',
                '"taxNodeID":"legend",',
                '"children":['
            ) AS rankJSON,
            tr.rank_index
        FROM taxonomy_json_rank tr
        WHERE tr.tree_id = treeID
          AND tr.rank_index > 0
        ORDER BY tr.rank_index
        LIMIT 100
    ) ranksJSON;

    -- Append "]}" for every non-tree taxonomy rank.
    SELECT
        GROUP_CONCAT(']}' ORDER BY rank_index SEPARATOR '') INTO tempEndJSON
    FROM (
        SELECT tr.rank_index
        FROM taxonomy_json_rank tr
        WHERE tr.tree_id = treeID
          AND tr.rank_index > 0
        ORDER BY tr.rank_index
    ) rankEnds;

    -- Combine the initial and ending parts of legendJSON
    SET legendJSON = CONCAT(tempJSON, tempEndJSON);

    -- =========================================================================================================
    -- Return the JSON result.
    -- ==========================================================================================================
    SELECT CONCAT(
        '{',
        tj.json,
        '"children":[',
        legendJSON,
        IF(CHAR_LENGTH(legendJSON) > 0 AND tj.child_json IS NOT NULL, ',', ''),
        IFNULL(tj.child_json, ''),
        ']}'
    ) INTO jsonResult
    FROM taxonomy_json tj
    WHERE tj.tree_id = treeID
      AND tj.taxnode_id = treeID
    LIMIT 1;

    -- Return the JSON result
    SELECT jsonResult;

END $$
DELIMITER ;

