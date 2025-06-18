
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create function [dbo].[get_taxon_names_in_msl](@name nvarchar(250),@msl int)
RETURNS TABLE
AS
RETURN 
(
--
-- find most recent name for an obsolete taxon name
--
/*
-- test
select * from dbo.get_taxon_names_in_msl('Bovine enterovirus', 8)
select * from dbo.get_taxon_names_in_msl('Bovine enterovirus', 38)
*/
select sd.old_msl, sd.old_name, sd.new_count, dest.name
from (
	select top 1
		old_msl=src.msl_release_num, old_name=src.name, old_ictv_id=src.ictv_id
		, new_msl=dest.msl_release_num
		, new_count=count(distinct(dest.name))
		, new_name=(case when count(distinct(dest.name))>1 then 'multiple' else max(dest.name)  end)
	from taxonomy_node src
	join taxonomy_node_merge_split ms on ms.prev_ictv_id=src.ictv_id
	join taxonomy_node dest on dest.ictv_id = ms.next_ictv_id
	where src.name = @name
	and dest.msl_release_num=@msl
	and ms.rev_count = 0
	group by 
		src.msl_release_num, src.name, src.ictv_id
		, dest.msl_release_num
	order by new_msl desc, old_msl desc
) as sd
join taxonomy_node_merge_split ms on ms.prev_ictv_id=sd.old_ictv_id
join taxonomy_node dest on dest.ictv_id = ms.next_ictv_id
	and ms.rev_count = 0
	and dest.msl_release_num = sd.new_msl
)

GO


