/* ================================================================
   LRM(07302025): Re-port to MariaDB after updates done on SQL Server
   Stored procedure : rebuild_node_merge_split (MariaDB)
   Converted from   : SQL-Server version
   Behaviour        : identical – rebuild the merge/split map,
                      then compute its transitive closure.
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS rebuild_node_merge_split $$
CREATE PROCEDURE rebuild_node_merge_split()
BEGIN

    DECLARE v_rows BIGINT DEFAULT 1;
    /* ==================================================================
       0.  Start a transaction – optional, but useful if your table is
           referenced elsewhere while rebuilding.
       ================================================================== */
    START TRANSACTION;

    /* ***************************
       1.  Throw away what we have
       *************************** */
    TRUNCATE TABLE taxonomy_node_merge_split;

    /* ***************************
       2.  Identities  (dist = 0)
       *************************** */
    INSERT INTO taxonomy_node_merge_split
            (prev_ictv_id, next_ictv_id,
             is_merged, is_split, is_recreated,
             dist,       rev_count)
    SELECT  ictv_id, ictv_id,
            0,        0,        0,
            0,        0
    FROM    taxonomy_node
    WHERE   msl_release_num IS NOT NULL
      AND   is_hidden       = 0
    GROUP BY ictv_id;

    /* ***************************
       3.  Forward links (dist = 1)
       *************************** */
    INSERT INTO taxonomy_node_merge_split
            (prev_ictv_id, next_ictv_id,
             is_merged, is_split, is_recreated,
             dist,       rev_count)
    SELECT  p.ictv_id,
            n.ictv_id,
            /* NOTE: taxonomy_node_delta can contain multiple rows that map to the
               same (p.ictv_id, n.ictv_id) pair. Because the target table has a
               composite PRIMARY KEY (prev_ictv_id, next_ictv_id), we must
               dedupe here to avoid duplicate-key errors (1062).
               These columns are counts, so SUM() is the correct aggregation. */
            SUM(COALESCE(d.is_merged, 0)),
            SUM(COALESCE(d.is_split, 0)),
            0,
            1,
            0
    FROM    taxonomy_node_delta AS d
    JOIN    taxonomy_node       AS p ON  p.taxnode_id      = d.prev_taxid
    JOIN    taxonomy_node       AS n ON  n.taxnode_id      = d.new_taxid
    WHERE   p.level_id          > 100
      AND   n.level_id          > 100
      AND   p.ictv_id           <> n.ictv_id
      AND   p.msl_release_num   = n.msl_release_num - 1
      AND   p.is_hidden = 0
      AND   n.is_hidden = 0
    GROUP BY p.ictv_id, n.ictv_id;

    /* ***************************
       4.  Reverse links (dist = 1)
       *************************** */
    INSERT INTO taxonomy_node_merge_split
            (prev_ictv_id, next_ictv_id,
             is_merged, is_split, is_recreated,
             dist,       rev_count)
    SELECT  n.ictv_id,
            p.ictv_id,
            /* Same dedupe/boolean aggregation as forward links, but reversed
               direction and rev_count=1. */
            SUM(COALESCE(d.is_merged, 0)),
            SUM(COALESCE(d.is_split, 0)),
            0,
            1,
            1           -- <<< reverse
    FROM    taxonomy_node_delta AS d
    JOIN    taxonomy_node       AS p ON p.taxnode_id = d.prev_taxid
    JOIN    taxonomy_node       AS n ON n.taxnode_id = d.new_taxid
    WHERE   p.level_id          > 100
      AND   n.level_id          > 100
      AND   p.ictv_id           <> n.ictv_id
      AND   p.msl_release_num   = n.msl_release_num - 1
      AND   p.is_hidden = 0
      AND   n.is_hidden = 0
    GROUP BY n.ictv_id, p.ictv_id;

    /* ***************************
       5.  Resurrection links (dist = 1)
           - pairs that share the same *name* but have non-overlapping
             MSL lifetimes (abolished → re-created later).
       *************************** */
    INSERT INTO taxonomy_node_merge_split
            (prev_ictv_id, next_ictv_id,
             is_merged, is_split, is_recreated,
             dist,       rev_count)
    SELECT
        /* direction = 0 → early→late, 1 → late→early  */
        CASE WHEN dir.rev_count = 0 THEN early.ictv_id ELSE late.ictv_id END,
        CASE WHEN dir.rev_count = 0 THEN late.ictv_id  ELSE early.ictv_id END,
        0,                -- merged
        0,                -- split
        1,                -- recreated
        1,                -- distance
        dir.rev_count
    FROM  ( SELECT 0 AS rev_count UNION ALL SELECT 1 ) AS dir
    JOIN  taxonomy_node_dx  AS early
      ON  1=1
      /* SQL Server version does not require early.next_tags LIKE '%Abolish%'.
         Keep the same behavior here for parity: any name-match with a later
         non-overlapping lifetime can be treated as a recreation candidate. */
    JOIN  taxonomy_node_dx  AS late
      ON  late.name             = early.name
     AND  late.msl_release_num  > early.msl_release_num
     AND  late.ictv_id          <> early.ictv_id
     AND  late.level_id          = early.level_id
    WHERE NOT EXISTS (
             SELECT 1
             FROM   taxonomy_node_merge_split ms
             /* Direction-aware existence check: we insert both forward and
                backward resurrection links (dir.rev_count 0/1), so the NOT
                EXISTS must match the *actual* pair being inserted. */
             WHERE  ms.prev_ictv_id = CASE WHEN dir.rev_count = 0 THEN early.ictv_id ELSE late.ictv_id END
               AND  ms.next_ictv_id = CASE WHEN dir.rev_count = 0 THEN late.ictv_id  ELSE early.ictv_id END
          )
    /* taxonomy_node_dx can have duplicate rows; collapse to unique pairs so we
       don't attempt to insert the same PK more than once. */
    GROUP BY
        CASE WHEN dir.rev_count = 0 THEN early.ictv_id ELSE late.ictv_id END,
        CASE WHEN dir.rev_count = 0 THEN late.ictv_id  ELSE early.ictv_id END,
        dir.rev_count;

    /* ==================================================================
       6.  Transitive closure:
           repeatedly add p → n when p → x and x → n exist.
       ================================================================== */

    SELECT 'start closure' AS info;

    WHILE v_rows > 0 DO
        INSERT INTO taxonomy_node_merge_split
                (prev_ictv_id, next_ictv_id,
                 is_merged, is_split, is_recreated,
                 dist,       rev_count)
        SELECT  p.prev_ictv_id,
                n.next_ictv_id,
                /* Match SQL Server semantics: treat these as counts computed
                   from the composed path (p -> mid -> n), then collapse
                   multiple paths between the same endpoints by taking MAX. */
                MAX(p.is_merged + n.is_merged),
                MAX(p.is_split  + n.is_split),
                MAX(p.is_recreated + n.is_recreated),
                MIN(p.dist + n.dist),
                SUM(p.rev_count + n.rev_count)
        FROM    taxonomy_node_merge_split AS p
        JOIN    taxonomy_node_merge_split AS n
               ON p.next_ictv_id = n.prev_ictv_id
        WHERE   p.dist > 0
          AND   n.dist > 0
        GROUP BY p.prev_ictv_id,
                 n.next_ictv_id
        HAVING  NOT EXISTS (
                   SELECT 1
                   FROM   taxonomy_node_merge_split cur
                   WHERE  cur.prev_ictv_id = p.prev_ictv_id
                     AND  cur.next_ictv_id = n.next_ictv_id
               );

        SET v_rows = ROW_COUNT();   -- number of rows added in this pass
    END WHILE;

    SELECT 'closure done' AS info;

    COMMIT;
END$$
DELIMITER ;
