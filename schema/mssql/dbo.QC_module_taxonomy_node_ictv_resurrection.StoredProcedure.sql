USE [ICTVonline40]
GO

/****** Object:  StoredProcedure [dbo].[QC_module_taxonomy_node_ictv_resurrection]    Script Date: 6/4/2025 6:03:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--exec QC_module_ictv_id_deltas




CREATE procedure [dbo].[QC_module_taxonomy_node_ictv_resurrection]
	@filter varchar(1000) = 'ERROR%' 
AS
-- 
-- Identify [taxonomy_node_delta] rows with unexpected NULLs, or that are missing all together
--
--
-- TEST
--    -- list only errors
--    exec [QC_module_taxonomy_node_ictv_resurrection]
--    -- test in QC framework
--    exec [QC_run_modules]
-- DECLARE @filter varchar(50); SET @filter='ERROR%'

select qc_module=OBJECT_NAME(@@PROCID),[table_name]='[taxonomy_node]',*--, qc_mesg 
from (
	--
	-- add OK/ERROR prefix
	--
	select src_data.*,
					class =(case when src_data.max_msl=(select max(msl_release_num) from taxonomy_toc) then 'CUR_MSL]]'
					when next_life.ictv_id is NULL then 'GAP>>'
					else '>>ADJ>>'
					end),
			next_ictv_id=next_life.ictv_id, next_min_msl=next_life.min_msl, next_max_msl=next_life.max_msl, next_msl_ct=next_life.msl_ct
	from (
		--
		-- underlying analysis query
		---
		select 
				qc_mesg='ERROR: ressurection of taxon with new ICTV_ID',
				ictvs.*,
				-- MSL extent of each ICTV
				min_msl=min(n.msl_release_num), max_msl=max(n.msl_release_num), msl_ct=count(n.ictv_id)
		from (
			-- individual distinct ICTVs that are linked to the same name
			select
				zombie.name, zombie.ictv_ct, ictv_id --, min_msl=min(msl_release_num), max_msl=max(msl_release_num), msl_ct=count(*)
			from taxonomy_node as n
			join (
				-- names associated with multiple ICTV_IDs
				select name, ictv_ct=count(distinct(ictv_id)) 
				from taxonomy_node
				group by name
				having count(distinct(ictv_id))>1
			) as zombie
			on zombie.name = n.name
			group by zombie.name, zombie.ictv_ct, ictv_id
		) as ictvs
		join taxonomy_node n on n.ictv_id = ictvs.ictv_id
		group by ictvs.name, ictvs.ictv_ct, ictvs.ictv_id

	) src_data
	left outer join (
		select ictvs.*, min_msl=min(msl_release_num), max_msl=max(msl_release_num), msl_ct=count(*)
		from (
			select name, ictv_id
			from taxonomy_node nn
			group by name, ictv_id
		) as ictvs
		join taxonomy_node n on n.ictv_id = ictvs.ictv_id
		group by ictvs.name,  ictvs.ictv_id

	) as next_life 
	on next_life.name = src_data.name and next_life.min_msl=src_data.max_msl+1
) src
where src.qc_mesg like  @filter
order by name, min_msl

GO


