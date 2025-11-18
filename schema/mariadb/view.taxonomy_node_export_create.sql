DROP VIEW IF EXISTS `taxonomy_node_export`;

CREATE VIEW `taxonomy_node_export` AS
-- 
-- Export used by validate_proposals.Rmd load script
-- Should be saved as current_msl/taxonony_node_export.txt
-- As that will have no column headers
-- 
-- export: select * from taxonomy_node_export
SELECT 
    tn.`taxnode_id`,
    tn.`parent_id`,
    tn.`tree_id`,
    tn.`msl_release_num`,
    tn.`level_id`,
    tn.`name`,
    tn.`ictv_id`,
    tn.`molecule_id`,
    tn.`abbrev_csv`,
    tn.`genbank_accession_csv`,
    tn.`genbank_refseq_accession_csv`,
    tn.`refseq_accession_csv`,
    tn.`isolate_csv`,
    REPLACE(tn.`notes`, '\r', '') AS notes, -- DOS newline removal
    tn.`is_ref`,
    tn.`is_official`,
    tn.`is_hidden`,
    tn.`is_deleted`,
    tn.`is_deleted_next_year`,
    tn.`is_typo`,
    tn.`is_renamed_next_year`,
    tn.`is_obsolete`,
    tn.`in_change`,
    tn.`in_target`,
    tn.`in_filename`,
    tn.`in_notes`,
    tn.`out_change`,
    tn.`out_target`,
    tn.`out_filename`,
    tn.`out_notes`,
    tn.`lineage`,
    tn.`cleaned_name`,
    COALESCE(`rank`.`name`, '') AS `rank`, -- Left join rank (taxonomy_level)
    COALESCE(mol.`abbrev`, '') AS `molecule` -- Left join molecule (taxonomy_molecule)
FROM 
    taxonomy_node tn
LEFT OUTER JOIN taxonomy_level `rank` ON `rank`.`id` = tn.`level_id`
LEFT OUTER JOIN taxonomy_molecule mol ON mol.`id` = tn.`molecule_id`
WHERE 
    tn.`msl_release_num` IS NOT NULL
    AND tn.`is_deleted` = 0
    AND (tn.`level_id` = 100 OR tn.`is_hidden` = 0)
    AND tn.`is_obsolete` = 0
ORDER BY 
    tn.`msl_release_num`, 
    tn.`left_idx`;
