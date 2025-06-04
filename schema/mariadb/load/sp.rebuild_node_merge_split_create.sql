/* ================================================================
   Stored procedure  : rebuild_node_merge_split
   Converted from    : SQL-Server to MariaDB
   Preserves         : All original comments and behaviour
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS rebuild_node_merge_split $$
CREATE PROCEDURE rebuild_node_merge_split()
BEGIN
    /* -----------------------------------------------------------------
       throw away what we have
       ----------------------------------------------------------------- */
    TRUNCATE TABLE taxonomy_node_merge_split;

    /* -----------------------------------------------------------------
       add forward links
       ----------------------------------------------------------------- */
    INSERT INTO taxonomy_node_merge_split
    SELECT  /* forward → */
            p.ictv_id  AS prev_ictv_id,
            n.ictv_id  AS next_ictv_id,
            d.is_merged,
            d.is_split,
            1          AS dist,
            0          AS rev_count
    FROM taxonomy_node_delta  AS d
    JOIN taxonomy_node        AS p ON d.prev_taxid = p.taxnode_id
    JOIN taxonomy_node        AS n ON d.new_taxid  = n.taxnode_id
    WHERE p.level_id  > 100
      AND n.level_id  > 100
      AND p.ictv_id  <> n.ictv_id
      AND p.msl_release_num = n.msl_release_num - 1
      AND p.is_hidden = 0
      AND n.is_hidden = 0;

    /* -----------------------------------------------------------------
       add identities
       ----------------------------------------------------------------- */
    INSERT INTO taxonomy_node_merge_split
    SELECT  ictv_id AS prev_ictv_id,
            ictv_id AS next_ictv_id,
            0       AS is_merged,
            0       AS is_split,
            0       AS dist,
            0       AS rev_count
    FROM taxonomy_node
    WHERE msl_release_num IS NOT NULL
      AND is_hidden = 0
    GROUP BY ictv_id;         -- keep one identity per ictv_id

    /* -----------------------------------------------------------------
       add reverse links
       ----------------------------------------------------------------- */
    INSERT INTO taxonomy_node_merge_split
    SELECT  /* reverse ← */
            n.ictv_id  AS prev_ictv_id,
            p.ictv_id  AS next_ictv_id,
            d.is_merged,
            d.is_split,
            1          AS dist,
            1          AS rev_count
    FROM taxonomy_node_delta  AS d
    JOIN taxonomy_node        AS p ON d.prev_taxid = p.taxnode_id
    JOIN taxonomy_node        AS n ON d.new_taxid  = n.taxnode_id
    WHERE p.level_id  > 100
      AND n.level_id  > 100
      AND p.ictv_id  <> n.ictv_id
      AND p.msl_release_num = n.msl_release_num - 1
      AND p.is_hidden = 0
      AND n.is_hidden = 0;

    /* -----------------------------------------------------------------
       compute transitive closure  (repeatedly add longer paths)
       ----------------------------------------------------------------- */
    SELECT 'start closure' AS msg;
    BEGIN
        DECLARE rows_added INT DEFAULT 1;

        WHILE rows_added > 0 DO
            INSERT INTO taxonomy_node_merge_split (prev_ictv_id,
                                                   next_ictv_id,
                                                   is_merged,
                                                   is_split,
                                                   dist,
                                                   rev_count)
            SELECT  src.prev_ictv_id,
                    src.next_ictv_id,
                    MAX(src.is_merged),
                    MAX(src.is_split),
                    MIN(src.dist),
                    SUM(src.rev_count)
            FROM (
                    SELECT  p.prev_ictv_id,
                            n.next_ictv_id,
                            p.is_merged + n.is_merged AS is_merged,
                            p.is_split  + n.is_split  AS is_split,
                            p.dist      + n.dist      AS dist,
                            p.rev_count + n.rev_count AS rev_count
                    FROM taxonomy_node_merge_split AS p
                    JOIN taxonomy_node_merge_split AS n
                      ON n.prev_ictv_id = p.next_ictv_id
                    WHERE p.dist > 0    -- ignore identities
                      AND n.dist > 0
                 ) AS src
            GROUP BY src.prev_ictv_id, src.next_ictv_id
            HAVING NOT EXISTS (
                    SELECT 1
                    FROM taxonomy_node_merge_split cur
                    WHERE cur.prev_ictv_id = src.prev_ictv_id
                      AND cur.next_ictv_id = src.next_ictv_id
                 );

            SET rows_added = ROW_COUNT();      -- how many rows were inserted
        END WHILE;
    END;
    SELECT 'closure done' AS msg;

    /* -----------------------------------------------------------------
       TEST symmetry (unchanged debug queries)
       ----------------------------------------------------------------- */
	SELECT 'TEST' AS title, t.*
	FROM   taxonomy_node_merge_split AS t
	WHERE  t.prev_ictv_id = 19710158;

	SELECT 'TEST' AS title, t.*
	FROM   taxonomy_node_merge_split AS t
	WHERE  t.next_ictv_id = 19710158;

	SELECT 'TEST' AS title, t.*
	FROM   taxonomy_node_merge_split AS t
	WHERE  t.prev_ictv_id = 20093515;
	
	SELECT 'TEST' AS title, t.*
	FROM   taxonomy_node_merge_split AS t
	WHERE  t.next_ictv_id = 20093515;
END$$
DELIMITER ;