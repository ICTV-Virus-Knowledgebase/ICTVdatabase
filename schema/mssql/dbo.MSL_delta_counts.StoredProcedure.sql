
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE  procedure [dbo].[MSL_delta_counts] 
	@msl_or_tree int = NULL
as
-- DEBUG - uncomment to replace procedure definition for testing.
--declare @msl_or_tree int; set @msl_or_tree=37 -- DEBUG
-- -------------------------------------------------------------------------
-- DELTA stats between two MSLS
-- Table 1 for MLS publication
-- https://uab-lefkowitz.atlassian.net/browse/IVK-166
-- -------------------------------------------------------------------------
/*
 exec [dbo].[MSL_delta_counts]    -- latest MSL
 exec [dbo].[MSL_delta_counts] 36 -- has merge, promote and demote
 exec [dbo].[MSL_delta_counts] 35 -- has split, promote
*/
-- Run time 
--	~ 
-- -------------------------------------------------------------------------
-- 20250228 CurtisH; make columns match MSL.xlsx:[Taxon Counts] sheet.
-- 20230210 CurtisH; MSL38 create

-- -------------------------------------------------------------------------

--
-- create ICTV MSL (extended) from taxonomy_node
declare @msl int
select  @msl=max(msl_release_num) 
from taxonomy_toc 
where  @msl_or_tree is null  or msl_release_num = @msl_or_tree or tree_id =  @msl_or_tree 


--select 'TARGET MSL: '=@msl
print 'TARGET MSL:'+rtrim(@msl)

select 
	-- RANK
	rank=tax_level.name
	-- PREV MSL
	, old_msl =@msl-1
	, old_msl_ct = (
		select count(*)
		from taxonomy_node tn
		where tn.msl_release_num = @msl-1
		and tn.level_id = tax_level.id
		)
	-- CHANGES
	, [+create] = (
		select count(*)
		from taxonomy_node_delta tax_delta
		join taxonomy_node tnode on tnode.taxnode_id = tax_delta.new_taxid
		where tnode.msl_release_num=@msl
		and tax_delta.is_new = 1
		and tnode.level_id = tax_level.id
		)
	, [+create_by_promote] =(
		select count(*)
		from taxonomy_node_delta tax_delta
		join taxonomy_node tnode on tnode.taxnode_id = tax_delta.new_taxid
		where tnode.msl_release_num=@msl
		and tax_delta.is_promoted = 1
		and tnode.level_id = tax_level.id
	)
	, [+create_by_demote] =(
		select count(*)
		from taxonomy_node_delta tax_delta
		join taxonomy_node tnode on tnode.taxnode_id = tax_delta.new_taxid
		where tnode.msl_release_num=@msl
		and tax_delta.is_demoted = 1
		and tnode.level_id = tax_level.id
	)
	, [+create_by_split] = (
		-- 
		-- because not all split deltas might be annotated with "split"
		-- we find all old taxa that are involved in a split
		-- then count all new taxa that are connected to them
		-- and compute the delta: count(#new)-count(#prev)
		-- Thus if one taxon was unchanged, and others were split from it, 
		-- it will work as well if there was no unchanged taxon in split, and
		-- all were marked with split.
		--
		select count(distinct(delta.new_taxid))-count(distinct(delta.prev_taxid))
		from taxonomy_node_delta delta
		where delta.prev_taxid in (
			select tn.taxnode_id
			from taxonomy_node tn
			join taxonomy_node_delta tax_delta on tax_delta.prev_taxid = tn.taxnode_id
			where tn.msl_release_num=@msl-1
			and tax_delta.is_split = 1
			and tn.level_id = tax_level.id
		)
	)
	, [-abolish] = (
		select -count(*)
		from taxonomy_node_delta tax_delta
		join taxonomy_node tnode on tnode.taxnode_id = tax_delta.prev_taxid
		where tnode.msl_release_num=@msl-1
		and tax_delta.is_deleted = 1
		and tnode.level_id = tax_level.id
		)
	,[-abolish_by_merge] = (
		-- 
		-- because not all merge deltas might be annotated with "merge"
		-- we find all new taxa that are involved in a merge
		-- then count all previous taxa that are connected to them
		-- and compute the delta: count(#new)-count(#prev)
		-- Thus if one taxon was unchanged, and others were merged into it, 
		-- it will work as well if there was no unchanged taxon in merge.
		--
		select count(distinct(delta.new_taxid))-count(distinct(delta.prev_taxid))
		from taxonomy_node_delta delta
		where delta.new_taxid in (
			select tn.taxnode_id
			from taxonomy_node tn
			join taxonomy_node_delta tax_delta on tax_delta.new_taxid = tn.taxnode_id
			where tn.msl_release_num =@msl
			and tax_delta.is_merged = 1
			and tn.level_id = tax_level.id

		)
	)
	, [-abolish_by_promote] = (
		select -count(*)
		from taxonomy_node_delta tax_delta
		join taxonomy_node tnode on tnode.taxnode_id = tax_delta.prev_taxid
		where tnode.msl_release_num=@msl-1
		and tax_delta.is_promoted = 1
		and tnode.level_id = tax_level.id
		)
	, [-abolish_by_demote] = (
		select -count(*)
		from taxonomy_node_delta tax_delta
		join taxonomy_node tnode on tnode.taxnode_id = tax_delta.prev_taxid
		where tnode.msl_release_num=@msl-1
		and tax_delta.is_demoted= 1
		and tnode.level_id = tax_level.id
		)
	, [_action_move] = (
		select count(*)
		from taxonomy_node_delta tax_delta
		join taxonomy_node tnode on tnode.taxnode_id = tax_delta.new_taxid
		where tnode.msl_release_num=@msl
		and tax_delta.is_moved = 1
		and tnode.level_id = tax_level.id
		)
	, [_action_rename] = (
		select count(*)
		from taxonomy_node_delta tax_delta
		join taxonomy_node tnode on tnode.taxnode_id = tax_delta.new_taxid
		where tnode.msl_release_num=@msl
		and tax_delta.is_renamed = 1
		and tnode.level_id = tax_level.id
		)
	-- NEW MSL
	, new_msl_ct = (
		select count(*)
		from taxonomy_node tn
		where tn.msl_release_num = @msl
		and tn.level_id = tax_level.id
		)
	, new_msl=@msl
	-- Other FYI columns, not included in counts table in MSL
	, [_action_lineage_update] = (
		select count(*)
		from taxonomy_node_delta tax_delta
		join taxonomy_node tnode on tnode.taxnode_id = tax_delta.new_taxid
		where tnode.msl_release_num=@msl
		and tax_delta.is_lineage_updated = 1
		and tnode.level_id = tax_level.id
		)

from taxonomy_level tax_level
where tax_level.name <> 'tree'
order by tax_level.id

--
-- generate a complete, detailed change list, including all un-changed taxa
--
select  
	p.msl, p.rank, p.name, p.taxnode_id,
	[PREV]='<PREV<'
	,d.*
	,[NEXT]='>NEXT>'  
	,n.taxnode_id, n.name, n.rank,n.msl
from taxonomy_node_delta d
left outer join taxonomy_node_names p on p.taxnode_id = d.prev_taxid
left outer join taxonomy_node_names n on n.taxnode_id = d.new_taxid
where d.msl= @msl
and (p.msl is not null or n.msl is not null)
order by isnull(n.lineage, p.lineage)

GO

