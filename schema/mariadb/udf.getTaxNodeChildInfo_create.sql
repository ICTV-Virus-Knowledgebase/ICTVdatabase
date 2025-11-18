DELIMITER $$

DROP FUNCTION IF EXISTS udf_getTaxNodeChildInfo $$

CREATE FUNCTION udf_getTaxNodeChildInfo(
    in_taxnode_id INT
)
RETURNS VARCHAR(512)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE child_info_result VARCHAR(512);
    DECLARE invalid_result_count INT DEFAULT 0;

    -- Calculate the total number of invalid result_labels
    SELECT
        COUNT(*) INTO invalid_result_count
    FROM (
        SELECT level_id, level_count,
               udf_singularOrPluralTaxLevelNames(level_count, level_id) AS result_label
        FROM (
            SELECT level_id, COUNT(DISTINCT taxnode_id) AS level_count
            FROM (
                -- Combine hidden and visible children
                SELECT tn3.level_id AS level_id, tn3.taxnode_id
                FROM taxonomy_node tn2
                JOIN taxonomy_node tn3 ON tn3.parent_id = tn2.taxnode_id
                WHERE tn2.parent_id = in_taxnode_id
                    AND tn2.is_hidden = 1
                    AND tn2.is_deleted = 0
                    AND tn3.is_deleted = 0
                    AND tn3.name <> 'unassigned'

                UNION ALL

                SELECT tn1.level_id AS level_id, tn1.taxnode_id
                FROM taxonomy_node tn1
                WHERE tn1.parent_id = in_taxnode_id
                    AND tn1.parent_id <> tn1.taxnode_id
                    AND tn1.is_hidden = 0
                    AND tn1.is_deleted = 0
            ) AS combined
            GROUP BY level_id
        ) AS level_counts
        WHERE udf_singularOrPluralTaxLevelNames(level_count, level_id) IS NULL
            OR udf_singularOrPluralTaxLevelNames(level_count, level_id) = ''
    ) AS invalid_results;

    -- If any invalid result_label exists, return NULL
    IF invalid_result_count > 0 THEN
        RETURN NULL;
    ELSE
        -- Build the child_info_result
        SELECT GROUP_CONCAT(result_label ORDER BY level_id ASC SEPARATOR ', ') INTO child_info_result
        FROM (
            SELECT level_id, level_count,
                   udf_singularOrPluralTaxLevelNames(level_count, level_id) AS result_label
            FROM (
                SELECT level_id, COUNT(DISTINCT taxnode_id) AS level_count
                FROM (
                    -- Combine hidden and visible children
                    SELECT tn3.level_id AS level_id, tn3.taxnode_id
                    FROM taxonomy_node tn2
                    JOIN taxonomy_node tn3 ON tn3.parent_id = tn2.taxnode_id
                    WHERE tn2.parent_id = in_taxnode_id
                        AND tn2.is_hidden = 1
                        AND tn2.is_deleted = 0
                        AND tn3.is_deleted = 0
                        AND tn3.name <> 'unassigned'

                    UNION ALL

                    SELECT tn1.level_id AS level_id, tn1.taxnode_id
                    FROM taxonomy_node tn1
                    WHERE tn1.parent_id = in_taxnode_id
                        AND tn1.parent_id <> tn1.taxnode_id
                        AND tn1.is_hidden = 0
                        AND tn1.is_deleted = 0
                ) AS combined
                GROUP BY level_id
            ) AS level_counts
            WHERE udf_singularOrPluralTaxLevelNames(level_count, level_id) IS NOT NULL
                AND udf_singularOrPluralTaxLevelNames(level_count, level_id) <> ''
        ) AS valid_results;

        RETURN child_info_result;
    END IF;
END $$
DELIMITER ;


-- Test 

-- SELECT udf_getTaxNodeChildInfo(19710000) AS child_info;