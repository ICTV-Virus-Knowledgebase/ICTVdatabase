-- Drop the view if it already exists
DROP VIEW IF EXISTS `taxonomy_node_names`;

-- Create the view
CREATE VIEW `taxonomy_node_names` AS
SELECT 
    -- the underlying table
    tn.*,
    -- msl shortcut
    tn.`msl_release_num` AS `msl`,
    -- ranks
    COALESCE(`rank`.`name`, '') AS `rank`,
    COALESCE(`tree`.`name`, '') AS `tree`,
    COALESCE(`realm`.`name`, '') AS `realm`,
    COALESCE(`subrealm`.`name`, '') AS `subrealm`,
    COALESCE(`kingdom`.`name`, '') AS `kingdom`,
    COALESCE(`subkingdom`.`name`, '') AS `subkingdom`,
    COALESCE(`phylum`.`name`, '') AS `phylum`,
    COALESCE(`subphylum`.`name`, '') AS `subphylum`,
    COALESCE(`class`.`name`, '') AS `class`,
    COALESCE(`subclass`.`name`, '') AS `subclass`,
    COALESCE(`order`.`name`, '') AS `order`,
    COALESCE(`suborder`.`name`, '') AS `suborder`,
    COALESCE(`family`.`name`, '') AS `family`,
    COALESCE(`subfamily`.`name`, '') AS `subfamily`,
    COALESCE(`genus`.`name`, '') AS `genus`,
    COALESCE(`subgenus`.`name`, '') AS `subgenus`,
    COALESCE(`species`.`name`, '') AS `species`,
    COALESCE(mol.`abbrev`, '') AS `molecule`,
    COALESCE(imol.`abbrev`, '') AS `inher_molecule`,
    COALESCE(gcov.`name`, '') AS `genome_coverage_name`
FROM 
    taxonomy_node tn
-- join all ranks
LEFT OUTER JOIN taxonomy_level `rank` ON `rank`.`id` = tn.`level_id`
LEFT OUTER JOIN taxonomy_node `tree` ON `tree`.`taxnode_id` = tn.`tree_id`
LEFT OUTER JOIN taxonomy_node `realm` ON `realm`.`taxnode_id` = tn.`realm_id`
LEFT OUTER JOIN taxonomy_node `subrealm` ON `subrealm`.`taxnode_id` = tn.`subrealm_id`
LEFT OUTER JOIN taxonomy_node `kingdom` ON `kingdom`.`taxnode_id` = tn.`kingdom_id`
LEFT OUTER JOIN taxonomy_node `subkingdom` ON `subkingdom`.`taxnode_id` = tn.`subkingdom_id`
LEFT OUTER JOIN taxonomy_node `phylum` ON `phylum`.`taxnode_id` = tn.`phylum_id`
LEFT OUTER JOIN taxonomy_node `subphylum` ON `subphylum`.`taxnode_id` = tn.`subphylum_id`
LEFT OUTER JOIN taxonomy_node `class` ON `class`.`taxnode_id` = tn.`class_id`
LEFT OUTER JOIN taxonomy_node `subclass` ON `subclass`.`taxnode_id` = tn.`subclass_id`
LEFT OUTER JOIN taxonomy_node `order` ON `order`.`taxnode_id` = tn.`order_id`
LEFT OUTER JOIN taxonomy_node `suborder` ON `suborder`.`taxnode_id` = tn.`suborder_id`
LEFT OUTER JOIN taxonomy_node `family` ON `family`.`taxnode_id` = tn.`family_id`
LEFT OUTER JOIN taxonomy_node `subfamily` ON `subfamily`.`taxnode_id` = tn.`subfamily_id`
LEFT OUTER JOIN taxonomy_node `genus` ON `genus`.`taxnode_id` = tn.`genus_id`
LEFT OUTER JOIN taxonomy_node `subgenus` ON `subgenus`.`taxnode_id` = tn.`subgenus_id`
LEFT OUTER JOIN taxonomy_node `species` ON `species`.`taxnode_id` = tn.`species_id`
-- other controlled vocabularies
LEFT OUTER JOIN taxonomy_molecule mol ON mol.`id` = tn.`molecule_id`
LEFT OUTER JOIN taxonomy_molecule imol ON imol.`id` = tn.`inher_molecule_id`
LEFT OUTER JOIN taxonomy_genome_coverage gcov ON gcov.`genome_coverage` = tn.`genome_coverage`
-- filter out historical junk
WHERE 
    tn.`is_deleted` = 0 
    AND tn.`is_hidden` = 0 
    AND tn.`is_obsolete` = 0;