/* ------------------------------------------------------------------
    (LRM 07172025)
    This view is used to generate the columns/data needed to test
    get‑taxon‑history web service with ICTVweb_unit_tests.
    Note: It only includes the case_url column for the SQL Server version.
   ------------------------------------------------------------------ */

CREATE OR REPLACE VIEW `QC_generate_taxonomy_history_binned_test_cases` AS
SELECT
  /* ---------------------------------------------------------------
     Build minimal set of test cases for taxonomyHistory web service

     ‑ For MSL40, that’s 22 209 test cases.
     ‑ For each set of merge‑split‑connected ICTV_IDs, choose a “key”
       ICTV_ID (the numerically smallest one).
     ‑ Pull the taxonomy for the earliest taxon in that ICTV_ID and
       use that to create a bin and name for the test case.

     We create bins, as having 22 k+ files in a directory causes
     performance problems with the filesystem, so we use
         bin_name = IFNULL(family, subfamily, genus)
     which yields ≈900 sub‑directories, the largest ≈1 k files.
     ---------------------------------------------------------------- */

  /* ----- literal columns (alias AFTER the expression in MariaDB) -- */
  'TaxonomyHistory test case generator - one key ICTV_ID per connected ICTV‑merge‑split set' AS report,
  'v1.bin=family-subfamily-genus'                                                             AS report_version,

  /* ----- columns from the derived‑table join ---------------------- */
  msm.key_ictv_id,
  msm.ictv_ct,
  msm.key_taxnode_id,
  msm.txn_ct,

  /* ----- bin name ------------------------------------------------- */
  CASE
    WHEN tnn.family = '' AND tnn.subfamily = '' AND tnn.genus = '' THEN 'Unassigned'
    WHEN tnn.family = '' AND tnn.subfamily = ''                    THEN REPLACE(tnn.genus     ,' ', '_')
    WHEN tnn.family = ''                                           THEN REPLACE(tnn.subfamily ,' ', '_')
    ELSE                                                                 REPLACE(tnn.family    ,' ', '_')
  END                                                               AS bin,

  /* ----- key_taxon (convert / → _ as well) ------------------------ */
  REPLACE(
    CONCAT(
      'ICTV', msm.key_ictv_id, '=',
      tnn.`rank` COLLATE utf8mb4_bin, '=',
      REPLACE( REPLACE(tnn.lineage, ';', '='), ' ', '_' )
    ),
    '/', '_'
  ) AS key_taxon,

  /* ----- extra columns used by the Python test‑suite -------------- */
  'taxonomy'                                   AS unit_name,
  REPLACE(
    CONCAT('taxonomyHistoryRegression_', REPLACE(tnn.name, ' ', '_')),
    '/', '_'
  )                                            AS case_name,
  CONCAT(
    '/api/taxonomyHistory.ashx?action_code=get_taxon_history',
    '&current_release=40',
    '&taxnode_id=', msm.key_taxnode_id
  )                                            AS case_url

FROM taxonomy_node_names AS tnn
JOIN (
  /* ---------------------------------------------------------------
     ms = one row per merge‑split–connected set
     msm = add first taxnode + counts per set
     --------------------------------------------------------------- */
  SELECT
    ms.key_ictv_id,
    ms.ictv_ct,
    MIN(n.taxnode_id) AS key_taxnode_id,
    COUNT(*)          AS txn_ct
  FROM taxonomy_node AS n
  JOIN (
    SELECT
      key_ictv_id,
      COUNT(*) AS ictv_ct
    FROM (
      SELECT
        prev_ictv_id,
        MIN(next_ictv_id) AS key_ictv_id
      FROM taxonomy_node_merge_split
      GROUP BY prev_ictv_id
    ) AS src
    GROUP BY key_ictv_id
  ) AS ms
    ON ms.key_ictv_id = n.ictv_id
  GROUP BY ms.key_ictv_id, ms.ictv_ct
) AS msm
  ON msm.key_taxnode_id = tnn.taxnode_id;
