CREATE OR REPLACE VIEW `vmr_export` AS
SELECT
    si.isolate_id                                             AS `isolate_id`,
    CONCAT('ICTV', si.isolate_id)                             AS `Isolate ID`,
    si.species_sort                                           AS `Species Sort`,
    si.isolate_sort                                           AS `Isolate Sort`,
    tn.realm                                                  AS `Realm`,
    tn.subrealm                                               AS `Subrealm`,
    tn.kingdom                                                AS `Kingdom`,
    tn.subkingdom                                             AS `Subkingdom`,
    tn.phylum                                                 AS `Phylum`,
    tn.subphylum                                              AS `Subphylum`,
    tn.class                                                  AS `Class`,
    tn.subclass                                               AS `Subclass`,
    tn.`order`                                                AS `Order`,
    tn.suborder                                               AS `Suborder`,
    tn.family                                                 AS `Family`,
    tn.subfamily                                              AS `Subfamily`,
    tn.genus                                                  AS `Genus`,
    tn.subgenus                                               AS `Subgenus`,

    -- Species, as an Excel hyperlink to taxon history
    CONCAT(
      '=HYPERLINK("https://ictv.global/taxonomy/taxondetails?taxnode_id=',
      tn.taxnode_id, '","',
      REPLACE(IFNULL(tn.species,''), '"', '""'),
      '")'
    )                                                         AS `Species`,

    IFNULL(si.isolate_type, '')                               AS `Exemplar or additional isolate`,
    IFNULL(si.isolate_names, '')                              AS `Virus name(s)`,
    IFNULL(si.isolate_abbrevs, '')                            AS `Virus name abbreviation(s)`,
    IFNULL(si.isolate_designation, '')                        AS `Virus isolate designation`,
    IFNULL(si.genbank_accessions, '')                         AS `Virus GENBANK accession`,
    -- IFNULL(si.refseq_accessions, '')                        AS `Virus REFSEQ accession`,
    -- IFNULL(si.refseq_taxids, '')                            AS `Virus REFSEQ NCBI taxid`,
    IFNULL(si.genome_coverage, '')                            AS `Genome coverage`,
    IFNULL(si.molecule, '')                                   AS `Genome`,
    IFNULL(si.host_source, '')                                AS `Host source`,

    CASE
      WHEN IFNULL(si.genbank_accessions,'') <> '' THEN
        CONCAT(
          '=HYPERLINK("https://www.ncbi.nlm.nih.gov/nuccore/',
          VMR_accessionsStripPrefixesAndConvertToCSV(si.genbank_accessions),
          '","NCBI Nucleotide")'
        )
      ELSE ''
    END                                                       AS `Accessions Link`,

    IFNULL(si.notes, '')                                      AS `Editor Notes`,

    -- QC
    CASE
      WHEN si.molecule <> tn.inher_molecule THEN 'ERROR:molecule '
      ELSE ''
    END                                                       AS `QC_status`,
    tn.inher_molecule                                         AS `QC_taxon_inher_molecule`,
    IFNULL(si.update_change,'')                               AS `QC_taxon_change`,
    IFNULL(
      CONCAT(
        '=HYPERLINK("https://ictv.global/ictv/proposals/',
        IFNULL(si.update_change_proposal,''),
        '","',
        REPLACE(IFNULL(si.update_change_proposal,''), '"', '""'),
        '")'
      ),
      ''
    )                                                         AS `QC_taxon_proposal`

FROM `species_isolates` AS si
JOIN `taxonomy_node_names` AS tn
  ON tn.taxnode_id = si.taxnode_id
WHERE tn.species <> 'abolished';
