USE [ICTVonline40]
GO

/****** Object:  StoredProcedure [dbo].[QC_module_taxonomy_node_hidden_nodes]    Script Date: 6/4/2025 6:49:55 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[QC_module_taxonomy_node_hidden_nodes]
	@filter varchar(1000) = 'ERROR%' 
AS
-- 
-- Identify [taxonomy_node] rows with with is_hidden=1, that shouldn't be
--
--
-- TEST
--    -- list only errors
--    exec [QC_module_taxonomy_node_hidden_nodes]
--    -- list all
--    exec [QC_module_taxonomy_node_hidden_nodes] '%'
--    -- test in QC framewokr
--    exec [QC_run_modules]
-- DECLARE @filter varchar(50); SET @filter='ERROR%'
select qc_module=OBJECT_NAME(@@PROCID),[table_name]='[taxonomy_node]', [msl]=msl_release_num,*--, qc_mesg 
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
		select msl_release_num, taxnode_id, left_idx,  [rank]=r.name, n.name, is_hidden, is_deleted, is_typo, is_obsolete, n.notes, 
			errors=''+
				(case when n.is_hidden=1 AND n.level_id <> 100 AND is_deleted+is_typo+is_obsolete=0	then 'HIDDEN['+r.name+':'+n.name+'];' else '' end) 
		from taxonomy_node n
		join taxonomy_level r on r.id = n.level_id
		where msl_release_num is not NULL
	) src_data
) src
where src.qc_mesg like @filter
order by msl desc, left_idx, qc_mesg

/* 
--
-- remove incorrectly is_hidden rows in [taxonomy_node]
--
update [taxonomy_node] set 
--select msl_release_num, left_idx, taxnode_id, parent_id, level_id, lineage, is_hidden, in_filename, 
 is_hidden=0
from [taxonomy_node] where 
msl_release_num is not null
and
is_hidden=1 AND level_id <> 100 AND is_deleted+is_typo+is_obsolete=0
order by msl_release_num, left_idx

*/
GO


