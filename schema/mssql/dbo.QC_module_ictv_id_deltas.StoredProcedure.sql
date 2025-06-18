
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create procedure [dbo].[QC_module_ictv_id_deltas]
	@filter varchar(1000) = 'ERROR%' 
AS
-- 
-- Identify [taxonomy_node.ictv] series with un-expected starts, stop or gaps
--
--
-- TEST
--    -- list only errors
--    exec [QC_module_ictv_id_deltas]
--    -- test in QC framework
--    exec [QC_run_modules]
-- DECLARE @filter varchar(50); SET @filter='ERROR%'
select qc_module=OBJECT_NAME(@@PROCID),[table_name]='[taxonomy_node_delta]',
	src.*,
	qc_mesg=(case when src.create_err='' and end_err='' and gap_err='' then 'OK'
			else 'ERROR: '+src.create_err+' '+src.end_err+' '+src.gap_err end)
from (
	select ictvs.*, 
		create_tags=nd.tag_csv2,
		create_err=(case when nd.is_new is null then 'creatre_missing' when nd.is_new+nd.is_merged+nd.is_split=0 then 'create_wrong' else '' end),
		end_tags=ed.tag_csv2,
		end_err=(case when cur_msl=max_msl then '' when ed.is_deleted is null then 'end_missing' when ed.is_deleted+ed.is_merged+ed.is_split=0 then 'end_wrong' else '' end),
		gap_err=(case when ct=ct_prev and  ct<>(ct_next+is_msl_cur) then '' 
			when ct<>ct_prev then 'gap_prev:'+cast(ct-ct_prev as varchar(10)) else '' end)+' '+(case when ct<>(ct_next+is_msl_cur) then 'gap_next:'+cast(ct-(ct_next+is_msl_cur) as varchar(10)) 
			else '' end)
	from (
		--
		-- stats on each ICTV_ID
		--
		select 
			name=min(name)+(case when min(name)<>max(name) then ':'+max(name) else '' end),
			ictv_id, 
			min_taxnode_id=min(taxnode_id), max_taxnode_id=max(taxnode_id), 
			min_msl=min(msl_release_num), max_msl=max(msl_release_num),
			cur_msl=(select max(msl_release_num) from taxonomy_toc),
			is_msl_cur=(case when (select max(msl_release_num) from taxonomy_toc)=max(msl_release_num) then 1 else 0 end),
			ct=count(distinct(taxnode_id)),
			ct_prev = count(distinct(nd.new_taxid)),
			ct_next = count(distinct(ed.prev_taxid))
		from taxonomy_node n
		left outer join taxonomy_node_delta nd on nd.new_taxid=n.taxnode_id
		left outer join taxonomy_node_delta ed on ed.prev_taxid=n.taxnode_id
		where n.is_deleted=0 and n.is_obsolete=0 and msl_release_num is not NULL
		group by ictv_id
	) ictvs
	left outer join taxonomy_node_delta nd on nd.new_taxid=ictvs.min_taxnode_id
	left outer join taxonomy_node_delta ed on ed.prev_taxid=ictvs.max_taxnode_id
) as src
where 
-- filter
(case when src.create_err='' and end_err='' and gap_err='' then 'OK'
			else 'ERROR: '+src.create_err+' '+src.end_err+' '+src.gap_err end) like @filter
order by ictv_id
GO


