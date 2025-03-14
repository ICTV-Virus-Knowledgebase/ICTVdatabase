
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE view [dbo].[species_latest] as
/*
* most recent MSL, with data pulled from earlier ones
*
* this is not a fast query, 
*	select * from species_latest
* can take MANY minutes to run.
*/
select 
	taxnode_id = tn.taxnode_id,
	msl_release_num = tn.msl_release_num,
	name = tn.name,
	[rank] = tn.rank,
	--
	-- molecule_type
	--
	tn.molecule,
	--
	-- genome_coverage 
	--
	genome_coverage = 
		(select top 1 genome_coverage
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.genome_coverage is not null
			order by prev.msl_release_num desc
			),
	genome_coverage_msl = 
		(select top 1 msl_release_num
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.genome_coverage is not null
			order by prev.msl_release_num desc
			),
	--
	-- host_source 
	--
	host_source = 
		(select top 1 host_source
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.host_source is not null
			order by prev.msl_release_num desc
			),	
	host_source_msl = 
		(select top 1 msl_release_num
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.host_source is not null
			order by prev.msl_release_num desc
			),
	--
	-- exemplar_name 
	--
	exemplar_name = 
		(select top 1 exemplar_name
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.exemplar_name is not null
			order by prev.msl_release_num desc
			),	
	exemplar_name_msl = 
		(select top 1 msl_release_num
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.exemplar_name is not null
			order by prev.msl_release_num desc
			),
	--
	-- abbrev_csv 
	--
	abbrev_csv = 
		(select top 1 abbrev_csv
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.abbrev_csv is not null
			order by prev.msl_release_num desc
			),
	abbrev_csv_msl = 
		(select top 1 msl_release_num
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.abbrev_csv is not null
			order by prev.msl_release_num desc
			),
	--
	-- isolate_csv 
	--
	isolate_csv = 
		(select top 1 isolate_csv
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.isolate_csv is not null
			order by prev.msl_release_num desc
			),
	isolate_csv_msl = 
		(select top 1 msl_release_num
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.isolate_csv is not null
			order by prev.msl_release_num desc
			),
	--
	-- genbank_accession_csv 
	--
	genbank_accession_csv = 
		(select top 1 genbank_accession_csv
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.genbank_accession_csv is not null
			order by prev.msl_release_num desc
			),
	genbank_accession_csv_msl = 
		(select top 1 msl_release_num
			from taxonomy_node prev 
			where prev.ictv_id = tn.ictv_id
			and prev.genbank_accession_csv is not null
			order by prev.msl_release_num desc
			)
from taxonomy_node_names tn
where tn.msl_release_num = (select max(msl_release_num) from taxonomy_toc)
and [rank] = 'species'

GO

