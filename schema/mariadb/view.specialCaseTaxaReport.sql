-- Source: export/report.special_case_taxa.template.xlsx, SQL tab.
-- The source query intentionally includes all releases, not only MSL41.
CREATE OR REPLACE VIEW `specialCaseTaxaReport` AS
--
-- ICTVdatabase: query split, merged, promoted, demoted taxa
--
select msl_release_num,
-- prev
tnd.taxnode_id as prev_id,
tnd.ictv_id as prev_ictv_id,
pr.name as prev_rank,
tnd.name as prev_name,
tnd.genbank_accession_csv as accessions,
-- change
next_tags,
-- current
tnd.next_name as next_name,
nr.name as next_rank,
tnd.next_ictv_id as next_ictv_id,
tnd.next_id as next_id,
-- URLs
CONCAT('=HYPERLINK("https://test.ictv.global/id/TN', tnd.taxnode_id,'","TN',tnd.taxnode_id,'@TEST")') AS test_taxnode_url,
CONCAT('=HYPERLINK("https://test.ictv.global/id/ICTV', tnd.ictv_id,'","ICTV',tnd.ictv_id,'@TEST")') AS test_ictv_url,
CONCAT('=HYPERLINK("https://ictv.global/id/TN', tnd.taxnode_id,'","TN',tnd.taxnode_id,'@prod")') AS prod_taxnode_url,
CONCAT('=HYPERLINK("https://ictv.global/id/ICTV', tnd.ictv_id,'","ICTV',tnd.ictv_id,'@prod")') AS prod_ictv_url
from taxonomy_node_dx tnd
join taxonomy_level pr on pr.id = tnd.level_id
left outer join taxonomy_level nr on nr.id = tnd.next_level
where (
tnd.next_tags like '%moted%'
or tnd.next_tags like '%split%'
or tnd.next_tags like '%merge%'
or tnd.next_tags like '%abolish%'
)
order by tnd.msl_release_num;
