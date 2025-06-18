
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[QC_module_taxonomy_node_suffixes]
	@filter varchar(1000) = 'ERROR%' 
AS
-- 
-- 5. qc taxon suffixes.sql
--
-- QC suffixes: list all non-compliant taxa
--
-- taxonomy_node.name is compared to the suffixes listed in taxonomy_level 
--
-- species names are NOT checked, as taxonomy_level.suffix=NULL for species.
--
-- by default, only 'ERROR' results are returned. 
--
-- TEST
--    -- list all errors
--    exec [QC_module_taxonomy_node_suffixes]
--    -- list all
--    exec [QC_module_taxonomy_node_suffixes] 'OK%'
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
--
select qc_module=OBJECT_NAME(@@PROCID), 
		src.* 
from (
	select tn.msl_release_num, tn.left_idx, tn.tree_id, tn.taxnode_id, tn.name, tn.level_id
		, [rank]=lvl.name, lvl.suffix, lvl.suffix_viroid, lvl.suffix_nuc_acid, lvl.suffix_viriform
		, mesg=(case
			when tn.name like '%'+lvl.suffix then 'OK: suffix = '+lvl.suffix 
			when tn.name like '%'+lvl.suffix_viroid then 'OK: suffix_viriod = '+lvl.suffix_viroid
			when tn.name like '%'+lvl.suffix_nuc_acid then 'OK: suffix_nuc_acid = '+lvl.suffix_nuc_acid
			when tn.name like '%'+lvl.suffix_viriform then 'OK: suffix_viriform = '+lvl.suffix_viriform
			when tn.msl_release_num < 32 and lvl.name in ('genus'         ) and tn.name like '%virus _' then 'OK: (historic pre-MSL32) "Influenza virus *" genus'
			when tn.msl_release_num < 32 and lvl.name in ('genus'         ) and tn.name like '%viruses' then 'OK: (historic pre-MSL32) "*viruses"'
			when tn.msl_release_num < 32 and lvl.name in ('genus','family') and tn.name like '%phages'  then 'OK: (historic pre-MSL32) "*phages"'
			when tn.msl_release_num < 32 and lvl.name in ('genus'         ) and tn.name like '%phage'   then 'OK: (historic pre-MSL32) "*phage"'
			when tn.msl_release_num < 32 and lvl.name in ('genus'         ) and tn.name like '%genus%'   then 'OK: (historic pre-MSL32) "*genus*"'
			when tn.msl_release_num < 32 and lvl.name in (        'family') and tn.name like '%family'   then 'OK: (historic pre-MSL32) "*family"'
			when tn.msl_release_num < 32 and lvl.name in ('genus','family') and tn.name like '%group%'  then 'OK: (historic pre-MSL32) "*group*"'
			when tn.msl_release_num < 32 and lvl.name in ('genus'         ) and tn.name like '%viroids%' then 'OK: (historic pre-MSL32) "*viroids"*'
			when tn.msl_release_num < 32 and lvl.name in (        'family') and tn.name like '%viroids%' then 'OK: (historic pre-MSL32) "*viroids*"'
			when tn.msl_release_num < 32 and lvl.name in ('genus'         ) and tn.name = 'Influenza virus A and B' then 'OK: (historic pre-MSL32) "Influenza virus A and B"'
			when tn.msl_release_num < 32 and lvl.name in ('genus'         ) and tn.name = 'Lipid phage PM2' then 'OK: (historic pre-MSL32) "Lipid phage PM2"'
			when tn.msl_release_num < 38 and lvl.name in ('genus'         ) and tn.name = 'Tunggulviirus' then 'OK: (historic pre-MSL38) "Tunggulviirus" (typo)'
			when tn.msl_release_num < 38 and lvl.name in ('genus'         ) and tn.name = 'Incheonvrus' then 'OK: (historic pre-MSL38) "Incheonvrus" (typo)'
			else 'ERROR: SUFFIX MISMATCH - look in taxonomy_level for legal suffix lists' end)
	from taxonomy_node tn 
	join taxonomy_level lvl on lvl.id = tn.level_id
	where tn.msl_release_num is not null
	and  tn.name is not null and  tn.name not in ('Unassigned') 
	and lvl.suffix is not null
/*	and not ( 
		tn.name like '%'+lvl.suffix 
		or 
		tn.name like '%'+lvl.suffix_viroid 
		or 
		tn.name like '%'+lvl.suffix_nuc_acid
		or 
		tn.name like '%'+lvl.suffix_viriform
	)
*/
) as src
where mesg like @filter
order by msl_release_num desc, left_idx

GO


