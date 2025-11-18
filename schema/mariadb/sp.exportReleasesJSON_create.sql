DELIMITER $$

DROP PROCEDURE IF EXISTS exportReleasesJSON $$

CREATE PROCEDURE exportReleasesJSON()
BEGIN
    -- Variable declarations
    DECLARE dataJSON LONGTEXT DEFAULT '';
    DECLARE displayOrderJSON LONGTEXT DEFAULT '';
    DECLARE finalJSON LONGTEXT DEFAULT '';
    DECLARE mslReleaseNum INT;
    DECLARE rankCount INT;
    DECLARE yearAB VARCHAR(10);
    DECLARE done INT DEFAULT 0;

    -- Cursor declaration
    DECLARE releaseCursor CURSOR FOR
        SELECT
            toc.msl_release_num,
            (
                SELECT COUNT(DISTINCT tnRank.level_id)
                FROM taxonomy_node tnRank
                WHERE tnRank.tree_id = toc.tree_id
                AND tnRank.level_id <> (SELECT id FROM taxonomy_level WHERE name = 'tree' LIMIT 1)
            ) AS rankCount,
            tn.name AS yearAB
        FROM taxonomy_toc toc
        JOIN taxonomy_node tn ON tn.taxnode_id = toc.tree_id
        WHERE toc.msl_release_num IS NOT NULL
        ORDER BY toc.msl_release_num DESC;

    -- Handler declaration
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Start of executable code

    -- Open the cursor
    OPEN releaseCursor;

    -- Cursor loop
    read_loop: LOOP
        FETCH releaseCursor INTO mslReleaseNum, rankCount, yearAB;
        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        -- Build up dataJSON
        SET dataJSON = CONCAT(
            dataJSON,
            '"', yearAB, '": { ',
                '"year": "', yearAB, '", ',
                '"rankCount": ', rankCount, ', ',
                '"releaseNum": ', mslReleaseNum, '},'
        );

        -- Build up displayOrderJSON
        SET displayOrderJSON = CONCAT(displayOrderJSON, '"', yearAB, '",');
    END LOOP;

    -- Close the cursor
    CLOSE releaseCursor;

    -- Remove trailing commas if necessary
    IF CHAR_LENGTH(dataJSON) > 0 THEN
        SET dataJSON = LEFT(dataJSON, CHAR_LENGTH(dataJSON) - 1);
    END IF;

    IF CHAR_LENGTH(displayOrderJSON) > 0 THEN
        SET displayOrderJSON = LEFT(displayOrderJSON, CHAR_LENGTH(displayOrderJSON) - 1);
    END IF;

    -- Assemble the final JSON
    SET finalJSON = CONCAT(
        '{ "data": {',
        dataJSON,
        '}, "displayOrder": [',
        displayOrderJSON,
        ']}'
    );

    -- Return the JSON
    SELECT finalJSON AS jsonResult;

END $$
DELIMITER ;

