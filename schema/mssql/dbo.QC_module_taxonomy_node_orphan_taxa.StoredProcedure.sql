
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[QC_module_taxonomy_node_orphan_taxa]
	@filter varchar(1000) = 'ERROR%' 
AS
-- 
-- Identify taxa that are not correctly linked into the annual taxonomy tree
--
--
-- TEST
--    -- list all errors
--    exec [QC_module_taxonomy_node_orphan_taxa]
--    -- list all
--    exec [QC_module_taxonomy_node_orphan_taxa] 'OK%'
--    -- report on all the suffixes used
/*
-- Step 1: Create the temporary table and populate it with the stored procedure's output
CREATE TABLE #suffixes ( 
	qc_module NVARCHAR(255),
	msl_release_num int,
	left_idx int,
	tree_id int,
	taxnode_id int ,
	name NVARCHAR(255),
	level_id int,
	[rank] NVARCHAR(50), 
	suffix NVARCHAR(255), 
	suffix_viroid  NVARCHAR(255),
	suffix_nuc_acid  NVARCHAR(255), 
	suffix_viriform  NVARCHAR(255),
    mesg NVARCHAR(255)
);
GO
-- Step 2: Insert the output of the stored procedure into the temporary table
TRUNCATE TABLE #suffixes
INSERT INTO #suffixes 
EXEC QC_module_taxonomy_node_suffixes 'OK%';
GO
-- Step 2: Query the temporary table with grouping and ordering
SELECT  level_id,  rank, mesg,  COUNT(*) AS ct
FROM #suffixes
GROUP BY  level_id,  rank,  mesg
ORDER BY level_id, mesg;
GO
-- Optional: Drop the temporary table
DROP TABLE #suffixes;
*/
-- DEBUG DECLARE @filter varchar(50); SET @filter= 'ERROR%' 
select qc_module=OBJECT_NAME(@@PROCID), 
		src.* 
from (
	select tn.msl_release_num, tn.taxnode_id, tn.name, tn.level_id, tn.left_idx, tn.right_idx, tn.parent_id, parent_name=p.name
		, [rank]=lvl.name
		, mesg=(case
			when tn.left_idx IS NULL then 'ERROR: left_idx = NULL'
			when tn.right_idx IS NULL then 'ERROR: right_idx = NULL'
			else 'OK: left and right idx' end)
	from taxonomy_node tn 
	join taxonomy_level lvl on lvl.id = tn.level_id
	left outer join taxonomy_node p on p.taxnode_id = tn.parent_id
	where tn.msl_release_num is not null
) as src
where mesg like @filter
order by msl_release_num desc, left_idx

GO


