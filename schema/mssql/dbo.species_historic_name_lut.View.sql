
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE view [dbo].[species_historic_name_lut] as 
select
	first_msl=min(old.msl_release_num), last_msl = max(old.msl_release_num), old_name=old.name, old_ictv_id=old.ictv_id
	,action=(case 
		when max(new.taxnode_id) is null then 'abolished'
		when old.name = max(new.name) and old.name = min(new.name) then 'same'
		when old.name <> max(new.name) and max(new.name) = min(new.name) and max(is_merged)=1 then 'renamed/merged'
		when old.name <> max(new.name) and max(new.name) = min(new.name) and max(is_merged)=0 then 'renamed'
		when max(new.name)<>min(new.name) then 'split'
		else 'error' end)
	,  new_msl = max(new.msl_release_num)
	--, count(*)
	, new_name=max(new.name)
	, new_taxnode_id = max(new.taxnode_id)
	, sep2=(case when max(new.name) = min(new.name) then '====' else '<'+rtrim(count(distinct(new.name)))+'>' end)
	, is_merge=max(ms.is_merged), is_split=max(ms.is_split)
	, new_name2=min(new.name)
	, new_taxnode_id2 = min(new.taxnode_id)
	, new_sort=max(new.left_idx)
from taxonomy_node_names old
left outer join taxonomy_node_merge_split ms on (    
	 ms.prev_ictv_id = old.ictv_id 
	 and rev_count =0
)
left outer join taxonomy_node_names new on (      
	 ms.next_ictv_id = new.ictv_id 
	-- put MSL and rank inside join, so we get NULL on abolish
	and new.msl_release_num = (select max(msl_release_num) from taxonomy_toc)
	and new.[rank] = 'species'
)
where
old.msl_release_num is not null 
and old.level_id = 600 
group by old.name, old.ictv_id 
-- QC
--having old.name='Alajuela orthobunyavirus'
--having  'Foot-and-mouth disease virus' in (min(new.name), max(new.name))
	-- split (A & O) and re-merged: (is it legal to re-create this species name?)
	--'Foot-and-mouth disease virus' in (min(new.name), max(new.name))
	--max(ms.is_split) > 0 and max(ms.is_merged) > 0
	--count(distinct(new.name))>0 and max(ms.is_merged) > 0
	-- this displays a duplicate entry in MSL18, but isn't duplicated in taxonomy_node!
	--'Teseptimavirus T7' in (min(new.name), max(new.name), old.name)
--order by max(new.left_idx)
GO

