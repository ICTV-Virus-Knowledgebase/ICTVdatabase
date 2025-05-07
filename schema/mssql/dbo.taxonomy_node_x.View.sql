
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE view [dbo].[taxonomy_node_x] 
as 

-- test 
--select msl_release_num, taxnode_id, ictv_id, lineage, name, in_change, out_change from (
select node.*
	, target_taxnode_id = target.taxnode_id
	, target_name       = target.name
	, target_lineage    = target.lineage
from taxonomy_node_names target
join taxonomy_node_merge_split ms on 
	target.ictv_id in (ms.prev_ictv_id)
join taxonomy_node_names node on
	node.ictv_id in (ms.next_ictv_id)
-- test
--) as src
--where target_taxnode_id=20113515--(merge)Transmissible gastro-enteritis virus of swine/Alphacoronavirus 1
--where target_taxnode_id=19740224--(merge)Transmissible gastro-enteritis virus of swine/Alphacoronavirus 1
--order by msl_release_num, lineage

/*
-- test view
select msl_release_num, taxnode_id, ictv_id, lineage, name, in_change, out_change 
from [taxonomy_node_x] 
where target_taxnode_id=20113515--(merge)Transmissible gastro-enteritis virus of swine/Alphacoronavirus 1
-- where target_taxnode_id=19740224--(merge)Transmissible gastro-enteritis virus of swine/Alphacoronavirus 1
order by msl_release_num, lineage

--'infectious bovine rhinotracheitis virus'
-- 3 real rows, 3 hidden rows. 
select msl_release_num, taxnode_id, ictv_id, lineage, name, in_change, out_change 
from [taxonomy_node_x] 
where target_taxnode_id=19710341
order by msl_release_num, lineage

*/

GO

