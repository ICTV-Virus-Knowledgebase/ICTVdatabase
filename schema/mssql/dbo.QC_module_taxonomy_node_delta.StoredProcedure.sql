USE [ICTVonline40]
GO

/****** Object:  StoredProcedure [dbo].[QC_module_taxonomy_node_delta]    Script Date: 6/18/2025 6:55:22 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[QC_module_taxonomy_node_delta]
	@filter varchar(1000) = 'ERROR%' 
AS
-- 
-- Identify [taxonomy_node_delta] rows with unexpected NULLs, or that are missing all together
--
--
-- TEST
--    -- list only errors
--    exec [QC_module_taxonomy_node_delta]
--    -- test in QC framewokr
--    exec [QC_run_modules]
-- DECLARE @filter varchar(50); SET @filter='ERROR%'
select qc_module=OBJECT_NAME(@@PROCID),[table_name]='[taxonomy_node_delta]',*--, qc_mesg 
from (
	--
	-- add OK/ERROR prefix
	--
	select *
	from (
		--
		-- underlying analysis query
		---
		select qc_mesg='ERROR: new_taxid=NULL, but not an ABOLISH',
			d.msl, d.prev_taxid, n.ictv_id, d.new_taxid, d.tag_csv2, n.lineage, target=n.out_target
		from  taxonomy_node_delta d
		left outer join taxonomy_node n 
		on n.taxnode_id = d.prev_taxid
		where d.new_taxid is NULL and d.is_deleted =0
	
		union

		select qc_mesg='ERROR: prev_taxid=NULL, but not a NEW',
			d.msl, d.prev_taxid, n.ictv_id,d.new_taxid, d.tag_csv2, n.lineage, target=n.in_target
		from  taxonomy_node_delta d
		left outer join taxonomy_node n 
		on n.taxnode_id = d.new_taxid
		where d.prev_taxid is NULL and d.is_new =0
	) src_data
) src
where src.qc_mesg like 'ERROR%'-- @filter
order by msl desc, lineage, qc_mesg

GO


