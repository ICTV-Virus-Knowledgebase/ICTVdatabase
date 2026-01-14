DELIMITER $$

DROP PROCEDURE IF EXISTS MSL_export_fast $$

CREATE PROCEDURE MSL_export_fast(
    IN p_msl_or_tree INT,
    IN p_taxnode_id INT,
    IN p_server VARCHAR(200)
)
BEGIN
    DECLARE v_msl INT;
    DECLARE v_tree_id INT;

    -- -----------------------------------------------------------------------
    -- Defaults
    -- -----------------------------------------------------------------------
    IF p_server IS NULL OR p_server = '' THEN
        SET p_server := 'ictv.global';
    END IF;

    -- -----------------------------------------------------------------------
    -- Warning/advice headers
    -- -----------------------------------------------------------------------
    SELECT
      'THIS EXPORT DOES NOT PULL HISTORY INFO, and GENOME_MOLECULE is ONLY FROM CUR MSL, NO FALLBACK TO OLDER MSLs IF THERE IS MISSING INFO'
      AS WARNING;

	SELECT
	  'FOR FULL EXPORT USE:' AS advice,
	  'CALL MSL_export_official' AS advice_sql;

    -- -----------------------------------------------------------------------
    -- Determine target MSL + tree_id
    -- SQL Server version: ORDER BY msl_release_num (ascending)
    -- -----------------------------------------------------------------------
    SELECT t.tree_id, t.msl_release_num
      INTO v_tree_id, v_msl
    FROM taxonomy_toc AS t
    WHERE (p_msl_or_tree IS NULL
           OR t.msl_release_num = p_msl_or_tree
           OR t.tree_id = p_msl_or_tree)
    ORDER BY t.msl_release_num DESC
    LIMIT 1;

    -- -----------------------------------------------------------------------
    -- Debug output (PRINT replacement)
    -- -----------------------------------------------------------------------
    SELECT CONCAT('TARGET MSL: ', v_msl) AS target_msl,
           CONCAT('TARGET TREE: ', v_tree_id) AS target_tree;

    -- Optional: PRINT equivalent
    SELECT CONCAT('TARGET MSL:', RTRIM(v_msl)) AS debug_print;

    -- -----------------------------------------------------------------------
    -- Version worksheet header block
    -- -----------------------------------------------------------------------
    SELECT
        'version info:' AS PASTE_TEXT_FOR_VERSION_WORKSHEET,
        CONCAT(
          'ICTV ',
          LEFT(RTRIM(CAST(tree_id AS CHAR)), 4),
          ' Master Species List (MSL',
          RTRIM(CAST(msl_release_num AS CHAR)),
          ')'
        ) AS cell_2B,
        'update today''s date!' AS cell_5C,
        CONCAT(
          'New MSL including all taxa updates since the ',
          (
            SELECT n2.name
            FROM taxonomy_node AS n2
            WHERE n2.level_id = 100
              AND n2.msl_release_num = (v_msl - 1)
            LIMIT 1
          ),
          ' release'
        ) AS cell_6E,
        CONCAT('Updates approved during ', CAST(notes AS CHAR)) AS cell_7F,
        CONCAT(
          'and ratified by the ICTV membership in ',
          LEFT(RTRIM(CAST(tree_id + 10000 AS CHAR)), 4)
        ) AS cell_8F,
        CONCAT(
          'ICTV',
          LEFT(RTRIM(CAST(tree_id AS CHAR)), 4),
          ' Master Species List#',
          RTRIM(CAST(msl_release_num AS CHAR))
        ) AS taxa_tab_name
    FROM taxonomy_node
    WHERE level_id = 100
      AND msl_release_num = v_msl;

    -- -----------------------------------------------------------------------
    -- Molecule usage stats
    -- -----------------------------------------------------------------------
	SELECT
	    'molecule stats' AS report,
	    m.*,
	    (
	        SELECT COUNT(*)
	        FROM taxonomy_node AS n
	        WHERE n.inher_molecule_id = m.id
	          AND n.tree_id = v_tree_id
	    ) AS usage_count
	FROM taxonomy_molecule AS m
	ORDER BY m.id;

    -- -----------------------------------------------------------------------
    -- Rank usage stats
    -- -----------------------------------------------------------------------
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

    -- -----------------------------------------------------------------------
    -- Main export (one row per species)
    -- -----------------------------------------------------------------------
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

        -- ictv_id_url (Excel formula)
        CONCAT(
          '=HYPERLINK("https://',
          p_server,
          '/taxonomy/taxondetails?taxnode_id=',
          RTRIM(CAST(tn.taxnode_id AS CHAR)),
          '&ictv_id=ICTV',
          RTRIM(CAST(tn.ictv_id AS CHAR)),
          '","ICTV',
          RTRIM(CAST(tn.ictv_id AS CHAR)),
          '")'
        ) AS ictv_id_url,

        -- molecule (current-only: tn.inher_molecule_id)
        IFNULL(
          (
            SELECT mol.abbrev
            FROM taxonomy_molecule AS mol
            WHERE mol.id = tn.inher_molecule_id
            LIMIT 1
          ),
          ''
        ) AS molecule,

        -- placeholders (matches SQL Server fast export)
        'CALL MSL_export_official' AS last_change,
        'CALL MSL_export_official' AS last_change_msl,
        'CALL MSL_export_official' AS last_change_proposal

    FROM taxonomy_node AS tn
    LEFT JOIN taxonomy_node AS tree_node      ON tree_node.taxnode_id       = tn.tree_id
    LEFT JOIN taxonomy_node AS realm_node     ON realm_node.taxnode_id      = tn.realm_id
    LEFT JOIN taxonomy_node AS subrealm_node  ON subrealm_node.taxnode_id   = tn.subrealm_id
    LEFT JOIN taxonomy_node AS kingdom_node   ON kingdom_node.taxnode_id    = tn.kingdom_id
    LEFT JOIN taxonomy_node AS subkingdom_node ON subkingdom_node.taxnode_id = tn.subkingdom_id
    LEFT JOIN taxonomy_node AS phylum_node    ON phylum_node.taxnode_id     = tn.phylum_id
    LEFT JOIN taxonomy_node AS subphylum_node ON subphylum_node.taxnode_id  = tn.subphylum_id
    LEFT JOIN taxonomy_node AS class_node     ON class_node.taxnode_id      = tn.class_id
    LEFT JOIN taxonomy_node AS subclass_node  ON subclass_node.taxnode_id   = tn.subclass_id
    LEFT JOIN taxonomy_node AS order_node     ON order_node.taxnode_id      = tn.order_id
    LEFT JOIN taxonomy_node AS suborder_node  ON suborder_node.taxnode_id   = tn.suborder_id
    LEFT JOIN taxonomy_node AS family_node    ON family_node.taxnode_id     = tn.family_id
    LEFT JOIN taxonomy_node AS subfamily_node ON subfamily_node.taxnode_id  = tn.subfamily_id
    LEFT JOIN taxonomy_node AS genus_node     ON genus_node.taxnode_id      = tn.genus_id
    LEFT JOIN taxonomy_node AS subgenus_node  ON subgenus_node.taxnode_id   = tn.subgenus_id
    LEFT JOIN taxonomy_node AS species_node   ON species_node.taxnode_id    = tn.species_id

    WHERE tn.is_deleted  = 0
      AND tn.is_hidden   = 0
      AND tn.is_obsolete = 0
      AND tn.tree_id     = v_tree_id
      AND tn.level_id    = 600
      AND (p_taxnode_id IS NULL OR tn.taxnode_id = p_taxnode_id)

    ORDER BY tn.left_idx;

END$$

DELIMITER ;