DELIMITER $$

DROP FUNCTION IF EXISTS udf_getChildTaxaCounts $$

CREATE FUNCTION udf_getChildTaxaCounts(in_taxnode_id INT)
RETURNS VARCHAR(1000)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE result VARCHAR(1000);

    SELECT
        SUBSTRING(
            GROUP_CONCAT(cnt_name ORDER BY level_id SEPARATOR ''),
            3
        ) INTO result
    FROM (
        SELECT
            CONCAT(', ', CAST(COUNT(*) AS CHAR(6)), ' ', 
                   IF(COUNT(*) > 1, tl.plural, tl.name)) AS cnt_name,
            tn.level_id
        FROM taxonomy_node sub
        JOIN taxonomy_node tn ON tn.left_idx BETWEEN sub.left_idx AND sub.right_idx 
                               AND tn.tree_id = sub.tree_id
        JOIN taxonomy_level tl ON tl.id = tn.level_id
        WHERE sub.taxnode_id = in_taxnode_id
          AND tn.taxnode_id <> sub.taxnode_id
        GROUP BY tl.plural, tl.name, tn.level_id
    ) AS derived_table;

    RETURN IFNULL(result, '');
END $$

DELIMITER ;