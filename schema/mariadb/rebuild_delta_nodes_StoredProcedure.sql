/* ================================================================
   Stored procedure  : rebuild_delta_nodes
   Converted from    : SQL-Server to MariaDB
   Preserves         : All original comments and behaviour
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS rebuild_delta_nodes $$
CREATE PROCEDURE rebuild_delta_nodes
(
      IN  p_msl         INT
    , IN  p_debug_taxid INT
)
BEGIN
    /* -------------------------------------------------------------
       Apply default MSL if caller passed NULL
       ------------------------------------------------------------- */
    IF p_msl IS NULL THEN
        SELECT MAX(msl_release_num) INTO p_msl
        FROM   taxonomy_node;
    END IF;

    /* tiny helper for debug output -------------------------------- */
    SELECT CONCAT('TARGET MSL: ', p_msl) AS msg;

    /* **************************************************************
       1. Clean out existing deltas for this MSL
       ************************************************************** */
    DELETE FROM taxonomy_node_delta
    WHERE msl = p_msl;
    SELECT 'MSL deltas DELETED' AS msg;

    /* **************************************************************
       2. IN-CHANGE  –  NEW / SPLIT
       ************************************************************** */
    INSERT INTO taxonomy_node_delta
           ( msl, prev_taxid, new_taxid, proposal, notes
           , is_new, is_split
           , is_now_type, is_promoted, is_demoted )
    SELECT
          n.msl_release_num                                            AS msl
        , p.taxnode_id                                                 AS prev_taxid
        , n.taxnode_id                                                 AS new_taxid
        , n.in_filename                                                AS proposal
        , n.in_notes                                                   AS notes
        , IF(n.in_change='new'  ,1,0)                                  AS is_new
        , IF(n.in_change='split',1,0)                                  AS is_split
        , CASE                             /* is_now_type heuristic */
              WHEN p.is_ref = 1 AND n.is_ref = 0 THEN -1
              WHEN p.is_ref = 0 AND n.is_ref = 1 THEN  1
              ELSE 0
          END                                                         AS is_now_type
        , IF(p.level_id > n.level_id,1,0)                             AS is_promoted
        , IF(p.level_id < n.level_id,1,0)                             AS is_demoted
    FROM taxonomy_node            AS n
    LEFT JOIN taxonomy_node       AS p   ON  p.msl_release_num = n.msl_release_num-1
                                         AND n.in_target       IN (p.lineage, p.name)
    LEFT JOIN taxonomy_node_delta AS d   ON  d.new_taxid       = n.taxnode_id
    WHERE n.in_change IN ('new','split')
      AND d.new_taxid IS NULL
      AND n.msl_release_num = p_msl
      AND n.is_deleted      = 0
      AND (p_debug_taxid IS NULL OR n.taxnode_id = p_debug_taxid);
    SELECT 'IN_CHANGE new / split INSERTED' AS msg;

    /* **************************************************************
       3. OUT-CHANGE  – rename / merge / promote / move / abolish
       ************************************************************** */
    INSERT INTO taxonomy_node_delta
           ( msl, prev_taxid, new_taxid, proposal, notes
           , is_renamed, is_merged, is_lineage_updated
           , is_promoted, is_demoted, is_now_type, is_deleted )
    SELECT
          p_msl                                                      AS msl
        , src.prev_taxid
        , src.new_taxid
        , src.proposal
        , src.notes
        , IF(prev_msl.name <> next_msl.name AND src.is_merged = 0,1,0)      AS is_renamed
        , src.is_merged
        , IF(prev_pmsl.lineage <> next_pmsl.lineage
             AND (prev_pmsl.level_id<>100 OR next_pmsl.level_id<>100),1,0)  AS is_lineage_updated
        , IF(prev_msl.level_id > next_msl.level_id,1,0)                      AS is_promoted
        , IF(prev_msl.level_id < next_msl.level_id,1,0)                      AS is_demoted
        , CASE                                                              /* now-type */
              WHEN prev_msl.is_ref = 1 AND next_msl.is_ref = 0 THEN -1
              WHEN prev_msl.is_ref = 0 AND next_msl.is_ref = 1 THEN  1
              ELSE 0
          END                                                               AS is_now_type
        , src.is_abolish                                                    AS is_deleted
    FROM (
            /* --- source rows building the OUT-CHANGE map ---------- */
            SELECT DISTINCT
                   p.taxnode_id                                   AS prev_taxid
                 , CASE
                       WHEN p.out_change <> 'promote'
                            AND p.level_id > targ.level_id
                            AND targ_child.taxnode_id IS NOT NULL
                            THEN targ_child.taxnode_id
                       WHEN p.level_id = 500 AND targ.level_id = 600
                            AND p.name <> 'Unassigned'
                            THEN targ.parent_id
                       ELSE targ.taxnode_id
                   END                                            AS new_taxid
                 , p.out_filename                                 AS proposal
                 , p.out_notes                                    AS notes
                 , IF(p.out_change='merge'  ,1,0)                 AS is_merged
                 , IF(p.out_change='abolish',1,0)                 AS is_abolish
            FROM taxonomy_node            AS p
            LEFT JOIN taxonomy_node       AS targ
                        ON targ.msl_release_num = p.msl_release_num + 1
                       AND ( p.out_target IN (targ.lineage, targ.name)
                             OR p._out_target_name = targ.name )
            LEFT JOIN taxonomy_node       AS targ_child
                        ON targ_child.parent_id = targ.taxnode_id
                       AND targ_child.name     IN (p.name, p.out_target)
                       AND targ_child.level_id = p.level_id
                       AND p.out_change <> 'promote'
                       AND targ_child.name <> 'Unassigned'
                       AND targ_child.is_hidden = 0
            LEFT JOIN taxonomy_node_delta AS d
                        ON d.prev_taxid = p.taxnode_id
            WHERE p.out_change IS NOT NULL
              AND p.msl_release_num = p_msl-1
              AND d.prev_taxid IS NULL
         ) AS src
    JOIN taxonomy_node       AS prev_msl  ON prev_msl.taxnode_id = src.prev_taxid
    JOIN taxonomy_node       AS prev_pmsl ON prev_pmsl.taxnode_id = prev_msl.parent_id
    LEFT JOIN taxonomy_node  AS next_msl  ON next_msl.taxnode_id  = src.new_taxid
    LEFT JOIN taxonomy_node  AS next_pmsl ON next_pmsl.taxnode_id = next_msl.parent_id
    WHERE p_debug_taxid IS NULL
       OR src.new_taxid = p_debug_taxid;
    SELECT 'OUT_CHANGE rename / merge / etc INSERTED' AS msg;

    /* **************************************************************
       4. NO-CHANGE rows (same lineage or same non-Unassigned name)
       ************************************************************** */
    INSERT INTO taxonomy_node_delta
           ( msl, prev_taxid, new_taxid, proposal, notes
           , is_lineage_updated, is_promoted, is_demoted, is_now_type )
    SELECT
          n.msl_release_num
        , p.taxnode_id
        , n.taxnode_id
        , p.out_filename
        , p.out_notes
        , IF(pp.lineage <> pn.lineage AND pp.level_id<>100,1,0)
        , IF(p.level_id > n.level_id ,1,0)
        , IF(p.level_id < n.level_id ,1,0)
        , CASE
              WHEN p.is_ref = 1 AND n.is_ref = 0 THEN -1
              WHEN p.is_ref = 0 AND n.is_ref = 1 THEN  1
              ELSE 0
          END
    FROM taxonomy_node p
    JOIN taxonomy_node n
         ON n.msl_release_num = p.msl_release_num + 1
        AND (
                n.lineage = p.lineage
             OR (n.name = p.name AND n.name <> 'Unassigned' AND n.level_id = p.level_id)
             OR (n.level_id = 100 AND p.level_id = 100)
            )
        AND (
                (p.is_hidden = 0 AND n.is_hidden = 0)
             OR (n.level_id = 100 AND p.level_id = 100)
            )
    LEFT JOIN taxonomy_node_delta pd ON pd.prev_taxid = p.taxnode_id
    LEFT JOIN taxonomy_node_delta nd ON nd.new_taxid  = n.taxnode_id
    JOIN taxonomy_node pp ON pp.taxnode_id = p.parent_id
    JOIN taxonomy_node pn ON pn.taxnode_id = n.parent_id
    WHERE n.msl_release_num = p_msl
      AND pd.prev_taxid IS NULL
      AND nd.new_taxid  IS NULL
      AND p.is_deleted = 0
      AND n.is_deleted = 0
      AND (p_debug_taxid IS NULL OR n.taxnode_id = p_debug_taxid);
    SELECT 'NO_CHANGE rows INSERTED' AS msg;

    /* **************************************************************
       5. Flag “is_moved” cases
       ************************************************************** */
    UPDATE taxonomy_node_delta      AS d
    LEFT JOIN taxonomy_node         AS prev_node   ON prev_node.taxnode_id = d.prev_taxid
    LEFT JOIN taxonomy_node         AS next_node   ON next_node.taxnode_id = d.new_taxid
    LEFT JOIN taxonomy_node         AS prev_parent ON prev_parent.taxnode_id = prev_node.parent_id
    LEFT JOIN taxonomy_node         AS next_parent ON next_parent.taxnode_id = next_node.parent_id
    LEFT JOIN taxonomy_node_delta   AS parent_del  ON parent_del.prev_taxid = prev_parent.taxnode_id
                                                 AND parent_del.new_taxid  = next_parent.taxnode_id
    SET d.is_moved =
        (prev_parent.ictv_id <> next_parent.ictv_id)
        * (prev_node.out_change NOT LIKE '%promot%')
        * (next_node.out_change NOT LIKE '%demot%')
        * (CASE WHEN parent_del.is_merged = 1 AND prev_parent.name = next_parent.name THEN 0 ELSE 1 END)
        * (CASE WHEN parent_del.is_split  = 1 AND prev_parent.name = next_parent.name THEN 0 ELSE 1 END)
        * (CASE WHEN prev_parent.level_id = 100 AND next_parent.level_id = 100 THEN 0 ELSE 1 END)
    WHERE d.msl = p_msl;
    SELECT 'IS_MOVED flags UPDATED' AS msg;

    /* **************************************************************
       6. Inherit “is_merged” across all rows sharing new_taxid
       ************************************************************** */
    UPDATE taxonomy_node_delta d
    JOIN ( SELECT new_taxid,
                  MAX(proposal) AS proposal,
                  MAX(notes)    AS notes
           FROM   taxonomy_node_delta
           WHERE  msl = p_msl
           GROUP  BY new_taxid
           HAVING COUNT(*) > 1 ) msrc
         ON msrc.new_taxid = d.new_taxid
    SET  d.is_merged = 1,
         d.proposal  = msrc.proposal,
         d.notes     = msrc.notes
    WHERE d.msl = p_msl
      AND d.is_merged = 0;
    SELECT 'IS_MERGED siblings UPDATED' AS msg;

    /* **************************************************************
       7. Simple stats (was PRINT in T-SQL)
       ************************************************************** */
    SELECT msl,
           IF(tag_csv='', 'UNCHANGED', tag_csv)   AS change_type,
           COUNT(*)                               AS cnt
    FROM   taxonomy_node_delta
    WHERE  msl = p_msl
    GROUP  BY msl, tag_csv
    ORDER  BY change_type;

    SELECT msl,
           IF(tag_csv2='', 'UNCHANGED', tag_csv2) AS change_type,
           COUNT(*)                               AS cnt
    FROM   taxonomy_node_delta
    WHERE  msl = p_msl
    GROUP  BY msl, tag_csv2
    ORDER  BY change_type;

END$$
DELIMITER ;