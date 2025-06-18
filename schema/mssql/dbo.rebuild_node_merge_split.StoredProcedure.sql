
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
	-- add forward links
	-- ***************************
	insert into taxonomy_node_merge_split 
	select prev_ictv_id=p.ictv_id, next_ictv_id=n.ictv_id, d.is_merged, d.is_split, dist=1, rev_count=0
	from taxonomy_node_delta d 
	join taxonomy_node p on d.prev_taxid=p.taxnode_id
	join taxonomy_node n on d.new_taxid=n.taxnode_id
	and p.level_id > 100 and n.level_id > 100
	where p.ictv_id <> n.ictv_id
	and p.msl_release_num = n.msl_release_num-1
	and p.is_hidden=0 and n.is_hidden=0

	-- ***************************
	-- add identities
	-- ***************************
	insert into taxonomy_node_merge_split
	select 
		prev_ictv_id=ictv_id
		, next_ictv_id=ictv_id
		, is_merged=0
		, is_split=0
		, dist=0
		, rev_count=0
	from taxonomy_node
	where msl_release_num is not null
	and is_hidden=0
	group by ictv_id
	-- ***************************
	-- add reverse links
	-- ***************************
	insert into taxonomy_node_merge_split 
	select prev_ictv_id=n.ictv_id, next_ictv_id=p.ictv_id, d.is_merged, d.is_split, dist=1, rev_count=1
	from taxonomy_node_delta d 
	join taxonomy_node p on d.prev_taxid=p.taxnode_id
	join taxonomy_node n on d.new_taxid=n.taxnode_id
	and p.level_id > 100 and n.level_id > 100
	where p.ictv_id <> n.ictv_id
	and p.msl_release_num = n.msl_release_num-1
	and p.is_hidden=0 and n.is_hidden=0

	/*****************************
	 * compute closure 
	 *****************************/
	select 'start closure'; while @@ROWCOUNT > 0 BEGIN
		insert into taxonomy_node_merge_split
		select 
			prev_ictv_id, next_ictv_id
			, is_merged=max(is_merged)
			, is_split=max(is_split)
			, dist=min(dist)
			, rev_count=sum(rev_count)
		from (
			select 
				p.prev_ictv_id
				, n.next_ictv_id
				,is_merged=(p.is_merged+n.is_merged)
				,is_split =(p.is_split +n.is_split)
				,dist     =(p.dist     +n.dist)
				,rev_count=(p.rev_count+n.rev_count)
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
GO