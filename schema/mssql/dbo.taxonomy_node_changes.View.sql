
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- select * from taxonomy_node_changes
CREATE view [dbo].[taxonomy_node_changes] as
--
-- https://uab-lefkowitz.atlassian.net/browse/IVK-201
--
-- all ictv_ids in all msl, with in/out change lists 
-- 
-- to be used to generate a history grid in R or elsewhere.
--
-- 639578 rows
--
--


/* debug
--
-- collapse list of changes into a single string with embedded counts
--
select STRING_AGG(ct_tag,'|')
from (
	select id=d.prev_taxid, ct_tag=tag_csv+(case when count(*)>1 then '(N='+rtrim(count(*))+')' else '' end)
	from taxonomy_node_delta d where d.prev_taxid = 20026243 group by d.prev_taxid,d.tag_csv
) as tags
group by id
*/

--
select *
from (
	select 
		bone.*
		-- change going out
		--,next_tag =STRING_AGG(nd.tag_csv,'|')
		,next_tag = (select STRING_AGG(ct_tag,'|') from (
						select top 500
							id=d.prev_taxid,
							ct_tag=
								left(tag_csv_min,(case when tag_csv_min='' then 1 else len(tag_csv_min)-1 end))
								+(case when count(*)>1 then '(N='+rtrim(count(*))+')' else '' end)
						from taxonomy_node_delta d where d.prev_taxid = n.taxnode_id 
						group by d.prev_taxid,d.tag_csv_min
						order by d.tag_csv_min
				) as tags group by id)
		,next_tag_ct = (select count(tag_csv) from taxonomy_node_delta d where d.prev_taxid = n.taxnode_id group by d.prev_taxid)
		-- this msl
		,left_idx = n.left_idx
		,taxnode_id = n.taxnode_id
		,rank = n.rank
		,name=n.name
		-- change coming in
		--,prev_tag=STRING_AGG(pd.tag_csv,'|')
		--,prev_tag = (select STRING_AGG(tag_csv,'|') from taxonomy_node_delta d where d.new_taxid = n.taxnode_id group by d.new_taxid)
		,prev_tag = (select replace(
							STRING_AGG(ct_tag,'|')
							,',(','(')
						from (
						select top 500
						 	id=d.new_taxid,
							ct_tag=
								left(tag_csv_min,(case when tag_csv_min='' then 1 else len(tag_csv_min)-1 end))
								+(case when count(*)>1 then '(N='+rtrim(count(*))+')' else '' end)
						from taxonomy_node_delta d where d.new_taxid = n.taxnode_id 
						group by d.new_taxid,d.tag_csv_min
						order by d.tag_csv_min
				) as tags group by id)
		,prev_tag_ct = (select count(tag_csv) from taxonomy_node_delta d where d.new_taxid = n.taxnode_id group by d.new_taxid)
	from (
		select 
			-- all IDs
			ids.ictv_id
			-- msl
			,msl.msl
		from (
			select ictv_id
			from taxonomy_node_names
			where msl is not null
			group by ictv_id
		) as ids,
		(	
			select msl=msl_release_num 
			from taxonomy_toc
			where msl_release_num is not null
			group by msl_release_num
		) as msl
	) as bone
	left outer join taxonomy_node_names n on n.msl_release_num = bone.msl and n.ictv_id = bone.ictv_id
	--left outer join taxonomy_node_delta pd on pd.new_taxid = n.taxnode_id
	--left outer join taxonomy_node_delta nd on nd.prev_taxid = n.taxnode_id
	group by bone.msl, bone.ictv_id, n.taxnode_id, n.left_idx, n.rank, n.name
) src
-- debug - just splits/merges
--where next_tag_ct >2 or prev_tag_ct >2
--order by next_tag desc
--order by msl DESC, left_idx

GO

