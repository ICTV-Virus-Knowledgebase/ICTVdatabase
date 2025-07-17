
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[rebuild_delta_nodes_2]
	@msl int = NULL,		 -- delete related deltas first
	@debug_taxid int = NULL  -- debugging - only deltas going INTO that node
AS

	-- -----------------------------------------------------------------------------
	--
	-- build deltas from in_out changes
	-- 
	-- version 2: try to separate real moves from taxons that have new lineages because a higher rank was re-named.
	--
	-- RUN TIME: 7 seconds
	-- -----------------------------------------------------------------------------
	--
	-- 20210505 curtish (Issue #5): obsolete is_now_type when MSL > 35, then add it back in
	--   declare @msl int; declare @debug_taxid int
	--   declare @msl int; declare @debug_taxid int; set @msl=18
	set @msl=(select isnull(@msl,MAX(msl_release_num)) from taxonomy_node)
	select 'TARGET MSL: ',@msl
	print '-- TARGET_MSL: '+rtrim(@MSL)
	-- ******************************************************************************************************
	--
	-- clean out deltas for this MSL
	--
	-- ******************************************************************************************************
	delete 
	-- select * 
	from taxonomy_node_delta
	where msl = @msl
	--where (new_taxid in (select taxnode_id from taxonomy_node where msl_release_num=@msl) or new_taxid is null)
	--and   (prev_taxid in (select taxnode_id from taxonomy_node where msl_release_num=@msl-1) or prev_taxid is null)
	print '-- MSL deltas DELETED'

	-- ******************************************************************************************************
	--
	-- IN_CHANGE: NEW / SPLIT
	--
	-- ******************************************************************************************************

	insert into taxonomy_node_delta (msl, prev_taxid, new_taxid, proposal, notes, is_new, is_split, is_now_type, is_promoted, is_demoted)
	select 
		msl=n.msl_release_num
		, p.taxnode_id, n.taxnode_id
		, proposal=n.in_filename
		, notes   =n.in_notes
		, is_new=(case when n.in_change='new' then 1 else 0 end)
		, is_split=(case when n.in_change='split' then 1 else 0 end)
		, is_now_type = (case
			-- is_ref/is_type obsoleted after MSL35 (Issue #5)
			--when n.msl_release_num > 35 then 0
			-- logic for previous MSLs
			when p.is_ref = 1 and n.is_ref = 0 then -1
			when p.is_ref = 0 and n.is_ref = 1 then 1
			else 0 end)
		, is_promoted = (case when p.level_id > n.level_id then 1 else 0 end)
		, is_demoted = (case when p.level_id < n.level_id then 1 else 0 end)
		-- debug
		--, t2='prev', p.taxnode_id, p.out_change, p.lineage
		--, t3='delta', d.*
	from taxonomy_node n
	left outer join taxonomy_node p on 
		p.msl_release_num = n.msl_release_num-1
		and 
		n.in_target in (p.lineage, p.name)
	left outer join taxonomy_node_delta d on d.new_taxid=n.taxnode_id
	where 
		n.in_change in ('new', 'split')
	and d.new_taxid is null
	and n.msl_release_num=@msl
	and n.is_deleted = 0
	and (n.taxnode_id=@debug_taxid or @debug_taxid is null) -- debug
	--group by p.lineage, n.in_target, p.msl_release_num, n.in_change, n.msl_release_num, n.lineage, n.taxnode_id, n.in_filename, cast(n.in_notes as varchar(max))
	order by n.taxnode_id, n.msl_release_num, n.lineage
	print '-- MSL_delta new/split INSERTED'

	-- ******************************************************************************************************
	--
	-- OUT_CHANGE: rename, merge, promote, move, abolish
	--
	-- ******************************************************************************************************


	insert into taxonomy_node_delta (msl, prev_taxid, new_taxid, proposal, notes, is_renamed, is_merged, is_lineage_updated, is_promoted, is_demoted, is_now_type, is_deleted)
	--select prev_taxid, new_taxid, count(*) from (
	-- add rename/moved empirally
	select 
		src.msl, src.prev_taxid, src.new_taxid, src.proposal, src.notes
		, is_renamed =         (case when prev_msl.name <> next_msl.name and is_merged = 0 then 1 else 0 end)
		, src.is_merged
		, is_lineage_updated = (case when prev_pmsl.lineage <> next_pmsl.lineage AND (prev_pmsl.level_id<>100/*root*/ or next_pmsl.level_id <> 100/*root*/) then 1 else 0 end)
		, is_promoted =        (case when prev_msl.level_id > next_msl.level_id then 1 else 0 end)
		, is_demoted =         (case when prev_msl.level_id < next_msl.level_id then 1 else 0 end)
		, is_now_type = (case
			-- is_ref/is_type obsoleted after MSL35 (Issue #5)
			--when next_msl.msl_release_num > 35 then 0
			-- logic for previous MSLs
			when prev_msl.is_ref = 1 and next_msl.is_ref = 0 then -1
			when prev_msl.is_ref = 0 and next_msl.is_ref = 1 then 1
			else 0 end)
		, src.is_abolish
	from (
		select distinct
			msl=p.msl_release_num+1
			,prev_taxid=p.taxnode_id
			,new_taxid=case
				-- handle SPECIES(Unassigned;Unassigned;Unassigned;Geminivirus group;Bean golden mosaic virus) BUT (target=new GENUS name)
				when p.out_change <> 'promote' AND p.level_id > targ.level_id AND targ_child.taxnode_id IS NOT NULL then targ_child.taxnode_id -- allow match to child of target of same name
				-- handle GENUS(Unassigned;Iridoviridae;Unassigned;African swine fever virus group) BUT (target=SPECIES, but genus is moved)
				when p.level_id=500/*genus*/ AND targ.level_id=600/*species*/ and p.name <> 'Unassigned' then targ.parent_id
				-- normal case - correct target
				else targ.taxnode_id
				end	
			/*,new_taxid_src=case
				-- handle SPECIES(Unassigned;Unassigned;Unassigned;Geminivirus group;Bean golden mosaic virus) BUT (target=new GENUS name)
				when p.out_change <> 'promote' AND p.level_id > targ.level_id AND targ_child.taxnode_id IS NOT NULL then 'targ_child.taxnode_id' -- allow match to child of target of same name
				-- handle GENUS(Unassigned;Iridoviridae;Unassigned;African swine fever virus group) BUT (target=SPECIES, but genus is moved)
				when p.level_id=500/*genus*/ AND targ.level_id=600/*species*/ and p.name <> 'Unassigned' then 'targ.parent_id'
				-- normal case - correct target
				else 'targ.taxnode_id'
				end
			*/
			,proposal=p.out_filename
			,notes   =cast(p.out_notes as varchar(max))
			,is_merged=(case when p.out_change='merge' then 1 else 0 end)
			,is_abolish=(case when p.out_change='abolish' then 1 else 0 end)
			--,is_renamed=(case when p.out_change='rename' then 1 else 0 end)
			--,is_move=(case when p.out_change='move' then 1 else 0 end)
			-- debugging
			--, p.out_change,p.lineage,p.out_target,targ.lineage,old_link=d.prev_taxid,targ_id=targ.taxnode_id, targ_child_id=targ_child.taxnode_id
		from taxonomy_node p
		left outer join taxonomy_node targ on 
			p.msl_release_num = targ.msl_release_num-1
			and (
				p.out_target in (targ.lineage, targ.name)
				or
				p._out_target_name = targ.name
			)
			and 
			p.is_deleted = 0
		-- allow match to child of target (ie, target is new genus for a species)
		left outer join taxonomy_node targ_child on 
			targ_child.parent_id = targ.taxnode_id
			and (targ_child.name = p.name or targ_child.name = p.out_target)
			and targ_child.level_id = p.level_id
			and p.out_change <> 'promote'
			and targ_child.name <> 'Unassigned'
			and targ_child.name is not null
			and targ_child.is_hidden = 0
			--and targ_child.name <> targ.name
		left outer join taxonomy_node_delta d on d.prev_taxid=p.taxnode_id
		where p.out_change is not null --in ('new', 'split')
		and p.msl_release_num = (@msl-1)
		and d.prev_taxid is null -- no double inserts!!!
		-- TESTING
		--and p.taxnode_id=19841242 -- TEST: Unassigned;Unassigned;Unassigned;Geminivirus group;Bean golden mosaic virus (target=genus name)
		--and p.taxnode_id=19820086 -- TEST: 'Unassigned;Iridoviridae;Unassigned;African swine fever virus group (target=species, but genus is moved)
		--and p.msl_release_num=11	and p.name like 'Influenza type C virus%'
		--and p.taxnode_id in (19900137, 19900770) -- 'Influenza C virus' genus/species ambiguity heuristic resolution (msl 11-12)
	) as src
	join taxonomy_node prev_msl on prev_msl.taxnode_id = src.prev_taxid
	join taxonomy_node prev_pmsl on prev_pmsl.taxnode_id = prev_msl.parent_id
	left outer join taxonomy_node next_msl on next_msl.taxnode_id = src.new_taxid
	left outer join taxonomy_node next_pmsl on next_pmsl.taxnode_id = next_msl.parent_id
	where (@debug_taxid is null or src.new_taxid = @debug_taxid ) -- debug


	--select * from taxonomy_node where taxnode_id in (19900137	,19910141, 19900770	,19910993)

	--) as src 
	--group by prev_taxid, new_taxid
	--having count(distinct(rtrim(prev_taxid)+','+rtrim(new_taxid))) > 1
	print '-- MSL_delta OUT_CHANGE: rename, merge, promote, move, abolish INSERTED'

	-- ******************************************************************************************************
	--
	-- NO CHANGE - deltas between nodes with same lineage
	--
	-- still set proposal, in case of attribute change (is_ref, etc)
	-- ******************************************************************************************************
	insert into taxonomy_node_delta (msl,prev_taxid, new_taxid, proposal, notes, is_lineage_updated, is_promoted, is_demoted, is_now_type)
	select 
		--p.msl_release_num, p_lin=p.lineage, p_name=p.name, -- debug
		msl=n.msl_release_num
		, prev_taxid=p.taxnode_id
		, new_taxid=n.taxnode_id
		, proposal=p.out_filename
		, notes=p.out_notes
		, is_lineage_updated = (case when pp.lineage <> pn.lineage AND pp.level_id<>100/*root*/ then 1 else 0 end)
		, is_promoted =        (case when p.level_id > n.level_id then 1 else 0 end)
		, is_demoted =         (case when p.level_id < n.level_id then 1 else 0 end)
		, is_now_type =        (case
			-- is_ref/is_type obsoleted after MSL35 (Issue #5)
			--when n.msl_release_num > 35 then 0
			-- logic for previous MSLs
			when p.is_ref = 1 and n.is_ref = 0 then -1
			when p.is_ref = 0 and n.is_ref = 1 then 1
			else 0 end)
		--,n_lin=n.lineage -- debug
		--,pd.tag_csv, nd.tag_csv, nd.prev_taxid -- debug
	from taxonomy_node p
	join taxonomy_node n 
			-- SAME NAME constraints v7 (link root nodes)
			on n.msl_release_num = (p.msl_release_num+1)
			and (
				-- same LINEAGE
				(n.lineage = p.lineage)
				or
				-- same non-NULL, non-Unassigned names, same level (species, genus, etc)
				(n.name = p.name AND n.name<>'Unassigned' AND n.level_id=p.level_id)
				or 
				-- root of tree (special case)
				(n.level_id = 100 AND p.level_id = 100)
			) and (
				-- no relationships between hidden nodes
				(p.is_hidden=0 and n.is_hidden=0)
				or
				-- root of tree (special case)
				(n.level_id = 100 AND p.level_id = 100)		
			)
		left outer join taxonomy_node_delta pd 
			on pd.prev_taxid = p.taxnode_id
			and p.taxnode_id is not null
			and pd.is_split = 0
		left outer join taxonomy_node_delta nd
			on nd.new_taxid = n.taxnode_id
			and n.taxnode_id is not null
			and nd.is_merged = 0 -- merge target often exists in prev MSL and continues with same name
		-- get parents
		join taxonomy_node pp on pp.taxnode_id = p.parent_id
		join taxonomy_node pn on pn.taxnode_id = n.parent_id
	where
	n.msl_release_num=@msl
	and 
	pd.prev_taxid is null and nd.new_taxid is null
	and 
	p.is_deleted = 0 and n.is_deleted = 0
	and
	(@debug_taxid is null OR n.taxnode_id = @debug_taxid) -- debug

	-- and p.level_id<=300 -- debug
	-- and p.name ='bushbush virus' -- debug
	-- and select msl_release_num, in_change, out_change, name, lineage from taxonomy_node p where p.name in ('Bovine enterovirus', 'Bovine enterovirus 1', 'Bovine enterovirus 2') -- debug
	order by p.name, p.msl_release_num
	print '-- MSL_delta NO_CHANGE: INSERTED'

	-- ******************************************************************************************************
	--
	-- MOVED - deltas between nodes with changed parents
	--
	-- still set proposal, in case of attribute change (is_ref, etc)
	-- ******************************************************************************************************
	--DECLARE @msl INTEGER; SET @msl=38 -- debug
	update taxonomy_node_delta set
	--
	-- there appear to be very few actual MOVES
	-- most are parent renames, and a few split/merges of parents!
	--
	/*
	select 
		msl=taxonomy_node_delta.msl, 
		target=(case taxonomy_node_delta.msl when 38 then '23/24' when 37 then '720' when 36 then '205' else '?' end)
		, whyNotMove = 
			(case when prev_parent.ictv_id <> next_parent.ictv_id then '' else 'parent same ictv_id; '  end)
			+(case when prev_node.out_change like '%promot%' then 'promotionl ' else '' end)
			+(case when prev_node.out_change like '%demo%' then 'demotion; ' else '' end)
			+(case when parent_delta.is_merged = 1 then (case when prev_parent.name <> next_parent.name then '' else 'parent merged, but same name; ' end)else '' end)
			+(case when parent_delta.is_split = 1 then (case when prev_parent.name <> next_parent.name then '' else 'parent split, but same name; ' end) else '' end)
			+(case when prev_parent.level_id=100 and next_parent.level_id=100 then  'root->root'  else '' end)
		, [NODE]='NODE>>', prev_rank=prev_node.rank, prev_name=prev_node.name, out_change=prev_node.out_change, next_name=next_node.name, prev_node.out_filename
		, [PARENTS]='PARENTS>>', prev_parent_ictv= prev_parent.ictv_id, prev_parent_name = prev_parent.name, prev_parent.out_change, next_parent.in_change,next_parent_name =next_parent.name, next_parent_ictv=next_parent.ictv_id
		, [PARENT_DELTA]='PARENT_DELTA>>', parent_delta.tag_csv2
		, [CONCLUSION]='CONCLUSION>>',
	*/  
		is_moved = 
			(case when prev_parent.ictv_id <> next_parent.ictv_id then 1 else 0 end)
			*(case when  prev_node.out_change like '%promot%' then 0 else 1 end)
			*(case when  next_node.out_change like '%demot%' then 0 else 1 end)
			*(case when parent_delta.is_merged = 1 then (case when prev_parent.name <> next_parent.name then 1 else 0 end) else 1 end)
			*(case when parent_delta.is_split = 1 then (case when prev_parent.name <> next_parent.name then 1 else 0 end) else 1 end)
			*(case when prev_parent.level_id=100 and next_parent.level_id=100 then  0  else 1 end)
	from taxonomy_node_delta 
	left outer join taxonomy_node_names prev_node on taxonomy_node_delta.prev_taxid = prev_node.taxnode_id -- N=24
	left outer join taxonomy_node prev_parent on prev_parent.taxnode_id = prev_node.parent_id -- N=24
	left outer join taxonomy_node_names next_node on next_node.taxnode_id = taxonomy_node_delta.new_taxid -- N=24
	left outer join taxonomy_node next_parent on next_parent.taxnode_id = next_node.parent_id -- N=24
	left outer join taxonomy_node_delta parent_delta on parent_delta.prev_taxid = prev_parent.taxnode_id and parent_delta.new_taxid=next_parent.taxnode_id -- N=1
	where
		 prev_node.msl_release_num+1=@msl
	and (
		-- nodes that are potentially a move
		prev_node.out_change like '%move%' 
		or (parent_delta.is_merged = 1 and  prev_parent.name <> next_parent.name)
		or (parent_delta.is_split = 1 and prev_parent.name <> next_parent.name)
		or prev_parent.ictv_id <> next_parent.ictv_id
		  --or prev_parent.name = 'Viunavirus' or next_parent.name='Kuttervirus' -- MSL36 merge
	)
	-- focus queries for debugging
	--and (
	--	 (parent_delta.is_split = 1 or parent_delta.is_merged = 1)
	--or prev_parent.name = 'Viunavirus' or next_parent.name='Kuttervirus' -- MSL36 merge
	--    )
	--and (prev_parent.level_id = next_parent.level_id)
	--order by prev_node.left_idx
	--and (prev_parent.name = 'Autographivirinae') -- genera that stay in 'Autographiviridae' (promotion) are NOT moves
	--and  prev_parent.name = 'Viunavirus' or next_parent.name='Kuttervirus' -- MSL36 merge
	--order by prev_node.msl_release_num, prev_node.left_idx
	print '-- MSL_delta IS_MOVED: UPDATED'

	-- ******************************************************************************************************
	--
	-- MERGED - update "sibling" deltas - if one delta going into a taxon has is_merged=1, then they all should
	--
	-- still set proposal, in case of attribute change (is_ref, etc)
	-- ******************************************************************************************************
	-- declare @msl int; declare @debug_taxid int; set @msl= 18 -- debug
	update taxonomy_node_delta set
	/* 
	declare @msl int; set @msl =18 
	select 
		taxonomy_node_delta.*, '|||', msrc.*, '>>>>',
	 --*/ 
		is_merged = 1,
		proposal = msrc.proposal,
		notes = msrc.notes
	from taxonomy_node_delta 
	join (
		select new_taxid, proposal=max(proposal), notes=max(notes)
		from taxonomy_node_delta 
		where msl = @msl 
		group by new_taxid
		having count(*) > 1
	) as msrc
	on msrc.new_taxid = taxonomy_node_delta.new_taxid
	where  taxonomy_node_delta.is_merged = 0 
	print '-- MSL_delta IS_MERGED: UPDATED'



	--
	-- stats
	--
	-- declare @msl int; set @msl=(select MAX(msl_release_num) from taxonomy_node)
	select 
		msl
		,case when tag_csv='' then 'UNCHANGED' else tag_csv end as [change_type]
		, COUNT(*) as [counts]
	from taxonomy_node_delta
	where msl = @msl
	group by msl, tag_csv
	order by msl, tag_csv
	print '-- MSL_delta stats'

	select 
		msl
		,case when tag_csv2='' then 'UNCHANGED' else tag_csv2 end as [change_type]
		, COUNT(*) as [counts]
	from taxonomy_node_delta
	where msl = @msl
	group by msl, tag_csv2
	order by msl, tag_csv2
	print '-- MSL_delta stats2'

	/*
	-- TEST
	exec rebuild_delta_nodes_2 38

	-- DEBUG - build only deltas into a specific node, but delete all deltas for that MSL
	exec rebuild_delta_nodes_2 18 19990680 -- 3 way merge, with main taxon retaining name
	*/
GO


