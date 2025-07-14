
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE view [dbo].[QC_generate_taxonomy_history_binned_test_cases] as 
/*
 -- Build minimal set of test cases for taxonomyHistory web service
 -- 
 -- for MSL40, that's 22209 test cases. 
 --
 -- For each set of merge-split connected ICTV_IDs, choose a "key" ICTV_ID 
 -- (currently the numerically smallest one), 
 -- then pull the taxonomy for the earliest taxon in that ICTV_ID
 -- and use that to create a bin and name for the test case
 --
 -- We create bins, as having 22k+ files in a directory causes performance problems 
 -- with the filesystem, so we use bin_name=ISNULL(family,subfamily,genus)
 -- which gives us  ~900 subdirectories, with the biggest being ~1k files. 
 --
*/ 	
select 

	report='TaxonomyHistory test case generator - one key ICTV_ID per connected ICTV-merge-split set', 
	report_version='v1.bin=family-subfamily-genus', 
	msm.key_ictv_id, msm.ictv_ct, msm.key_taxnode_id,msm.txn_ct
	, bin=(case 
			when (tnn.family = '') and (tnn.subfamily='') and (tnn.genus ='') then 'Unassigned'
			when (tnn.family = '') and (tnn.subfamily='')  then replace(tnn.genus,' ','_')
			when (tnn.family = '')   then replace(tnn.subfamily,' ','_')
			else replace(tnn.family, ' ', '_')
			end)
	, key_taxon = concat('ICTV',key_ictv_id, '=', tnn.rank COLLATE SQL_Latin1_General_CP1_CS_AS,'=',replace(replace(tnn.lineage, ';', '='),' ','_'))
from taxonomy_node_names tnn
join (
	select ms.key_ictv_id, ms.ictv_ct, key_taxnode_id = min(n.taxnode_id), txn_ct=count(*)
	from taxonomy_node n
	join (
		select key_ictv_id, ictv_ct=count(*) 
		from (
			-- for each ictv_id, what's the min one in it's extended group	
			select prev_ictv_id, key_ictv_id= min(next_ictv_id)
			from taxonomy_node_merge_split
			--where prev_ictv_id in (19710002, 19990048, 19990055)
			--or  next_ictv_id in (19710002, 19990048, 19990055)
			group by prev_ictv_id
		) src
		group by key_ictv_id
	) ms on ms.key_ictv_id = n.ictv_id
	group by ms.key_ictv_id, ms.ictv_ct
) as msm on msm.key_taxnode_id=tnn.taxnode_id

/*  
-- show bin count and sizes 

select bin, ct=count(*) 
from QC_generate_taxonomy_history_binned_test_cases
group by bin
order by ct


select * 
from QC_generate_taxonomy_history_binned_test_cases

*/
GO

