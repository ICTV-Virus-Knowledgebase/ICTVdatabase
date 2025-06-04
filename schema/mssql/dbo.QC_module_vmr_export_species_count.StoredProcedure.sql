USE [ICTVonline40]
GO

/****** Object:  StoredProcedure [dbo].[QC_module_vmr_export_species_count]    Script Date: 6/4/2025 7:03:29 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE procedure [dbo].[QC_module_vmr_export_species_count]
	@filter varchar(1000) = 'ERROR%' 
AS
-- 
-- Verify that [vmr_export].[species] has an entry for every species in [taxonomy_node] / current MSL
--
--
-- TEST
--    -- list only errors
--    exec [QC_module_vmr_export_species_count]
--    -- test in QC framewokr
--    exec [QC_run_modules]
-- DECLARE @filter varchar(50); SET @filter='ERROR%'
select qc_module=OBJECT_NAME(@@PROCID),[table_name]='[vmr_export]',*--, qc_mesg 
from (
	--
	-- add OK/ERROR prefix
	--
	select *
	from (
		--
		-- species missing from VMR
		---
		select qc_mesg='ERROR: species missing from [vmr_export]',
			n.msl_release_num, n.lineage, ct=1
		from  taxonomy_node n
		where n.msl_release_num = (select max(msl_release_num) from taxonomy_toc)
		and n.level_id=600
		and n.name not in (select species from [vmr_export])
	
		union all

		select qc_mesg='ERROR: extra species in [vmr_export] (missing from taxonomy_node)',
			msl_release_num=(select max(msl_release_num) from taxonomy_toc),
			lineage = vmr.species, ct=1
		from  vmr_export vmr
		where vmr.species not in (
			select name
			from  taxonomy_node n
			where n.msl_release_num = (select max(msl_release_num) from taxonomy_toc)
			and n.level_id=600
		)
		union all

		select qc_mesg='ERROR: too many/too few E records  in [vmr_export]',
			msl_release_num=(select max(msl_release_num) from taxonomy_toc),
			lineage = vmr.species, 
			ct=count((case when [Exemplar or additional isolate]='E' then 1 end))
		from  vmr_export vmr
		group by species 
		having 	1 <> count((case when [Exemplar or additional isolate]='E' then 1 end))
 
		union all
		
		select qc_mesg='ERROR: two isolates have same accession [vmr_export]',
			msl_release_num=(select max(msl_release_num) from taxonomy_toc),
			lineage = (case when vmr.[Virus GENBANK accession]='' then 'MSL40: no accesion; N=151'
						else vmr.[Virus GENBANK accession] + 
						' ['+min(Species+':'+[Exemplar or additional isolate]+':'+[Virus name(s)])+
						' | '+max(Species+':'+[Exemplar or additional isolate]+':'+[Virus name(s)])+']' end ), 
			ct=count(*)
		from  vmr_export vmr
		group by [Virus GENBANK accession] 
		having 	1 < count(*)
		
		union all

		select qc_mesg='ERROR: E record is not isolate_sort=1 [vmr_export]',
			msl_release_num=(select max(msl_release_num) from taxonomy_toc),
			lineage = Species, 
			ct=count(*)
		from  vmr_export vmr
		where [Isolate Sort] <> 1 AND [Exemplar or additional isolate] = 'E'
		group by Species
		
		union all

		select qc_mesg='ERROR: NULL isolate_sort [vmr_export]',
			msl_release_num=(select max(msl_release_num) from taxonomy_toc),
			lineage = Species, 
			ct=count(*)
		from  vmr_export vmr
		where [Isolate Sort] is NULL
		group by Species


	) src_data
) src
--where src.qc_mesg like @filter
order by msl_release_num desc , qc_mesg , lineage

GO


