DELIMITER $$

DROP FUNCTION IF EXISTS udf_getMSL $$

CREATE FUNCTION udf_getMSL(in_tree_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE msl INT;

    IF in_tree_id IS NULL THEN
        -- Get the maximum msl_release_num
        SELECT MAX(msl_release_num) INTO msl FROM taxonomy_toc;
        RETURN msl;
    ELSE
        -- Get the msl_release_num for the given tree_id
        SELECT msl_release_num INTO msl
        FROM taxonomy_toc
        WHERE tree_id = in_tree_id
        ORDER BY msl_release_num DESC
        LIMIT 1;

        RETURN msl;
    END IF;
END $$

DELIMITER ;

-- Test

-- SELECT udf_getMSL(NULL) AS latest_msl;
-- SELECT udf_getMSL(20170000) AS msl_for_tree;
-- SELECT IFNULL(udf_getMSL(10000), -999) AS msl_for_tree;