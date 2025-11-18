DELIMITER $$

DROP PROCEDURE IF EXISTS MSL_export_fast $$

CREATE PROCEDURE MSL_export_fast(IN msl_or_tree INT, IN taxnode_id INT)
BEGIN
    -- Declare variables
    DECLARE msl INT;
    DECLARE tree_id INT;
    DECLARE notes TEXT;

    -- Handle default values for input parameters
    -- Since default parameter values are not supported directly in MariaDB stored procedures,
    -- we need to handle NULL values within the procedure.

    -- Determine the target tree_id and msl_release_num
    SELECT toc.tree_id, toc.msl_release_num, toc.notes INTO tree_id, msl, notes
    FROM taxonomy_toc toc
    WHERE msl_or_tree IS NULL OR toc.msl_release_num = msl_or_tree OR toc.tree_id = msl_or_tree
    ORDER BY toc.msl_release_num DESC
    LIMIT 1;

    -- Output TARGET MSL and TREE information
    SELECT CONCAT('TARGET MSL: ', msl) AS target_msl, CONCAT('TARGET TREE: ', tree_id) AS target_tree;

    -- Output warning and advice messages
    SELECT 'THIS EXPORT DOES NOT PULL HISTORY INFO, and GENOME_MOLECULE is ONLY FROM CUR MSL, NO FALLBACK TO OLDER MSLs IF THERE IS MISSING INFO' AS WARNING;
    SELECT 'FOR FULL EXPORT USE:' AS ADVICE, 'exec MSL_export_official' AS `SQL`;

    -- Version info
    SELECT 
        'version info:' AS PASTE_TEXT_FOR_VERSION_WORKSHEET,
        CONCAT('ICTV ', LEFT(RTRIM(tree_id), 4), ' Master Species List (MSL', RTRIM(msl), ')') AS cell_2B,
        'update today''s date!' AS cell_5C,
        CONCAT('New MSL including all taxa updates since the ', (SELECT name FROM taxonomy_node WHERE level_id = 100 AND msl_release_num = (msl - 1)), ' release') AS cell_6E,
        CONCAT('Updates approved during ', CAST(notes AS CHAR)) AS cell_7F,
        CONCAT('and ratified by the ICTV membership in ', LEFT(RTRIM(tree_id + 10000), 4)) AS cell_8F,
        CONCAT('ICTV', LEFT(RTRIM(tree_id), 4), ' Master Species List#', RTRIM(msl)) AS taxa_tab_name
    FROM taxonomy_node
    WHERE level_id = 100
      AND msl_release_num = msl;

    -- Molecule stats
    SELECT 'molecule stats' AS REPORT, m.*, 
        (SELECT COUNT(n.taxnode_id) FROM taxonomy_node n WHERE n.inher_molecule_id = m.id AND n.tree_id = tree_id) AS `usage`
    FROM taxonomy_molecule m
    ORDER BY id;

    -- Rank stats
    SELECT 'rank stats' AS REPORT, l.*, 
        (SELECT COUNT(n.taxnode_id) FROM taxonomy_node n WHERE n.level_id = l.id AND n.tree_id = tree_id) AS `usage`
    FROM taxonomy_level l
    ORDER BY id;

    -- Main data query
    SELECT
        ROW_NUMBER() OVER(ORDER BY tn.left_idx ASC) AS `sort`,
        IFNULL(`realm`.name, '') AS `realm`,
        IFNULL(`subrealm`.name, '') AS `subrealm`,
        IFNULL(`kingdom`.name, '') AS `kingdom`,
        IFNULL(`subkingdom`.name, '') AS `subkingdom`,
        IFNULL(`phylum`.name, '') AS `phylum`,
        IFNULL(`subphylum`.name, '') AS `subphylum`,
        IFNULL(`class`.name, '') AS `class`,
        IFNULL(`subclass`.name, '') AS `subclass`,
        IFNULL(`order`.name, '') AS `order`,
        IFNULL(`suborder`.name, '') AS `suborder`,
        IFNULL(`family`.name, '') AS `family`,
        IFNULL(`subfamily`.name, '') AS `subfamily`,
        IFNULL(`genus`.name, '') AS `genus`,
        IFNULL(`subgenus`.name, '') AS `subgenus`,
        IFNULL(`species`.name, '') AS `species`,
        -- Molecule info
        IFNULL((
            SELECT mol.abbrev
            FROM taxonomy_molecule mol
            WHERE mol.id = tn.inher_molecule_id
            LIMIT 1
        ), '') AS molecule,
        -- Last change info
        'exec MSL_export_official' AS last_change,
        'exec MSL_export_official' AS last_change_msl,
        'exec MSL_export_official' AS last_change_proposal,
        -- History URL
        CONCAT('=HYPERLINK("https://ictv.global/taxonomy/taxondetails?taxnode_id=', RTRIM(tn.taxnode_id), '","ictv.global=', RTRIM(tn.taxnode_id), '")') AS history_url
    FROM taxonomy_node tn
    LEFT JOIN taxonomy_node `tree` ON `tree`.taxnode_id = tn.tree_id
    LEFT JOIN taxonomy_node `realm` ON `realm`.taxnode_id = tn.realm_id
    LEFT JOIN taxonomy_node `subrealm` ON `subrealm`.taxnode_id = tn.subrealm_id
    LEFT JOIN taxonomy_node `kingdom` ON `kingdom`.taxnode_id = tn.kingdom_id
    LEFT JOIN taxonomy_node `subkingdom` ON `subkingdom`.taxnode_id = tn.subkingdom_id
    LEFT JOIN taxonomy_node `phylum` ON `phylum`.taxnode_id = tn.phylum_id
    LEFT JOIN taxonomy_node `subphylum` ON `subphylum`.taxnode_id = tn.subphylum_id
    LEFT JOIN taxonomy_node `class` ON `class`.taxnode_id = tn.class_id
    LEFT JOIN taxonomy_node `subclass` ON `subclass`.taxnode_id = tn.subclass_id
    LEFT JOIN taxonomy_node `order` ON `order`.taxnode_id = tn.order_id
    LEFT JOIN taxonomy_node `suborder` ON `suborder`.taxnode_id = tn.suborder_id
    LEFT JOIN taxonomy_node `family` ON `family`.taxnode_id = tn.family_id
    LEFT JOIN taxonomy_node `subfamily` ON `subfamily`.taxnode_id = tn.subfamily_id
    LEFT JOIN taxonomy_node `genus` ON `genus`.taxnode_id = tn.genus_id
    LEFT JOIN taxonomy_node `subgenus` ON `subgenus`.taxnode_id = tn.subgenus_id
    LEFT JOIN taxonomy_node `species` ON `species`.taxnode_id = tn.species_id
    WHERE tn.is_deleted = 0 AND tn.is_hidden = 0 AND tn.is_obsolete = 0
      AND tn.tree_id = tree_id
      AND tn.level_id = 600 /* species */
      -- limit to a specific taxon, if specified
      AND (taxnode_id IS NULL OR tn.taxnode_id = taxnode_id)
    ORDER BY tn.left_idx;

END $$

DELIMITER ;