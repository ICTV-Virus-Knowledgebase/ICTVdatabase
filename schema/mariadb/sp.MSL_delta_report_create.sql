DELIMITER $$

DROP PROCEDURE IF EXISTS MSL_delta_report $$

CREATE PROCEDURE MSL_delta_report(IN in_msl INT)
BEGIN
    DECLARE msl INT;
    DECLARE prev_msl INT;

    -- Assign the input parameter to a local variable
    SET msl = in_msl;

    -- If msl is NULL, set it to the maximum msl_release_num from taxonomy_node
    IF msl IS NULL THEN
        SELECT MAX(msl_release_num) INTO msl FROM taxonomy_node;
    END IF;

    -- Calculate the previous MSL release number
    SET prev_msl = msl - 1;

    -- Output TARGET MSLs information
    SELECT 'TARGET MSLs' AS target_msls,
           msl AS `current`,
           prev_msl AS `prev`,
           CONCAT('Deltas MSL', RTRIM(prev_msl), ' v ', RTRIM(msl)) AS excel_tab_name;

    -- Generate the delta report
    SELECT 
        IFNULL(RTRIM(prev.left_idx), '') AS sort_old,
        IFNULL(plevel.name, '') AS old_level,
        IFNULL(prev.lineage, '') AS old_lineage,
        delta.tag_csv AS `change`,
        IFNULL(delta.proposal, '') AS proposal,
        IFNULL(dlevel.name, '') AS new_level,
        IFNULL(dx.lineage, '') AS new_lineage,
        IFNULL(dx.left_idx, '') AS sort_new
    FROM taxonomy_node_delta delta
    LEFT JOIN taxonomy_node dx ON delta.new_taxid = dx.taxnode_id
    LEFT JOIN taxonomy_level dlevel ON dlevel.id = dx.level_id
    LEFT JOIN taxonomy_node prev ON prev.taxnode_id = delta.prev_taxid
    LEFT JOIN taxonomy_level plevel ON plevel.id = prev.level_id
    WHERE (dx.msl_release_num = msl AND delta.tag_csv <> '')
       OR (prev.msl_release_num = prev_msl AND delta.is_deleted = 1)
    ORDER BY dx.left_idx, prev.left_idx;
END $$

DELIMITER ;