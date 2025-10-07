DELIMITER $$

DROP FUNCTION IF EXISTS udf_singularOrPluralTaxLevelNames $$

CREATE FUNCTION udf_singularOrPluralTaxLevelNames(
    level_count INT,
    level_id INT
)
RETURNS VARCHAR(128)
DETERMINISTIC
BEGIN
    DECLARE level_label VARCHAR(128) DEFAULT '';
    DECLARE result VARCHAR(200) DEFAULT '';

    -- Assign level_label based on level_id and level_count
    SET level_label = CASE
        WHEN level_id = 200 AND level_count = 1 THEN 'Order'
        WHEN level_id = 200 AND level_count <> 1 THEN 'Orders'

        WHEN level_id = 300 AND level_count = 1 THEN 'Family'
        WHEN level_id = 300 AND level_count <> 1 THEN 'Families'

        WHEN level_id = 400 AND level_count = 1 THEN 'Subfamily'
        WHEN level_id = 400 AND level_count <> 1 THEN 'Subfamilies'

        WHEN level_id = 500 AND level_count = 1 THEN 'Genus'
        WHEN level_id = 500 AND level_count <> 1 THEN 'Genera'

        WHEN level_id = 600 THEN 'Species'

        ELSE ''
    END;

    -- Ensure level_label is not NULL
    SET level_label = IFNULL(level_label, '');

    -- Build the result string if level_label is not empty
    IF level_label <> '' THEN
        SET result = CONCAT(CAST(level_count AS CHAR(3)), ' ', level_label);
    END IF;

    -- Return the result
    RETURN result;
END $$
DELIMITER ;


-- Test

-- SELECT udf_singularOrPluralTaxLevelNames(1, 200) AS result;