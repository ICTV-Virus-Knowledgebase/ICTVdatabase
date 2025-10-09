DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_ictv_id_deltas $$
CREATE PROCEDURE QC_module_ictv_id_deltas
(
    IN p_filter VARCHAR(1000)   -- pass NULL to use default 'ERROR%'
)
BEGIN
    DECLARE v_current_msl INT;

    -- default like SQL Server param default
    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;

    -- cache current MSL
    SELECT MAX(msl_release_num) INTO v_current_msl
    FROM taxonomy_toc;

    /* Main query: build ictvs (per-ictv_id stats), join to nd/ed lookups,
       compute create/end/gap errors and final qc_mesg, then filter via HAVING */
    SELECT
        'QC_module_ictv_id_deltas' AS qc_module,
        '[taxonomy_node_delta]'    AS table_name,

        -- ictvs columns
        ictvs.name,
        ictvs.ictv_id,
        ictvs.min_taxnode_id,
        ictvs.max_taxnode_id,
        ictvs.min_msl,
        ictvs.max_msl,
        ictvs.cur_msl,
        ictvs.is_msl_cur,
        ictvs.ct,
        ictvs.ct_prev,
        ictvs.ct_next,

        -- computed tags/errors (same semantics as original)
        IFNULL(nd.tag_csv2,'') AS create_tags,
        CASE
          WHEN nd.is_new IS NULL THEN 'create_missing'
          WHEN IFNULL(nd.is_new,0) + IFNULL(nd.is_merged,0) + IFNULL(nd.is_split,0) = 0
               THEN 'create_wrong'
          ELSE ''
        END AS create_err,

        IFNULL(ed.tag_csv2,'') AS end_tags,
        CASE
          WHEN ictvs.cur_msl = ictvs.max_msl THEN ''
          WHEN ed.is_deleted IS NULL THEN 'end_missing'
          WHEN IFNULL(ed.is_deleted,0) + IFNULL(ed.is_merged,0) + IFNULL(ed.is_split,0) = 0
               THEN 'end_wrong'
          ELSE ''
        END AS end_err,

        TRIM(CONCAT(
          CASE
            WHEN ictvs.ct <> ictvs.ct_prev
                 THEN CONCAT('gap_prev:', CAST(ictvs.ct - ictvs.ct_prev AS CHAR))
            ELSE ''
          END,
          ' ',
          CASE
            WHEN ictvs.ct <> (ictvs.ct_next + ictvs.is_msl_cur)
                 THEN CONCAT('gap_next:', CAST(ictvs.ct - (ictvs.ct_next + ictvs.is_msl_cur) AS CHAR))
            ELSE ''
          END
        )) AS gap_err,

        -- final QC message (alias we can filter on)
        CASE
          WHEN
            (CASE
               WHEN nd.is_new IS NULL THEN 'create_missing'
               WHEN IFNULL(nd.is_new,0) + IFNULL(nd.is_merged,0) + IFNULL(nd.is_split,0) = 0
                    THEN 'create_wrong'
               ELSE ''
             END) = ''
          AND
            (CASE
               WHEN ictvs.cur_msl = ictvs.max_msl THEN ''
               WHEN ed.is_deleted IS NULL THEN 'end_missing'
               WHEN IFNULL(ed.is_deleted,0) + IFNULL(ed.is_merged,0) + IFNULL(ed.is_split,0) = 0
                    THEN 'end_wrong'
               ELSE ''
             END) = ''
          AND
            TRIM(CONCAT(
              CASE
                WHEN ictvs.ct <> ictvs.ct_prev
                     THEN CONCAT('gap_prev:', CAST(ictvs.ct - ictvs.ct_prev AS CHAR))
                ELSE ''
              END,
              ' ',
              CASE
                WHEN ictvs.ct <> (ictvs.ct_next + ictvs.is_msl_cur)
                     THEN CONCAT('gap_next:', CAST(ictvs.ct - (ictvs.ct_next + ictvs.is_msl_cur) AS CHAR))
                ELSE ''
              END
            )) = ''
          THEN 'OK'
          ELSE CONCAT(
                 'ERROR: ',
                 (CASE
                    WHEN nd.is_new IS NULL THEN 'create_missing'
                    WHEN IFNULL(nd.is_new,0) + IFNULL(nd.is_merged,0) + IFNULL(nd.is_split,0) = 0
                         THEN 'create_wrong'
                    ELSE ''
                  END),
                 ' ',
                 (CASE
                    WHEN ictvs.cur_msl = ictvs.max_msl THEN ''
                    WHEN ed.is_deleted IS NULL THEN 'end_missing'
                    WHEN IFNULL(ed.is_deleted,0) + IFNULL(ed.is_merged,0) + IFNULL(ed.is_split,0) = 0
                         THEN 'end_wrong'
                    ELSE ''
                  END),
                 ' ',
                 TRIM(CONCAT(
                   CASE
                     WHEN ictvs.ct <> ictvs.ct_prev
                          THEN CONCAT('gap_prev:', CAST(ictvs.ct - ictvs.ct_prev AS CHAR))
                     ELSE ''
                   END,
                   ' ',
                   CASE
                     WHEN ictvs.ct <> (ictvs.ct_next + ictvs.is_msl_cur)
                          THEN CONCAT('gap_next:', CAST(ictvs.ct - (ictvs.ct_next + ictvs.is_msl_cur) AS CHAR))
                     ELSE ''
                   END
                 ))
               )
        END AS qc_mesg

    FROM
    (
      -- ictvs: stats per ictv_id
      SELECT
        CONCAT(MIN(n.name),
               IF(MIN(n.name) <> MAX(n.name),
                    CONCAT(':', MAX(n.name)),
                    '')
             )                                    AS name,
        n.ictv_id,
        MIN(n.taxnode_id)                         AS min_taxnode_id,
        MAX(n.taxnode_id)                         AS max_taxnode_id,
        MIN(n.msl_release_num)                    AS min_msl,
        MAX(n.msl_release_num)                    AS max_msl,
        v_current_msl                             AS cur_msl,
        IF(v_current_msl = MAX(n.msl_release_num), 1, 0)
                                                 AS is_msl_cur,
        COUNT(DISTINCT n.taxnode_id)              AS ct,
        COUNT(DISTINCT nd_all.new_taxid)          AS ct_prev,
        COUNT(DISTINCT ed_all.prev_taxid)         AS ct_next
      FROM taxonomy_node AS n
      LEFT JOIN taxonomy_node_delta AS nd_all
             ON nd_all.new_taxid  = n.taxnode_id
      LEFT JOIN taxonomy_node_delta AS ed_all
             ON ed_all.prev_taxid = n.taxnode_id
      WHERE n.is_deleted       = 0
        AND n.is_obsolete      = 0
        AND n.msl_release_num IS NOT NULL
      GROUP BY n.ictv_id
    ) AS ictvs
    LEFT JOIN taxonomy_node_delta AS nd
           ON nd.new_taxid  = ictvs.min_taxnode_id
    LEFT JOIN taxonomy_node_delta AS ed
           ON ed.prev_taxid = ictvs.max_taxnode_id

    HAVING qc_mesg LIKE p_filter
    ORDER BY ictvs.ictv_id;

END $$
DELIMITER ;