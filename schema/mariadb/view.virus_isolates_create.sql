DROP VIEW IF EXISTS `virus_isolates`;

CREATE VIEW `virus_isolates` AS
SELECT 
    si.species_name AS species, 
    si.isolate_type AS exemplar, 
    CASE WHEN isolate_type = 'E' THEN si.isolate_designation END AS exemplar_isolate, 
    CASE WHEN isolate_type = 'E' THEN si.genbank_accessions END AS exemplar_genbank_accession, 
    CASE WHEN isolate_type = 'E' THEN si.refseq_accessions END AS exemplar_refseq_accession, 
    CASE WHEN isolate_type = 'E' THEN si.genome_coverage END AS exemplar_seq_complete, 
    CASE WHEN isolate_type = 'A' THEN si.isolate_designation END AS isolate_csv, 
    CASE WHEN isolate_type = 'A' THEN si.genbank_accessions END AS isolate_genbank_accession_csv, 
    CASE WHEN isolate_type = 'A' THEN si.refseq_accessions END AS isolate_refseq_accession, 
    CASE WHEN isolate_type = 'A' THEN si.genome_coverage END AS isolate_seq_complete_csv, 
    si.isolate_names AS alternative_name_csv, 
    si.isolate_abbrevs AS abbrev_csv, 
    NULL AS isolate_abbrev, 
    si.species_sort AS sort_species, 
    si.isolate_sort AS sort, 
    si.taxnode_id AS taxnode_id, 
    si.host_source AS host, 
    si.molecule AS molecule, 
    tn.realm AS realm, 
    tn.subrealm AS subrealm, 
    tn.kingdom AS kingdom, 
    tn.subkingdom AS subkingdom, 
    tn.phylum AS phylum, 
    tn.subphylum AS subphylum, 
    tn.class AS class, 
    tn.subclass AS subclass, 
    tn.`order` AS `order`, 
    tn.suborder AS suborder, 
    tn.family AS family, 
    tn.subfamily AS subfamily, 
    tn.genus AS genus, 
    tn.subgenus AS subgenus, 
    tn.left_idx AS left_idx, 
    CASE WHEN si.molecule <> tn.inher_molecule THEN 'ERROR:molecule ' ELSE '' END AS qc_status, 
    tn.inher_molecule AS qc_taxon_inher_molecule, 
    si.update_change AS qc_taxon_change, 
    si.update_change_proposal AS qc_taxon_proposal
FROM species_isolates si
JOIN taxonomy_node_names tn ON tn.taxnode_id = si.taxnode_id
WHERE si.species_name <> 'abolished';
