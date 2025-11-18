DELIMITER $$

DROP PROCEDURE IF EXISTS populateTaxonomyJsonForAllReleases $$

CREATE PROCEDURE populateTaxonomyJsonForAllReleases()
BEGIN
    -- Variable declarations
    DECLARE errorCode INT DEFAULT 50000;
    DECLARE errorMsg VARCHAR(200);
    DECLARE treeID INT;
    DECLARE done INT DEFAULT FALSE;

    -- Cursor declaration
    DECLARE release_cursor CURSOR FOR
        SELECT tree_id 
        FROM taxonomy_toc 
        WHERE msl_release_num IS NOT NULL
        ORDER BY tree_id;

    -- Handler declarations
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 errorMsg = MESSAGE_TEXT;
        -- Rethrow the error with a custom message
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = errorMsg;
    END;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- =======================================================================
    -- Ensure taxonomy_json_rank is populated
    -- =======================================================================
    IF (SELECT COUNT(*) FROM taxonomy_json_rank) < 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No taxonomy JSON ranks exist. Run the stored procedure initializeTaxonomyJsonRanks and try again.';
    END IF;

    -- =======================================================================
    -- Open the cursor
    -- =======================================================================
    OPEN release_cursor;

    -- Cursor loop
    read_loop: LOOP
        FETCH release_cursor INTO treeID;
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Call populateTaxonomyJSON for each tree ID
        CALL populateTaxonomyJSON(treeID);
    END LOOP;

    -- Close the cursor
    CLOSE release_cursor;

END$$
DELIMITER ;
