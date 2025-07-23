
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

----------------------------------------------------------------------------------
-- (LRM 07172025)
-- This view is used to generate the columns/data needed to test get-taxon-history
-- web service with ICTVweb_unit_tests. 

-- Note: It only includes the case_url column for the SQL Server version.
-- I will add an additional case_url column for MariaDB.
----------------------------------------------------------------------------------

CREATE   VIEW [dbo].[QC_generate_taxonomy_history_binned_test_cases] AS
SELECT
    ---------------------------------------------------------------------------
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
    ---------------------------------------------------------------------------
    report         = 'TaxonomyHistory test case generator - one key ICTV_ID per connected ICTV-merge-split set',
    report_version = 'v1.bin=family-subfamily-genus',
    msm.key_ictv_id,
    msm.ictv_ct,
    msm.key_taxnode_id,
    msm.txn_ct,

    bin = CASE
            WHEN tnn.family   = '' AND tnn.subfamily = '' AND tnn.genus = '' THEN 'Unassigned'
            WHEN tnn.family   = '' AND tnn.subfamily = ''                   THEN REPLACE(tnn.genus,      ' ', '_')
            WHEN tnn.family   = ''                                         THEN REPLACE(tnn.subfamily, ' ', '_')
            ELSE REPLACE(tnn.family, ' ', '_')
          END,

    ---------------------------------------------------------------------------
    -- key_taxon : also replace “/” with “_”
    ---------------------------------------------------------------------------
    key_taxon = REPLACE(
                  CONCAT(
                     'ICTV', key_ictv_id, '=',
                     tnn.rank COLLATE SQL_Latin1_General_CP1_CS_AS, '=',
                     REPLACE(
                         REPLACE(tnn.lineage, ';', '='),
                         ' ', '_'
                     )
                  ),
                  '/', '_'
                ),

    ---------------------------------------------------------------------------
    -- Add unit_name, case_name, and case_url columns for python testing
    ---------------------------------------------------------------------------
    unit_name = 'taxonomy',

    case_name = REPLACE(
                   CONCAT(
                      'taxonomyHistoryRegression_',
                      REPLACE(tnn.name, ' ', '_')
                   ),
                   '/', '_'
                 ),

    case_url  = CONCAT(
                   '/api/taxonomyHistory.ashx?action_code=get_taxon_history',
                   '&current_release=40',
                   '&taxnode_id=', msm.key_taxnode_id
                 )

FROM taxonomy_node_names tnn
JOIN (
    SELECT
        ms.key_ictv_id,
        ms.ictv_ct,
        key_taxnode_id = MIN(n.taxnode_id),
        txn_ct         = COUNT(*)
    FROM taxonomy_node n
    JOIN (
        SELECT key_ictv_id, ictv_ct = COUNT(*)
        FROM (
            SELECT prev_ictv_id,
                   key_ictv_id = MIN(next_ictv_id)
            FROM taxonomy_node_merge_split
            GROUP BY prev_ictv_id
        ) src
        GROUP BY key_ictv_id
    ) ms
      ON ms.key_ictv_id = n.ictv_id
    GROUP BY ms.key_ictv_id, ms.ictv_ct
) AS msm
  ON msm.key_taxnode_id = tnn.taxnode_id;
GO

