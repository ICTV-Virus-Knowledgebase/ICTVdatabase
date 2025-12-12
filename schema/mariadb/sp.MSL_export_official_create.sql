DELIMITER $$

DROP PROCEDURE IF EXISTS MSL_export_official $$

CREATE PROCEDURE MSL_export_official(
    IN p_msl_or_tree INT,
    IN p_taxnode_id INT,
    IN p_server VARCHAR(200)
)
BEGIN
    DECLARE v_msl INT;
    DECLARE v_tree_id INT;

    -- ---------------------------------------------------------------
    -- Default server if not provided (same behavior as SQL Server)
    -- ---------------------------------------------------------------
    IF p_server IS NULL OR p_server = '' THEN
        SET p_server := 'ictv.global';
    END IF;

    -- ---------------------------------------------------------------
    -- Determine target MSL and tree_id
    -- (DESC so NULL p_msl_or_tree gives latest MSL)
    -- ---------------------------------------------------------------
    SELECT t.tree_id, t.msl_release_num
      INTO v_tree_id, v_msl
    FROM taxonomy_toc AS t
    WHERE (p_msl_or_tree IS NULL
           OR t.msl_release_num = p_msl_or_tree
           OR t.tree_id = p_msl_or_tree)
    ORDER BY t.msl_release_num DESC
    LIMIT 1;

    -- ---------------------------------------------------------------
    -- TEMP TABLES: materialize and index history data
    -- ---------------------------------------------------------------

    -- 1) taxonomy_node_dx view → tmp_dx
    -- taxonomy_node_dx columns:
    --   prev_* , next_*, and t.* (tree_id, level_id, left_idx, right_idx, node_depth, msl_release_num, etc)
    CREATE TEMPORARY TABLE tmp_dx
    ENGINE=InnoDB
    AS
    SELECT
        tree_id,
        level_id,
        left_idx,
        right_idx,
        node_depth,
        msl_release_num,
        prev_tags,
        prev_proposal,
        prev_ictv_id,
        next_ictv_id
    FROM taxonomy_node_dx
    WHERE tree_id <= v_tree_id        -- only trees up to current
      AND level_id > 100              -- matches original conditions
      AND (
            (prev_tags IS NOT NULL AND prev_tags <> '')
         OR (prev_proposal IS NOT NULL AND prev_proposal <> '')
          );

    -- Index shaped for: tree_id + level_id + left/right + node_depth
    ALTER TABLE tmp_dx
      ADD INDEX idx_tmpdx_tree_level_lr
          (tree_id, level_id, left_idx, right_idx, node_depth),
      ADD INDEX idx_tmpdx_next_ictv
          (next_ictv_id),
      ADD INDEX idx_tmpdx_prev_ictv
          (prev_ictv_id);

    -- 2) taxonomy_node_merge_split → tmp_ms
    CREATE TEMPORARY TABLE tmp_ms
    ENGINE=InnoDB
    AS
    SELECT *
    FROM taxonomy_node_merge_split;

    ALTER TABLE tmp_ms
      ADD INDEX idx_tmpms_next (next_ictv_id),
      ADD INDEX idx_tmpms_prev (prev_ictv_id);

    -- ---------------------------------------------------------------
    -- Debug-style header
    -- ---------------------------------------------------------------
    SELECT CONCAT('TARGET MSL: ', v_msl) AS target_msl,
           CONCAT('TARGET TREE: ', v_tree_id) AS target_tree;

    -- ---------------------------------------------------------------
    -- Version worksheet header block
    -- ---------------------------------------------------------------
    SELECT
        'version info:' AS PASTE_TEXT_FOR_VERSION_WORKSHEET,
        CONCAT(
            'ICTV ',
            SUBSTRING(CAST(tree_id AS CHAR),1,4),
            ' Master Species List (MSL',
            msl_release_num,
            ')'
        ) AS cell_2B,
        'update today''s date!' AS cell_5C,
        CONCAT(
            'New MSL including all taxa updates since the ',
            (SELECT n2.name
               FROM taxonomy_node AS n2
              WHERE n2.level_id = 100
                AND n2.msl_release_num = v_msl - 1
              LIMIT 1),
            ' release'
        ) AS cell_6E,
        CONCAT('Updates approved during ', notes) AS cell_7F,
        CONCAT(
            'and ratified by the ICTV membership in ',
            SUBSTRING(CAST(tree_id + 10000 AS CHAR),1,4)
        ) AS cell_8F,
        CONCAT(
            'ICTV',
            SUBSTRING(CAST(tree_id AS CHAR),1,4),
            ' Master Species List#',
            msl_release_num
        ) AS taxa_tab_name
    FROM taxonomy_node
    WHERE level_id = 100
      AND msl_release_num = v_msl;

    -- ---------------------------------------------------------------
    -- Molecule usage stats
    -- ---------------------------------------------------------------
    SELECT
        'molecule stats' AS REPORT,
        m.*,
        (
            SELECT COUNT(n.taxnode_id)
            FROM taxonomy_node AS n
            WHERE n.inher_molecule_id = m.id
              AND n.tree_id = v_tree_id
        ) AS usage_count
    FROM taxonomy_molecule AS m
    ORDER BY m.id;

    -- ---------------------------------------------------------------
    -- Rank usage stats
    -- ---------------------------------------------------------------
    SELECT
        'rank stats' AS REPORT,
        l.*,
        (
            SELECT COUNT(n.taxnode_id)
            FROM taxonomy_node AS n
            WHERE n.level_id = l.id
              AND n.tree_id = v_tree_id
        ) AS usage_count
    FROM taxonomy_level AS l
    ORDER BY l.id;

    -- ---------------------------------------------------------------
    -- Main MSL export (one row per species)
    -- ---------------------------------------------------------------
    SELECT
        ROW_NUMBER() OVER (ORDER BY tn.left_idx ASC) AS sort,

        IFNULL(realm_node.name,     '') AS realm,
        IFNULL(subrealm_node.name,  '') AS subrealm,
        IFNULL(kingdom_node.name,   '') AS kingdom,
        IFNULL(subkingdom_node.name,'') AS subkingdom,
        IFNULL(phylum_node.name,    '') AS phylum,
        IFNULL(subphylum_node.name, '') AS subphylum,
        IFNULL(class_node.name,     '') AS class,
        IFNULL(subclass_node.name,  '') AS subclass,
        IFNULL(order_node.name,     '') AS `order`,
        IFNULL(suborder_node.name,  '') AS suborder,
        IFNULL(family_node.name,    '') AS family,
        IFNULL(subfamily_node.name, '') AS subfamily,
        IFNULL(genus_node.name,     '') AS genus,
        IFNULL(subgenus_node.name,  '') AS subgenus,
        IFNULL(species_node.name,   '') AS species,

        -- history_url = Excel HYPERLINK formula with ICTV ID
        CONCAT(
            '=HYPERLINK("https://',
            p_server,
            '/taxonomy/taxondetails?taxnode_id=',
            tn.taxnode_id,
            '&ictv_id=ICTV',
            tn.ictv_id,
            '","ICTV',
            tn.ictv_id,
            '")'
        ) AS history_url,

        -- --------------------------------------------------------------
        -- molecule: most recent molecule type designation
        -- (uses tmp_ms instead of taxonomy_node_merge_split)
        -- --------------------------------------------------------------
        IFNULL(
          (
            SELECT mol.abbrev
            FROM tmp_ms AS tms
            JOIN taxonomy_node AS t
              ON t.ictv_id = tms.prev_ictv_id
             AND t.tree_id <= tn.tree_id
            JOIN taxonomy_node AS tancestor
              ON tancestor.left_idx  <= t.left_idx
             AND tancestor.right_idx >= t.right_idx
             AND tancestor.tree_id   = t.tree_id
             AND tancestor.level_id  > 100
            JOIN taxonomy_molecule AS mol
              ON mol.id = tancestor.inher_molecule_id
            WHERE tms.next_ictv_id = tn.ictv_id
              AND mol.abbrev IS NOT NULL
            ORDER BY (tn.tree_id - tancestor.tree_id), tancestor.node_depth DESC
            LIMIT 1
          ),
          ''
        ) AS molecule,

        -- --------------------------------------------------------------
        -- last_change: most recent prev_tags for node/ancestors
        -- (uses tmp_ms + tmp_dx)
        -- --------------------------------------------------------------
        (
          SELECT dx.prev_tags
          FROM tmp_ms AS tms
          JOIN taxonomy_node AS t
            ON t.ictv_id = tms.prev_ictv_id
           AND t.tree_id <= tn.tree_id
          JOIN tmp_dx AS dx
            ON dx.left_idx  <= t.left_idx
           AND dx.right_idx >= t.right_idx
           AND dx.tree_id   = t.tree_id
           AND dx.level_id  > 100
           AND dx.prev_tags IS NOT NULL
           AND dx.prev_tags <> ''
          WHERE tms.next_ictv_id = tn.ictv_id
          ORDER BY (tn.tree_id - dx.tree_id), dx.node_depth DESC
          LIMIT 1
        ) AS last_change,

        -- --------------------------------------------------------------
        -- last_change_msl: MSL of most recent change tag
        -- ----------------------------------------------------------------
        (
          SELECT dx.msl_release_num
          FROM tmp_ms AS tms
          JOIN taxonomy_node AS t
            ON t.ictv_id = tms.prev_ictv_id
           AND t.tree_id <= tn.tree_id
          JOIN tmp_dx AS dx
            ON dx.left_idx  <= t.left_idx
           AND dx.right_idx >= t.right_idx
           AND dx.tree_id   = t.tree_id
           AND dx.level_id  > 100
           AND dx.prev_tags IS NOT NULL
           AND dx.prev_tags <> ''
          WHERE tms.next_ictv_id = tn.ictv_id
          ORDER BY (tn.tree_id - dx.tree_id), dx.node_depth DESC
          LIMIT 1
        ) AS last_change_msl,

        -- --------------------------------------------------------------
        -- last_change_proposal: hyperlink to most recent proposal
        -- (uses tmp_ms + tmp_dx)
        -- --------------------------------------------------------------
        IFNULL(
          (
            SELECT
              CONCAT(
                '=HYPERLINK("https://',
                p_server,
                '/ictv/proposals/',
                SUBSTRING_INDEX(dx.prev_proposal, ';', -1),
                '","',
                SUBSTRING_INDEX(dx.prev_proposal, ';', -1),
                '")'
              ) AS prev_proposal
            FROM tmp_ms AS tms
            JOIN taxonomy_node AS t
              ON t.ictv_id = tms.prev_ictv_id
             AND t.tree_id <= tn.tree_id
            JOIN tmp_dx AS dx
              ON dx.left_idx  <= t.left_idx
             AND dx.right_idx >= t.right_idx
             AND dx.tree_id   = t.tree_id
             AND dx.level_id  > 100
             AND dx.prev_tags IS NOT NULL
             AND dx.prev_tags <> ''
            WHERE tms.next_ictv_id = tn.ictv_id
              AND dx.prev_proposal IS NOT NULL
              AND dx.prev_proposal <> ''
              AND dx.tree_id = (
                SELECT dx2.tree_id
                FROM tmp_ms AS tms2
                JOIN taxonomy_node AS t2
                  ON t2.ictv_id = tms2.prev_ictv_id
                 AND t2.tree_id <= tn.tree_id
                JOIN tmp_dx AS dx2
                  ON dx2.left_idx  <= t2.left_idx
                 AND dx2.right_idx >= t2.right_idx
                 AND dx2.tree_id   = t2.tree_id
                 AND dx2.level_id  > 100
                 AND dx2.prev_tags IS NOT NULL
                 AND dx2.prev_tags <> ''
                WHERE tms2.next_ictv_id = tn.ictv_id
                ORDER BY (tn.tree_id - dx2.tree_id), dx2.node_depth DESC
                LIMIT 1
              )
            ORDER BY (tn.tree_id - dx.tree_id), dx.node_depth DESC
            LIMIT 1
          ),
          ''
        ) AS last_change_proposal

    FROM taxonomy_node AS tn
    LEFT JOIN taxonomy_node AS tree_node      ON tree_node.taxnode_id      = tn.tree_id
    LEFT JOIN taxonomy_node AS realm_node     ON realm_node.taxnode_id     = tn.realm_id
    LEFT JOIN taxonomy_node AS subrealm_node  ON subrealm_node.taxnode_id  = tn.subrealm_id
    LEFT JOIN taxonomy_node AS kingdom_node   ON kingdom_node.taxnode_id   = tn.kingdom_id
    LEFT JOIN taxonomy_node AS subkingdom_node
                                             ON subkingdom_node.taxnode_id = tn.subkingdom_id
    LEFT JOIN taxonomy_node AS phylum_node    ON phylum_node.taxnode_id    = tn.phylum_id
    LEFT JOIN taxonomy_node AS subphylum_node ON subphylum_node.taxnode_id = tn.subphylum_id
    LEFT JOIN taxonomy_node AS class_node     ON class_node.taxnode_id     = tn.class_id
    LEFT JOIN taxonomy_node AS subclass_node  ON subclass_node.taxnode_id  = tn.subclass_id
    LEFT JOIN taxonomy_node AS order_node     ON order_node.taxnode_id     = tn.order_id
    LEFT JOIN taxonomy_node AS suborder_node  ON suborder_node.taxnode_id  = tn.suborder_id
    LEFT JOIN taxonomy_node AS family_node    ON family_node.taxnode_id    = tn.family_id
    LEFT JOIN taxonomy_node AS subfamily_node ON subfamily_node.taxnode_id = tn.subfamily_id
    LEFT JOIN taxonomy_node AS genus_node     ON genus_node.taxnode_id     = tn.genus_id
    LEFT JOIN taxonomy_node AS subgenus_node  ON subgenus_node.taxnode_id  = tn.subgenus_id
    LEFT JOIN taxonomy_node AS species_node   ON species_node.taxnode_id   = tn.species_id
    WHERE tn.is_deleted  = 0
      AND tn.is_hidden   = 0
      AND tn.is_obsolete = 0
      AND tn.tree_id     = v_tree_id
      AND tn.level_id    = 600  -- species
      AND (p_taxnode_id IS NULL OR tn.taxnode_id = p_taxnode_id)
    ORDER BY tn.left_idx;

END$$

DELIMITER ;