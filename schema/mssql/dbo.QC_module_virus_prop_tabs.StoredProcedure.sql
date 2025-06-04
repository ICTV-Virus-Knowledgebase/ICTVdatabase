USE [ICTVonline40]
GO

/****** Object:  StoredProcedure [dbo].[QC_module_virus_prop_tabs]    Script Date: 6/4/2025 7:02:55 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[QC_module_virus_prop_tabs]
	@filter varchar(1000) = 'ERROR%' 
AS
-- 
-- Identify [virus_prop] rows with formatting/data errors
--
--
-- TEST
--    -- list only errors
--    exec [QC_module_virus_prop_tabs]
--    -- list all
--    exec [QC_module_virus_prop_tabs] '%'
--    -- test in QC framewokr
--    exec [QC_run_modules]

select qc_module=OBJECT_NAME(@@PROCID),[table_name]='[virus_prop]', [taxon]=taxon, qc_mesg 
from (
	--
	-- add OK/ERROR prefix
	--
	select *, 
		qc_mesg = (case when errors='' then 'OK' else 'ERROR:'+errors end)
	from (
		--
		-- underlying analysis query
		---
		select *, errors=''+
				(case when [taxon] like '%'+char(9)+'%'					then 'TAB[taxon];' else '' end) +
				(case when [sub_taxon] like '%'+char(9)+'%'				then 'TAB[sub_taxon];' else '' end)+
				(case when [molecule] like '%'+char(9)+'%'				then 'TAB[molecule];' else '' end)+
				(case when [morphology] like '%'+char(9)+'%'				then 'TAB[morphology];' else '' end)+
				(case when [virion_size] like '%'+char(9)+'%'			then 'TAB[virion_size];' else '' end)+
				(case when [genome_segments] like '%'+char(9)+'%'		then 'TAB[genome_segments];' else '' end)+
				(case when [genome_configuration] like '%'+char(9)+'%'	then 'TAB[genome_configuration];' else '' end)+
				(case when [genome_size] like '%'+char(9)+'%'			then 'TAB[genome_size];' else '' end)+
				(case when [host] like '%'+char(9)+'%'					then 'TAB[host]='+replace([host],char(9),'[TAB]') else '' end)
		from virus_prop
	) src_data
) src
where src.qc_mesg like @filter
order by qc_mesg

/* 
--
-- remove tabs in the [host] column
--
update [virus_prop] set 
--select
 host=replace(host,'	'chr(,'')
from [virus_prop] where host like '%'+char(9)+'%'
*/
GO


