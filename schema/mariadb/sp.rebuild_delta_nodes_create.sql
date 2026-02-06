/* ================================================================
   Stored procedure  : rebuild_delta_nodes
   Converted from    : SQL-Server to MariaDB on 08042025
   ================================================================ */
/* ================================================================
    LRM 02062025: Switch to utf8mb4_uca1400_as_cs from utf8mb4_bin.
   utf8mb4_uca1400_as_cs, I think matches collation used in SQL
   Server version better
   ================================================================ */

DELIMITER //

DROP PROCEDURE IF EXISTS rebuild_delta_nodes //
CREATE PROCEDURE rebuild_delta_nodes
(
    IN  p_msl         INT DEFAULT NULL,
    IN  p_debug_taxid INT DEFAULT NULL,
    IN  p_debug_notes VARCHAR(20) DEFAULT NULL
)
BEGIN
    /* -------------------------------------------------------------
       Emulate default parameters (SQL Server style)
    ------------------------------------------------------------- */
    IF p_msl IS NULL THEN
        SELECT MAX(msl_release_num) INTO p_msl FROM taxonomy_node;
    END IF;

    /* -------------------------------------------------------------
       Clean existing deltas for this MSL
    ------------------------------------------------------------- */
    DELETE FROM taxonomy_node_delta
     WHERE msl = p_msl;

    /* -------------------------------------------------------------
       IN-CHANGE  (new / split)
    ------------------------------------------------------------- */
    INSERT INTO taxonomy_node_delta
        ( msl, prev_taxid, new_taxid, proposal, notes,
          is_new, is_split,
          is_now_type, is_promoted, is_demoted )
    SELECT
        n.msl_release_num                                           AS msl,
        p.taxnode_id,
        n.taxnode_id,
        n.in_filename                                               AS proposal,
        -- LRM 02062026: CONCAT_WS does not treat empty strings as NULL, switch to a CASE that preserves NULLs
        CASE
            WHEN p_debug_notes IS NULL THEN n.in_notes
            ELSE CONCAT('[',p_debug_notes,'NEW/SPLIT];', COALESCE(n.in_notes,''))
        END                                                         AS notes,
        (n.in_change='new')                                         AS is_new,
        (n.in_change='split')                                       AS is_split,
        CASE
            WHEN p.is_ref=1  AND n.is_ref=0 THEN -1
            WHEN p.is_ref=0  AND n.is_ref=1 THEN  1
            ELSE 0
        END                                                         AS is_now_type,
        IF(p.level_id IS NOT NULL AND n.level_id IS NOT NULL AND p.level_id > n.level_id, 1, 0) AS is_promoted,
        IF(p.level_id IS NOT NULL AND n.level_id IS NOT NULL AND p.level_id < n.level_id, 1, 0) AS is_demoted
    FROM taxonomy_node AS n
    LEFT JOIN taxonomy_node AS p  ON p.msl_release_num = n.msl_release_num-1
                                 AND n.in_target COLLATE utf8mb4_uca1400_as_cs IN (p.lineage, p.name)
    LEFT JOIN taxonomy_node_delta d
    ON d.msl = p_msl
    AND d.new_taxid = n.taxnode_id
    WHERE n.in_change IN ('new','split')
      AND d.new_taxid IS NULL
      AND n.msl_release_num = p_msl
      AND n.is_deleted      = 0
      AND (p_debug_taxid IS NULL OR n.taxnode_id = p_debug_taxid);
    -- #############################################################

    /* -------------------------------------------------------------
       OUT-CHANGE  (rename / merge / promote / move / abolish)
    ------------------------------------------------------------- */
    INSERT INTO taxonomy_node_delta
        ( msl, prev_taxid, new_taxid, proposal, notes,
          is_renamed, is_merged, is_lineage_updated,
          is_promoted, is_demoted, is_now_type, is_deleted )
    SELECT
        s.msl,
        s.prev_taxid,
        s.new_taxid,
        s.proposal,
        -- LRM 02062026: CONCAT_WS does not treat empty strings as NULL, switch to a CASE that preserves NULLs
        CASE
            WHEN p_debug_notes IS NULL THEN s.notes
            ELSE CONCAT('[',p_debug_notes,'RENAME,MERGE,PROMOTE,MOVE,ABOLISH];', COALESCE(s.notes,''))
        END,
        IF(
            next_msl.name IS NOT NULL
            AND prev_msl.name IS NOT NULL
            AND prev_msl.name <> next_msl.name COLLATE utf8mb4_uca1400_as_cs
            AND COALESCE(s.is_merged,0) = 0,
            1, 0
        ) AS is_renamed,
        s.is_merged,
        IF(
            next_pmsl.lineage IS NOT NULL
            AND prev_pmsl.lineage IS NOT NULL
            AND prev_pmsl.lineage <> next_pmsl.lineage COLLATE utf8mb4_uca1400_as_cs
            AND (prev_pmsl.level_id<>100 OR next_pmsl.level_id<>100),
            1, 0
        ) AS is_lineage_updated,
         IF(next_msl.level_id IS NOT NULL AND prev_msl.level_id > next_msl.level_id, 1, 0) AS is_promoted,
         IF(next_msl.level_id IS NOT NULL AND prev_msl.level_id < next_msl.level_id, 1, 0) AS is_demoted,
        CASE
            WHEN prev_msl.is_ref=1 AND next_msl.is_ref=0 THEN -1
            WHEN prev_msl.is_ref=0 AND next_msl.is_ref=1 THEN  1
            ELSE 0
        END                                                         AS is_now_type,
        s.is_abolish
    FROM (
        /* — identical derivation of src as in SQL Server — */
        SELECT DISTINCT
            p.msl_release_num+1   AS msl,
            p.taxnode_id          AS prev_taxid,
            /* ‎… rule-based new_taxid selection kept unchanged … */
            CASE
              WHEN p.out_change <> 'promote'
               AND p.level_id > targ.level_id
               AND targ_child.taxnode_id IS NOT NULL
                   THEN targ_child.taxnode_id
              WHEN p.level_id=500 AND targ.level_id=600
               AND p.name <> 'Unassigned'
                   THEN targ.parent_id
              ELSE targ.taxnode_id
            END                AS new_taxid,
            p.out_filename     AS proposal,
            CAST(p.out_notes AS CHAR) AS notes,
            (p.out_change='merge')  AS is_merged,
            (p.out_change='abolish') AS is_abolish
        FROM taxonomy_node            p
        LEFT JOIN taxonomy_node       targ
              ON targ.msl_release_num = p.msl_release_num+1
             AND (p.out_target COLLATE utf8mb4_uca1400_as_cs IN (targ.lineage,targ.name)
                  OR p._out_target_name COLLATE utf8mb4_uca1400_as_cs = targ.name)
             AND p.is_deleted = 0
        LEFT JOIN taxonomy_node targ_child
              ON targ_child.parent_id = targ.taxnode_id
             AND (targ_child.name = p.name COLLATE utf8mb4_uca1400_as_cs
                  OR targ_child.name = p.out_target COLLATE utf8mb4_uca1400_as_cs)
             AND targ_child.level_id = p.level_id
             AND p.out_change <> 'promote'
             AND targ_child.name <> 'Unassigned'
             AND targ_child.is_hidden = 0
        -- LEFT JOIN taxonomy_node_delta d
        --       ON d.prev_taxid = p.taxnode_id
        LEFT JOIN taxonomy_node_delta d
            ON d.msl = p_msl
            AND d.prev_taxid = p.taxnode_id
        WHERE p.out_change IS NOT NULL
          AND p.msl_release_num = p_msl-1
          AND d.prev_taxid IS NULL
    ) AS s
    JOIN taxonomy_node prev_msl  ON prev_msl.taxnode_id = s.prev_taxid
    JOIN taxonomy_node prev_pmsl ON prev_pmsl.taxnode_id = prev_msl.parent_id
    LEFT JOIN taxonomy_node next_msl  ON next_msl.taxnode_id = s.new_taxid
    LEFT JOIN taxonomy_node next_pmsl ON next_pmsl.taxnode_id = next_msl.parent_id
    WHERE (p_debug_taxid IS NULL OR s.new_taxid = p_debug_taxid);
    -- #############################################################

    /* -------------------------------------------------------------
       NO-CHANGE and UPDATE (same lineage etc.)
       — unchanged SQL translated only for syntax —
    ------------------------------------------------------------- */
    INSERT INTO taxonomy_node_delta
        (msl, prev_taxid, new_taxid, proposal, notes,
         is_lineage_updated, is_promoted, is_demoted, is_now_type)
    SELECT
        n.msl_release_num,
        p.taxnode_id,
        n.taxnode_id,
        p.out_filename,
        CASE
            WHEN p_debug_notes IS NULL THEN p.out_notes
            ELSE CONCAT('[',p_debug_notes,'NO CHANGE];', COALESCE(p.out_notes,''))
        END,
        IF(
            pp.lineage IS NOT NULL
            AND pn.lineage IS NOT NULL
            AND pp.lineage <> pn.lineage COLLATE utf8mb4_uca1400_as_cs
            AND pp.level_id<>100,
            1, 0
        )                                                   AS is_lineage_updated,
         IF(p.level_id IS NOT NULL AND n.level_id IS NOT NULL AND p.level_id > n.level_id, 1, 0) AS is_promoted,
         IF(p.level_id IS NOT NULL AND n.level_id IS NOT NULL AND p.level_id < n.level_id, 1, 0) AS is_demoted,
        -- (p.level_id > n.level_id)                           AS is_promoted,
        -- (p.level_id < n.level_id)                           AS is_demoted,
        CASE
          WHEN p.is_ref=1 AND n.is_ref=0 THEN -1
          WHEN p.is_ref=0 AND n.is_ref=1 THEN  1
          ELSE 0
        END                                                 AS is_now_type
    FROM taxonomy_node p
    JOIN taxonomy_node n
         ON n.msl_release_num = p.msl_release_num+1
        AND ( n.lineage = p.lineage
           OR (n.name = p.name COLLATE utf8mb4_uca1400_as_cs
               AND n.name<>'Unassigned' AND n.level_id=p.level_id)
           OR (n.level_id=100 AND p.level_id=100) )
    -- LEFT JOIN taxonomy_node_delta pd
    --      ON pd.prev_taxid = p.taxnode_id
    --     AND pd.is_split  = 0
    -- LEFT JOIN taxonomy_node_delta nd
    --      ON nd.new_taxid = n.taxnode_id
    --     AND nd.is_merged = 0
    LEFT JOIN taxonomy_node_delta pd
        ON pd.msl = p_msl
        AND pd.prev_taxid = p.taxnode_id
        AND pd.is_split = 0
    LEFT JOIN taxonomy_node_delta nd
        ON nd.msl = p_msl
        AND nd.new_taxid = n.taxnode_id
        AND nd.is_merged = 0
    JOIN taxonomy_node pp ON pp.taxnode_id = p.parent_id
    JOIN taxonomy_node pn ON pn.taxnode_id = n.parent_id
    WHERE n.msl_release_num = p_msl
      AND pd.prev_taxid IS NULL
      AND nd.new_taxid IS NULL
      AND p.is_deleted = 0
      AND n.is_deleted = 0
      AND (p_debug_taxid IS NULL OR n.taxnode_id = p_debug_taxid);
    -- #############################################################

    /* -------------------------------------------------------------
       UPDATE is_moved  (same arithmetic logic, CONCAT in notes)
    ------------------------------------------------------------- */

    UPDATE taxonomy_node_delta AS d
    LEFT JOIN taxonomy_node_names prev_node  ON prev_node.taxnode_id = d.prev_taxid
    LEFT JOIN taxonomy_node       prev_parent ON prev_parent.taxnode_id = prev_node.parent_id
    LEFT JOIN taxonomy_node_names next_node  ON next_node.taxnode_id = d.new_taxid
    LEFT JOIN taxonomy_node       next_parent ON next_parent.taxnode_id = next_node.parent_id
    LEFT JOIN taxonomy_node_delta parent_delta
        ON parent_delta.prev_taxid = prev_parent.taxnode_id
        AND parent_delta.new_taxid  = next_parent.taxnode_id
    SET
    d.is_moved =
        (
        IF(prev_parent.ictv_id IS NOT NULL AND next_parent.ictv_id IS NOT NULL
            AND prev_parent.ictv_id <> next_parent.ictv_id, 1, 0)
        * IF(COALESCE(prev_node.out_change, '') NOT LIKE '%promot%', 1, 0)
        * IF(COALESCE(prev_node.out_change, '') NOT LIKE '%demot%', 1, 0)
        * IF(COALESCE(parent_delta.is_merged, 0) = 1, 0, 1)
        * IF(COALESCE(parent_delta.is_split, 0) = 1,
            IF(prev_parent.ictv_id IS NOT NULL AND next_parent.ictv_id IS NOT NULL
                AND prev_parent.ictv_id <> next_parent.ictv_id, 1, 0),
            1)
        * IF(prev_parent.level_id = 100 AND next_parent.level_id = 100, 0, 1)
        ),
        d.notes = CASE
        WHEN
            (
            IF(prev_parent.ictv_id IS NOT NULL AND next_parent.ictv_id IS NOT NULL
                AND prev_parent.ictv_id <> next_parent.ictv_id, 1, 0)
            * IF(COALESCE(prev_node.out_change, '') NOT LIKE '%promot%', 1, 0)
            * IF(COALESCE(prev_node.out_change, '') NOT LIKE '%demot%', 1, 0)
            * IF(COALESCE(parent_delta.is_merged, 0) = 1, 0, 1)
            * IF(COALESCE(parent_delta.is_split, 0) = 1,
                IF(prev_parent.ictv_id IS NOT NULL AND next_parent.ictv_id IS NOT NULL
                    AND prev_parent.ictv_id <> next_parent.ictv_id, 1, 0),
                1)
            * IF(prev_parent.level_id = 100 AND next_parent.level_id = 100, 0, 1)
            ) = 1
            AND p_debug_notes IS NOT NULL
            AND d.notes IS NOT NULL
            AND d.notes <> ''
        THEN CONCAT('[', p_debug_notes, 'SET MOVED=1];', d.notes)
        ELSE d.notes
        END
        WHERE d.msl = p_msl
            AND prev_node.msl_release_num + 1 = p_msl;

    /* -------------------------------------------------------------
       UPGRADE rename → merge when N:1
    ------------------------------------------------------------- */

    -- LRM 02062026: Re-worked to take MAX(notes) among siblings and write it back to all siblings
    -- Before, this snippet was not getting the right value in the notes column for some rows

    UPDATE taxonomy_node_delta AS d
    JOIN (
        SELECT
            new_taxid,
            MAX(proposal) AS proposal,
            MAX(notes)    AS notes
        FROM taxonomy_node_delta
        WHERE msl = p_msl
        GROUP BY new_taxid
        HAVING COUNT(*) > 1
    ) AS msrc
    ON msrc.new_taxid = d.new_taxid
    SET
    d.is_merged  = 1,
    d.is_renamed = 0,
    d.proposal   = msrc.proposal,
    d.notes      = CASE
        WHEN p_debug_notes IS NULL THEN msrc.notes
        ELSE CONCAT('[', p_debug_notes, 'UPGRADE_TO_MERGE];', msrc.notes)
    END
    WHERE d.msl = p_msl
    AND d.is_merged = 0;

END //
DELIMITER ;
