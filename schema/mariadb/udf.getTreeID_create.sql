DELIMITER $$

DROP FUNCTION IF EXISTS udf_getTreeID $$

CREATE FUNCTION udf_getTreeID(in_msl INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_tree_id INT;

    IF in_msl IS NULL THEN
        -- Get the maximum tree_id
        SELECT MAX(tree_id) INTO v_tree_id FROM taxonomy_toc;
        RETURN v_tree_id;
    ELSE
        -- Get the tree_id for the given msl_release_num
        SELECT tree_id INTO v_tree_id
        FROM taxonomy_toc
        WHERE msl_release_num IS NOT NULL
          AND msl_release_num = in_msl
        ORDER BY msl_release_num
        LIMIT 1;

        RETURN v_tree_id;
    END IF;
END $$

DELIMITER ;

-- Test

-- in_msl is null
-- SELECT udf_getTreeID(NULL) AS latest_tree_id;

-- in_msl = 32
-- SELECT udf_getTreeID(32) AS tree_id_for_msl;

-- in_msl = -1 (Does not exist)
-- SELECT IFNULL(udf_getTreeID(-1), -999) AS tree_id_for_msl;