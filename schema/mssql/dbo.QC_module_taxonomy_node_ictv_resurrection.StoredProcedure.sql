
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--
-- ICTV_ID issues
--
-- MOVE this into QC_module_taxonomy_node_ictv_resurrection
--   NEEDS ERROR FLAGS, keep showing linked things that are not abolish:new

CREATE procedure [dbo].[QC_module_taxonomy_node_ictv_resurrection]
	@filter varchar(1000) = 'ERROR%',
	@target_name varchar(100) = NULL 
AS
-- 
-- Identify ([rank],[name]) associated with multiple [ictv_id]'s 
--
--
-- TEST
--    -- list only hard errors
--    exec [QC_module_taxonomy_node_ictv_resurrection]
--    -- list only Zika virus
--    exec [QC_module_taxonomy_node_ictv_resurrection] '%', 'Zika virus'
--    -- list only CASE problems
--    exec [QC_module_taxonomy_node_ictv_resurrection] '%CASE%'
--    -- test in QC framework
--    exec [QC_run_modules]
--
-- DEBUG:
--   DECLARE @filter varchar(50); SET @filter='ERROR%'; DECLARE @target_name varchar(100); SET @target_name=NULL--'Zika virus'

select qc_module=OBJECT_NAME(@@PROCID),[table_name]='[taxonomy_node]',*--, qc_mesg 
from (
--exec rebuild_node_merge_split

 --DEBUG  DECLARE @target_name varchar(50); SET @target_name =NULL--'zika virus'
	select 
		pairs.*,
		qc_mesg = 
			(case when p_name COLLATE SQL_Latin1_General_CP1_CS_AS = n_name COLLATE SQL_Latin1_General_CP1_CS_AS then '' else 'WARNING: CASE; ' end)
			+
			(case when pairs.link_ct = 0 then 'ERROR: NOT LINKED;'
				when pairs.link_ct = 1 and p_out_change = 'abolish' and n_in_change = 'new' then 'OK: linked new:abolish/new:...'
				when pairs.link_ct = 1 and (not (p_out_change = 'abolish' and n_in_change = 'new') or p_out_change is null or n_in_change is null) then 'WARNING: linked, but '+isnull(p_out_change,'NULL')+':'+ISNULL(n_in_change,'NULL')
				when pairs.link_ct > 1 then 'ERROR: link_ct > 1'
				else 'ERROR: unknown'
				end)
	from (
		--DEBUG DECLARE @target_name varchar(50); SET @target_name ='zika virus'
		select 
			src.*,  
			s1='>>>', 
			p_name =prev_range.name, p_ictv_id=prev_range.ictv_id,p_min_msl=prev_range.min_msl, p_max_msl=prev_range.max_msl,  p_out_change=pc.out_change,
			s2=(case when prev_range.max_msl = next_range.min_msl+1 then '>>ADJ>>' else '>>GAP>>' end),
			prevDELTAs=(select concat(count(*),'')+':'+isnull( max(d.tag_csv2+isnull(':'+d.proposal,'')),'') from taxonomy_node_delta d where d.new_taxid=next_range.min_taxnode_id),
			n_in_change=nc.in_change, n_name =next_range.name, n_ictv_id=next_range.ictv_id,n_min_msl=next_range.min_msl, n_max_msl=next_range.max_msl, 
			s3='====', link_ct=(
				select count(*)
				from taxonomy_node_merge_split ms 
				where ms.prev_ictv_id = prev_range.ictv_id 
				and ms.next_ictv_id   = next_range.ictv_id
				)
		from (
			-- rank:NAMES associated with multiple ICTV_IDs
			-- DECLARE @target_name varchar(50); SET @target_name ='zika virus'
			select n.level_id, n.name, ictv_ct=count(distinct(n.ictv_id))--, new_ictv_ct=count(distinct(ms.next_ictv_id))
			from taxonomy_node n
			--FIX
			--join taxonomy_node_merge_split ms on ms.prev_ictv_id = n.ictv_id
			where name = ISNULL(@target_name,name)  
			and name <> 'Unnamed genus'  
			group by n.level_id, n.name  
			having count(distinct(ictv_id))>1 
		) as src
		join (
			-- rank:NAME by ICTV_ID with min/max MSL
			select n.level_id, n.name, n.ictv_id, min_msl=min(n.msl_release_num), max_msl=max(n.msl_release_num), min_taxnode_id=min(n.taxnode_id), max_taxnode_id=max(n.taxnode_id)
			from taxonomy_node n
			group by n.level_id, n.ictv_id, n.name 
		) as prev_range
		on prev_range.level_id=src.level_id and prev_range.name =src.name 
		join taxonomy_node pc on pc.taxnode_id = prev_range.max_taxnode_id 
		left outer join (
			-- rank:NAME by ICTV_ID with min/max MSL
			select n.level_id, n.name, n.ictv_id, min_msl=min(n.msl_release_num), max_msl=max(n.msl_release_num), min_taxnode_id=min(n.taxnode_id), max_taxnode_id=max(n.taxnode_id)
			from taxonomy_node n
			group by n.level_id, n.ictv_id, n.name  
		) as next_range
		on next_range.level_id=src.level_id and next_range.name =src.name 
		left outer join taxonomy_node nc on nc.taxnode_id = next_range.min_taxnode_id
		where prev_range.max_msl < next_range.min_msl
/*		and not exists (
			-- remove things that are linked in merge_split
			select * 
			from taxonomy_node_merge_split ms 
			where ms.prev_ictv_id = prev_range.ictv_id 
			and ms.next_ictv_id   = next_range.ictv_id
*/
	) as pairs

) src
where src.qc_mesg like  @filter
and name like ISNULL(@target_name,name)
order by name, p_min_msl, p_max_msl, n_min_msl, n_max_msl

GO

