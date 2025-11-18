DROP VIEW IF EXISTS `species_latest`;

CREATE VIEW `species_latest` AS
/*
 * Most recent MSL, with data pulled from earlier ones
 * This query may take significant time to run.
 */

SELECT 
    tn.taxnode_id AS taxnode_id,
    tn.msl_release_num AS msl_release_num,
    tn.name AS name,
    tn.rank AS `rank`,
    -- molecule_type
    tn.molecule AS molecule,
    
    -- genome_coverage
    (SELECT genome_coverage
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.genome_coverage IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS genome_coverage,
    
    (SELECT msl_release_num
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.genome_coverage IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS genome_coverage_msl,
    
    -- host_source
    (SELECT host_source
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.host_source IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS host_source,
    
    (SELECT msl_release_num
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.host_source IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS host_source_msl,
    
    -- exemplar_name
    (SELECT exemplar_name
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.exemplar_name IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS exemplar_name,
    
    (SELECT msl_release_num
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.exemplar_name IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS exemplar_name_msl,
    
    -- abbrev_csv
    (SELECT abbrev_csv
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.abbrev_csv IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS abbrev_csv,
    
    (SELECT msl_release_num
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.abbrev_csv IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS abbrev_csv_msl,
    
    -- isolate_csv
    (SELECT isolate_csv
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.isolate_csv IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS isolate_csv,
    
    (SELECT msl_release_num
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.isolate_csv IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS isolate_csv_msl,
    
    -- genbank_accession_csv
    (SELECT genbank_accession_csv
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.genbank_accession_csv IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS genbank_accession_csv,
    
    (SELECT msl_release_num
     FROM taxonomy_node prev 
     WHERE prev.ictv_id = tn.ictv_id
     AND prev.genbank_accession_csv IS NOT NULL
     ORDER BY prev.msl_release_num DESC
     LIMIT 1) AS genbank_accession_csv_msl
     
FROM taxonomy_node_names tn
WHERE tn.msl_release_num = (SELECT MAX(msl_release_num) FROM taxonomy_toc)
AND `rank` = 'species';
