/* ================================================================
   Stored procedure  : QC_module_taxonomy_node_ictv_resurrection
   Converted from    : SQL-Server to MariaDB on 08042025
   ================================================================ */

DELIMITER //

DROP PROCEDURE IF EXISTS QC_module_taxonomy_node_ictv_resurrection //
CREATE PROCEDURE QC_module_taxonomy_node_ictv_resurrection
(
    IN  p_filter      VARCHAR(1000),
    IN  p_target_name VARCHAR(100)
)
BEGIN
	IF p_filter IS NULL      THEN SET p_filter      := 'ERROR%'; END IF;
/* ------------------------------------------------------------------
   (LRM 07172025) ICTV_ID issues
   Identify ([rank],[name]) associated with multiple [ictv_id]’s
   – re-ported from SQL Server to MariaDB
   ------------------------------------------------------------------
   Tests you can run:
     CALL QC_module_taxonomy_node_ictv_resurrection();                     -- hard errors
     CALL QC_module_taxonomy_node_ictv_resurrection('%', 'Zika virus');    -- one name
     CALL QC_module_taxonomy_node_ictv_resurrection('%CASE%');             -- case problems
------------------------------------------------------------------- */

SELECT
   'QC_module_taxonomy_node_ictv_resurrection' AS qc_module,   -- SQL Server used OBJECT_NAME(@@PROCID)
   '[taxonomy_node]'                           AS table_name,
   src.*                                       -- every column produced below
FROM (

  /* ---------------------------------------------------------------
     pairs : each row holds the “prev” and “next” ICTV_ID slice for
             the same [rank,name] where a gap exists
  --------------------------------------------------------------- */
  SELECT
      pairs.*,

      /* ---------- QC message ------------------------------------ */
      CONCAT_WS(
          '',
          /* CASE warning */
          CASE
            WHEN pairs.p_name COLLATE utf8mb4_bin
               = pairs.n_name COLLATE utf8mb4_bin THEN ''
            ELSE 'WARNING: CASE; '
          END,

          /* linkage diagnostics */
          CASE
            WHEN pairs.link_ct = 0
              THEN 'ERROR: NOT LINKED;'
            WHEN pairs.link_ct = 1
             AND pairs.p_out_change = 'abolish'
             AND pairs.n_in_change = 'new'
              THEN 'OK: linked new:abolish/new:...'
            WHEN pairs.link_ct = 1
              THEN CONCAT(
                     'WARNING: linked, but ',
                     IFNULL(pairs.p_out_change,'NULL'), ':',
                     IFNULL(pairs.n_in_change,'NULL')
                   )
            WHEN pairs.link_ct > 1
              THEN 'ERROR: link_ct > 1'
            ELSE 'ERROR: unknown'
          END
      )                                                          AS qc_mesg

  FROM (
      /* ==========================================================
         Build the “prev” / “next” ranges for every [level_id,name]
         that maps to *more than one* ICTV_ID
      ========================================================== */

      /* ----- STEP 1: find names used by 2+ ICTV_IDs ------------- */
      SELECT
          n.level_id,
          n.name,
          COUNT(DISTINCT n.ictv_id)                AS ictv_ct
      FROM taxonomy_node AS n
      WHERE n.name = IFNULL(p_target_name, n.name)
        AND n.name <> 'Unnamed genus'
      GROUP BY n.level_id, n.name
      HAVING COUNT(DISTINCT n.ictv_id) > 1
  ) AS src

  /* ----- STEP 2: prev_range (earliest ICTV_ID slice) ----------- */
  JOIN (
      SELECT
          n.level_id,
          n.name,
          n.ictv_id,
          MIN(n.msl_release_num)                   AS min_msl,
          MAX(n.msl_release_num)                   AS max_msl,
          MIN(n.taxnode_id)                        AS min_taxnode_id,
          MAX(n.taxnode_id)                        AS max_taxnode_id
      FROM taxonomy_node AS n
      GROUP BY n.level_id, n.ictv_id, n.name
  ) AS prev_range
    ON prev_range.level_id = src.level_id
   AND prev_range.name     = src.name

  /* latest row of that slice */
  JOIN taxonomy_node AS pc
    ON pc.taxnode_id = prev_range.max_taxnode_id

  /* ----- STEP 3: next_range (later ICTV_ID slice) -------------- */
  LEFT JOIN (
      SELECT
          n.level_id,
          n.name,
          n.ictv_id,
          MIN(n.msl_release_num)                   AS min_msl,
          MAX(n.msl_release_num)                   AS max_msl,
          MIN(n.taxnode_id)                        AS min_taxnode_id,
          MAX(n.taxnode_id)                        AS max_taxnode_id
      FROM taxonomy_node AS n
      GROUP BY n.level_id, n.ictv_id, n.name
  ) AS next_range
    ON next_range.level_id = src.level_id
   AND next_range.name     = src.name

  LEFT JOIN taxonomy_node AS nc
    ON nc.taxnode_id = next_range.min_taxnode_id

  /* ----- only gaps (prev.max < next.min) ----------------------- */
  WHERE prev_range.max_msl < next_range.min_msl

) AS pairs

/* ---------------------------------------------------------------
   Filters identical to SQL Server version
--------------------------------------------------------------- */
WHERE pairs.qc_mesg LIKE p_filter
  AND pairs.name    LIKE IFNULL(p_target_name, pairs.name)

ORDER BY
  pairs.name,
  pairs.p_min_msl, pairs.p_max_msl,
  pairs.n_min_msl, pairs.n_max_msl;

END //

DELIMITER ;
