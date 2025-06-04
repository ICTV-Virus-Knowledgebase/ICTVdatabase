/* ================================================================
   Stored procedure  : QC_module_ictv_id_deltas   (MariaDB version)
   Converted from    : SQL-Server
   Behaviour         : Same result-set, same default parameter
   Tested on         : MariaDB 10.11
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_ictv_id_deltas $$
CREATE PROCEDURE QC_module_ictv_id_deltas
(
    IN p_filter VARCHAR(1000)          -- pass NULL to use default 'ERROR%'
)
BEGIN
    DECLARE v_current_msl INT;
    /* ---------------------------------------------------------------
       Provide the SQL-Server default value ('ERROR%') when caller
       passes NULL – MariaDB cannot put defaults in the parameter list
       --------------------------------------------------------------- */
    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;

    /* ---------------------------------------------------------------
       Cache the “current” MSL once – used many times below
       --------------------------------------------------------------- */
    SELECT MAX(msl_release_num) INTO v_current_msl
      FROM taxonomy_toc;

    /* ---------------------------------------------------------------
       Main query – almost identical to the original.
       Differences:
         • CONCAT() instead of + for strings
         • TOP 1 .. ORDER BY  →  LIMIT 1
         • CAST( … AS CHAR ) instead of CAST( … AS VARCHAR )
         • OBJECT_NAME(@@PROCID) replaced by a literal
       --------------------------------------------------------------- */
    SELECT
        'QC_module_ictv_id_deltas'                   AS qc_module,
        '[taxonomy_node_delta]'                      AS table_name,
        src.*,
        CASE
            WHEN src.create_err = ''
             AND src.end_err    = ''
             AND src.gap_err    = ''
            THEN 'OK'
            ELSE CONCAT('ERROR: ',
                        src.create_err,' ',
                        src.end_err  ,' ',
                        src.gap_err)
        END                                          AS qc_mesg
    FROM
    (
        /* -----------------------------------------------------------------
           ictvs : statistics per ictv_id
           ----------------------------------------------------------------- */
        SELECT
            /* If min(name) ≠ max(name) show both separated by ':' */
            CONCAT(MIN(n.name),
                   IF(MIN(n.name) <> MAX(n.name),
                        CONCAT(':', MAX(n.name)),
                        '')
                  )                                  AS name,

            n.ictv_id,
            MIN(n.taxnode_id)                       AS min_taxnode_id,
            MAX(n.taxnode_id)                       AS max_taxnode_id,
            MIN(n.msl_release_num)                  AS min_msl,
            MAX(n.msl_release_num)                  AS max_msl,
            v_current_msl                           AS cur_msl,
            IF(v_current_msl = MAX(n.msl_release_num), 1, 0)
                                                   AS is_msl_cur,

            COUNT(DISTINCT n.taxnode_id)            AS ct,
            COUNT(DISTINCT nd.new_taxid)            AS ct_prev,
            COUNT(DISTINCT ed.prev_taxid)           AS ct_next
        FROM taxonomy_node n
        LEFT JOIN taxonomy_node_delta nd
               ON nd.new_taxid  = n.taxnode_id
        LEFT JOIN taxonomy_node_delta ed
               ON ed.prev_taxid = n.taxnode_id
        WHERE n.is_deleted       = 0
          AND n.is_obsolete      = 0
          AND n.msl_release_num IS NOT NULL
        GROUP BY n.ictv_id
    ) AS ictvs
    /* -----------------------------------------------------------------
       Look-ups of the first / last node for each ictv_id
       ----------------------------------------------------------------- */
    LEFT JOIN taxonomy_node_delta nd
           ON nd.new_taxid  = ictvs.min_taxnode_id
    LEFT JOIN taxonomy_node_delta ed
           ON ed.prev_taxid = ictvs.max_taxnode_id
    /* -----------------------------------------------------------------
       Build the error strings exactly as the SQL-Server code did
       ----------------------------------------------------------------- */
    /* -------------- SELECT list with error logic --------------------- */
    CROSS JOIN
    (
        SELECT
            ictvs.*,

            /* tags and tests for “create” side */
            IFNULL(nd.tag_csv2,'')                  AS create_tags,
            CASE
               WHEN nd.is_new IS NULL
                    THEN 'create_missing'
               WHEN nd.is_new + nd.is_merged + nd.is_split = 0
                    THEN 'create_wrong'
               ELSE ''
            END                                     AS create_err,

            /* tags and tests for “end” side */
            IFNULL(ed.tag_csv2,'')                  AS end_tags,
            CASE
               WHEN ictvs.cur_msl = ictvs.max_msl
                    THEN ''
               WHEN ed.is_deleted IS NULL
                    THEN 'end_missing'
               WHEN ed.is_deleted + ed.is_merged + ed.is_split = 0
                    THEN 'end_wrong'
               ELSE ''
            END                                     AS end_err,

            /* gap tests */
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
                 END)
            )                                       AS gap_err
        FROM ictvs
        /* the derived table defined just above */
    ) AS src
    /* -----------------------------------------------------------------
       Apply caller’s filter and order by ictv_id
       ----------------------------------------------------------------- */
    WHERE (CASE
             WHEN src.create_err = ''
              AND src.end_err    = ''
              AND src.gap_err    = ''
             THEN 'OK'
             ELSE CONCAT('ERROR: ',
                         src.create_err,' ',
                         src.end_err  ,' ',
                         src.gap_err)
           END) LIKE p_filter
    ORDER BY ictv_id;

END$$
DELIMITER ;