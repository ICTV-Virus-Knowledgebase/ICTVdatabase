
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[rebuild_node_merge_split]
AS

	-- ***************************
	-- throw away what we have
	-- ***************************
	truncate table taxonomy_node_merge_split

	-- ***************************
	-- add identities (dist=0)
	-- ***************************
	insert into taxonomy_node_merge_split
	select 
		prev_ictv_id=ictv_id
		, next_ictv_id=ictv_id
		, is_merged=0
		, is_split=0
		, is_recreated=0
		, dist=0
		, rev_count=0
	from taxonomy_node
	where msl_release_num is not null
	and is_hidden=0
	group by ictv_id

	-- ***************************
	-- add forward links (dist=1)
	-- ***************************
	insert into taxonomy_node_merge_split 
	select 
		prev_ictv_id=p.ictv_id
		, next_ictv_id=n.ictv_id
		, d.is_merged
		, d.is_split
		, is_recreated=0
		, dist=1
		, rev_count=0
	from taxonomy_node_delta d 
	join taxonomy_node p on d.prev_taxid=p.taxnode_id
	join taxonomy_node n on d.new_taxid=n.taxnode_id
	and p.level_id > 100 and n.level_id > 100
	where p.ictv_id <> n.ictv_id
	and p.msl_release_num = n.msl_release_num-1
	and p.is_hidden=0 and n.is_hidden=0

	-- ***************************
	-- add reverse links (dist=1)
	-- ***************************
	insert into taxonomy_node_merge_split 
	select 
		prev_ictv_id=n.ictv_id
		, next_ictv_id=p.ictv_id
		, d.is_merged
		, d.is_split
		, is_recreated=0
		, dist=1
		, rev_count=1
	from taxonomy_node_delta d 
	join taxonomy_node p on d.prev_taxid=p.taxnode_id
	join taxonomy_node n on d.new_taxid=n.taxnode_id
	and p.level_id > 100 and n.level_id > 100
	where p.ictv_id <> n.ictv_id
	and p.msl_release_num = n.msl_release_num-1
	and p.is_hidden=0 and n.is_hidden=0

	-- ***************************
	-- add resurection links (dist=1): both forwards and backwards
	-- ***************************
	-- example: 
	--    MSL4-5      Acute bee paralysis virus, ictv_id=19760317 (abolished)
    --    MSL22-40    Acute bee paralysis virus, ictv_id=20040961 (new)
	-- example: 
	--    MSL6-12	  M'Poko virus, ictv_id=, (abolished)
	--    MSL8-40       [MSL8.new]Yaba-1 virus[MSL28:rename]M'Poko virus[etc]
	insert into taxonomy_node_merge_split 
	select distinct
		prev_ictv_id	= (case direction.rev_count when 0 then early.ictv_id when 1 then late.ictv_id  end)
		, next_ictv_id	= (case direction.rev_Count when 0 then late.ictv_id  when 1 then early.ictv_id end)
		, is_merged		= 0
		, is_split		= 0
		, is_recreated	= 1
		, dist			= 1
		, rev_count		= direction.rev_count
		-- report='RESURECTIONS: Abolished and re-created later', 
		-- early_msl=early.msl_release_num, early_prop=early.next_proposal,  early.next_tags, early.ictv_id,
		-- early_name=early.name, late_name=late.name,
		--late.ictv_id, late.prev_tags, late_prop=late.prev_proposal, late_msl= late.msl_release_num
	from (select rev_count=0 union select rev_count=1) as direction,
		 taxonomy_node_dx early
	join taxonomy_node_dx late on late.name =early.name --and late.prev_tags like '%New%' 
	and late.msl_release_num > early.msl_release_num and late.ictv_id <> early.ictv_id
	and early.level_id = late.level_id
	--where early.next_tags like '%Abolish%'
	and not exists (select * from taxonomy_node_merge_split ms where ms.prev_ictv_id=early.ictv_id and ms.next_ictv_id=late.ictv_id)
	--order by early.msl_release_num, early.name

	/*****************************
	 * compute closure 
	 *****************************/
	select 'start closure'; while @@ROWCOUNT > 0 BEGIN
		insert into taxonomy_node_merge_split
		select 
			prev_ictv_id, next_ictv_id
			, is_merged=max(is_merged)
			, is_split=max(is_split)
			, is_recreated=max(is_recreated)
			, dist=min(dist)
			, rev_count=sum(rev_count)
		from (
			select 
				p.prev_ictv_id
				, n.next_ictv_id
				,is_merged		=(p.is_merged	+ n.is_merged)
				,is_split		=(p.is_split	+ n.is_split)
				,is_recreated	=(p.is_recreated+ n.is_recreated)
				,dist			=(p.dist		+ n.dist)
				,rev_count		=(p.rev_count	+ n.rev_count)
			from taxonomy_node_merge_split p
			join taxonomy_node_merge_split n on (
				p.next_ictv_id = n.prev_ictv_id
			)
			where 
			-- ignore identities
			p.dist > 0 and n.dist > 0
		) as src
		-- collapse multiple paths between the same points.
		group by prev_ictv_id, next_ictv_id
		-- don't duplicate existing paths
		having not exists (
			select * 
			from taxonomy_node_merge_split cur
			where cur.prev_ictv_id=src.prev_ictv_id
			and   cur.next_ictv_id=src.next_ictv_id
		)
		--order by p.prev_taxid, n.next_taxid
	END; select 'closure done'


	/**
	 ** TEST symetry
	 **/
	select 'TEST', * from taxonomy_node_merge_split 
	where prev_ictV_id = 19710158 

	select 'TEST', * from taxonomy_node_merge_split 
	where next_ictV_id = 19710158

	select 'TEST', * from taxonomy_node_merge_split 
	where prev_ictV_id = 20093515

	select 'TEST', * from taxonomy_node_merge_split 
	where next_ictV_id =20093515

	select 'TEST RECREATED: Acute bee paralysis virus', * from taxonomy_node_merge_split 
	where next_ictv_id in (19760317,20040961) order by dist, rev_count
GO

