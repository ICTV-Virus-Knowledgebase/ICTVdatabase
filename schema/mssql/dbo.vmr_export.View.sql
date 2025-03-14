
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE view [dbo].[vmr_export] as 
--
-- Export VMR to XLSX
--
-- Change Log: 
--   20250224 add 'ICTV' prefix to [Isolate ID] column, add [isolate_id]
--   20241106  commented out REFSEQ values - to expensive to maintain

/*

SELECT * 
FROM [vmr_export]
--ORDER BY [Species Sort], [Isolate Sort]
WHERE QC_status <> ''


*/
SELECT  TOP  1000000
		si.isolate_id
      ,concat('ICTV',si.[isolate_id]) as 'Isolate ID'
	  ,si.[species_sort] as 'Species Sort'
	  ,si.[isolate_sort] as 'Isolate Sort'
	  ,tn.[realm] as 'Realm'
      ,tn.[subrealm] as 'Subrealm'
      ,tn.[kingdom] as 'Kingdom'
      ,tn.[subkingdom] as 'Subkingdom'
      ,tn.[phylum] as 'Phylum'
      ,tn.[subphylum] as 'Subphylum'
      ,tn.[class] as 'Class'
      ,tn.[subclass] as 'Subclass'
      ,tn.[order] as 'Order'
      ,tn.[suborder] as 'Suborder'
      ,tn.[family] as 'Family'
      ,tn.[subfamily] as 'Subfamily'
      ,tn.[genus] as 'Genus'
      ,tn.[subgenus] as 'Subgenus'
	  -- species, with link to history
	  ,concat('=HYPERLINK("https://ictv.global/taxonomy/taxondetails?taxnode_id=',tn.taxnode_id,'","',tn.[species],'")') as 'Species'
      ,CONCAT(si.[isolate_type],'') as 'Exemplar or additional isolate'
      ,CONCAT(si.[isolate_names],'') as 'Virus name(s)'
      ,CONCAT(si.[isolate_abbrevs],'') as 'Virus name abbreviation(s)'
      ,CONCAT(si.[isolate_designation],'') as 'Virus isolate designation'
      ,CONCAT(si.[genbank_accessions],'') as 'Virus GENBANK accession'
     -- ,CONCAT(si.[refseq_accessions],'') as 'Virus REFSEQ accession'
	 -- ,CONCAT(si.[refseq_taxids],'') as 'Virus REFSEQ NCBI taxid'
      ,CONCAT(si.[genome_coverage],'') as 'Genome coverage'
      ,CONCAT(si.[molecule],'') as 'Genome'
      ,CONCAT(si.[host_source],'') as 'Host source'
	  ,(case when genbank_accessions <> '' then
	  CONCAT('=HYPERLINK("https://www.ncbi.nlm.nih.gov/nuccore/',
	--	dbo.VMR_accessionsStripPrefixesAndConvertToCSV(CONCAT(refseq_accessions,';',genbank_accessions)),
		dbo.VMR_accessionsStripPrefixesAndConvertToCSV(genbank_accessions),
		'","NCBI Nucleotide")' ) 
		else '' end ) as 'Accessions Link'
	  -- editor only
	  ,CONCAT(si.[notes],'') as 'Editor Notes'
	   -- QC
	  ,QC_status =
		 (case when  si.molecule <> tn.inher_molecule then 'ERROR:molecule ' else '' end)
		 --(case when  si.genome_coverage <> tn.genome_coverage_name then 'ERROR:genome_coverage ' else '' end)
	  ,QC_taxon_inher_molecule=tn.inher_molecule
	  --,QC_taxon_genome_coverage = tn.genome_coverage_name
	  ,QC_taxon_change = CONCAT(si.update_change,'')
	  ,QC_taxon_proposal = ISNULL('=HYPERLINK("https://ictv.global/ictv/proposals/'+ si.update_change_proposal+'","'+ si.update_change_proposal+'")','')
  -- SELECT * 
  FROM [dbo].[species_isolates] si
  JOIN [dbo].[taxonomy_node_names] tn on tn.taxnode_id = si.taxnode_id
  WHERE species <> 'abolished' -- removes abolished species
  --order by left_idx, sort
  ORDER BY  si.[species_sort] ,si.[isolate_sort] 
 
GO

