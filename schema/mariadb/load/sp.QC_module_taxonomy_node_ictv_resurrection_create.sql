DELIMITER $$

DROP PROCEDURE IF EXISTS QC_module_taxonomy_node_ictv_resurrection $$
CREATE PROCEDURE QC_module_taxonomy_node_ictv_resurrection(
    IN  p_filter      VARCHAR(1000),   -- pass NULL to use default 'ERROR%'
    IN  p_target_name VARCHAR(100)     -- optional name filter
)
BEGIN
    -- default like the SQL Server version
    IF p_filter IS NULL THEN
        SET p_filter := 'ERROR%';
    END IF;

    /* Inner: compute all fields + link_ct (but NOT qc_mesg) */
    SELECT
      'QC_module_taxonomy_node_ictv_resurrection' AS qc_module,
      '[taxonomy_node]'                            AS table_name,
      pairs_core.*,
      /* Build qc_mesg in the OUTER level using the already-computed aliases */
      CONCAT_WS(
        '',
        CASE
          WHEN pairs_core.p_name COLLATE utf8mb4_bin = pairs_core.n_name COLLATE utf8mb4_bin
            THEN ''
          ELSE 'WARNING: CASE; '
        END,
        CASE
          WHEN pairs_core.link_ct = 0
            THEN 'ERROR: NOT LINKED;'
          WHEN pairs_core.link_ct = 1
           AND pairs_core.p_out_change = 'abolish'
           AND pairs_core.n_in_change  = 'new'
            THEN 'OK: linked new:abolish/new:...'
          WHEN pairs_core.link_ct = 1
            THEN CONCAT(
                   'WARNING: linked, but ',
                   IFNULL(pairs_core.p_out_change,'NULL'), ':',
                   IFNULL(pairs_core.n_in_change,'NULL')
                 )
          WHEN pairs_core.link_ct > 1
            THEN 'ERROR: link_ct > 1'
          ELSE 'ERROR: unknown'
        END
      ) AS qc_mesg
    FROM (
      /* ---------- Build the “pairs_core” rows (no references to pairs_core inside) ---------- */
      SELECT
          -- base identity
          src.level_id,
          src.name,
          src.ictv_ct,

          -- previous (p_*) range + row at end of previous span
          prev_range.ictv_id        AS p_ictv_id,
          prev_range.min_msl        AS p_min_msl,
          prev_range.max_msl        AS p_max_msl,
          prev_range.min_taxnode_id AS p_min_taxnode_id,
          prev_range.max_taxnode_id AS p_max_taxnode_id,
          pc.name                   AS p_name,
          pc.out_change             AS p_out_change,

          -- gap/adjacency indicator (optional, kept from T-SQL)
          CASE
            WHEN prev_range.max_msl = next_range.min_msl + 1 THEN '>>ADJ>>'
            ELSE '>>GAP>>'
          END                       AS s2,

          -- a little context from deltas at the start of the next span (fixed to 1 column)
          (
            SELECT CONCAT(
                     COUNT(*), ':',
                     IFNULL(MAX(CONCAT(d.tag_csv2, IFNULL(CONCAT(':', d.proposal), ''))), '')
                   )
            FROM taxonomy_node_delta d
            WHERE d.new_taxid = next_range.min_taxnode_id
          ) AS prevDELTAs,

          -- next (n_*) range + row at start of next span
          next_range.ictv_id        AS n_ictv_id,
          next_range.min_msl        AS n_min_msl,
          next_range.max_msl        AS n_max_msl,
          next_range.min_taxnode_id AS n_min_taxnode_id,
          next_range.max_taxnode_id AS n_max_taxnode_id,
          nc.name                   AS n_name,
          nc.in_change              AS n_in_change,

          -- link count between prev and next ictv_id (central to QC)
          (
            SELECT COUNT(*)
            FROM taxonomy_node_merge_split ms
            WHERE ms.prev_ictv_id = prev_range.ictv_id
              AND ms.next_ictv_id = next_range.ictv_id
          ) AS link_ct

      FROM (
          -- names (by level) that appear with >1 distinct ictv_id
          SELECT
              n.level_id,
              n.name,
              COUNT(DISTINCT n.ictv_id) AS ictv_ct
          FROM taxonomy_node AS n
          WHERE n.name = IFNULL(p_target_name, n.name)
            AND n.name <> 'Unnamed genus'
          GROUP BY n.level_id, n.name
          HAVING COUNT(DISTINCT n.ictv_id) > 1
      ) AS src

      -- previous span for that (level_id, name)
      JOIN (
          SELECT
              n.level_id, n.name, n.ictv_id,
              MIN(n.msl_release_num) AS min_msl,
              MAX(n.msl_release_num) AS max_msl,
              MIN(n.taxnode_id)      AS min_taxnode_id,
              MAX(n.taxnode_id)      AS max_taxnode_id
          FROM taxonomy_node AS n
          GROUP BY n.level_id, n.ictv_id, n.name
      ) AS prev_range
        ON prev_range.level_id = src.level_id
       AND prev_range.name     = src.name

      JOIN taxonomy_node AS pc
        ON pc.taxnode_id = prev_range.max_taxnode_id

      -- next span (same name/level, different ictv_id expected)
      LEFT JOIN (
          SELECT
              n.level_id, n.name, n.ictv_id,
              MIN(n.msl_release_num) AS min_msl,
              MAX(n.msl_release_num) AS max_msl,
              MIN(n.taxnode_id)      AS min_taxnode_id,
              MAX(n.taxnode_id)      AS max_taxnode_id
          FROM taxonomy_node AS n
          GROUP BY n.level_id, n.ictv_id, n.name
      ) AS next_range
        ON next_range.level_id = src.level_id
       AND next_range.name     = src.name

      LEFT JOIN taxonomy_node AS nc
        ON nc.taxnode_id = next_range.min_taxnode_id

      -- only keep cases with a true gap between spans
      WHERE prev_range.max_msl < next_range.min_msl
    ) AS pairs_core
    HAVING qc_mesg LIKE p_filter
       AND pairs_core.name LIKE IFNULL(p_target_name, pairs_core.name)
    ORDER BY
      pairs_core.name,
      pairs_core.p_min_msl, pairs_core.p_max_msl,
      pairs_core.n_min_msl, pairs_core.n_max_msl;

END $$
DELIMITER ;