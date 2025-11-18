-- Drop view if exists
DROP VIEW IF EXISTS `MSL_export_fast`;

CREATE VIEW `MSL_export_fast` AS
SELECT 
    -- Basic MSL - one line per species
    -- tn.tree_id, tn.msl_release_num, tn.left_idx, tn.taxnode_id, tn.ictv_id -- debugging
    tn.left_idx,
    
    -- Ranks
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
    tn.is_ref AS is_type_species,
    
    -- Inherited molecule
    IFNULL(imol.abbrev, '') AS inher_molecule,
    
    -- Molecule source
    (SELECT `rank` FROM taxonomy_node_names tns 
     WHERE tns.tree_id = tn.tree_id 
       AND tn.left_idx BETWEEN tns.left_idx AND tns.right_idx 
       AND tns.molecule_id = tn.inher_molecule_id 
     ORDER BY tns.node_depth DESC LIMIT 1) AS inher_molecule_src,

    -- Last change
    IFNULL((SELECT tag_csv FROM taxonomy_node_delta WHERE new_taxid = tn.taxnode_id LIMIT 1), '') AS last_change,

    -- Last change MSL
    CASE 
        WHEN (SELECT tag_csv FROM taxonomy_node_delta WHERE new_taxid = tn.taxnode_id LIMIT 1) <> '' 
        THEN RTRIM(tn.msl_release_num)
        ELSE ''
    END AS last_change_msl,

    -- Last change proposal
    IFNULL((SELECT proposal FROM taxonomy_node_delta WHERE new_taxid = tn.taxnode_id LIMIT 1), '') AS last_change_proposal,

    -- History URL
    CONCAT('=HYPERLINK("http://ictvonline.org/taxonomy/p/taxonomy-history?taxnode_id=', RTRIM(tn.taxnode_id), '","ICTVonline=', RTRIM(tn.taxnode_id), '")') AS history_url,

    -- FYI columns
    IFNULL(tn.abbrev_csv, '') AS FYI_last_abbrev,
    IFNULL(tn.genbank_accession_csv, '') AS last_ncbi,
    IFNULL(tn.isolate_csv, '') AS last_isolates,

    -- Tree and MSL for joining
    tn.tree_id,
    tn.msl_release_num

FROM taxonomy_node tn

-- Join all ranks
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
LEFT JOIN taxonomy_molecule mol ON mol.id = tn.molecule_id
LEFT JOIN taxonomy_molecule imol ON imol.id = tn.inher_molecule_id

WHERE tn.is_deleted = 0 
  AND tn.is_hidden = 0 
  AND tn.is_obsolete = 0
  AND tn.level_id = 600;  /* species */
