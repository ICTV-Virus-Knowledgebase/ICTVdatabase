-- taxonomy_node_delta
LOAD DATA LOCAL INFILE '../../../data//taxonomy_node_delta.utf8.osx.txt'
INTO TABLE taxonomy_node_delta
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  prev_taxid,
  new_taxid,
  proposal,
  notes,
  is_merged,
  is_split,
  is_moved,
  is_promoted,
  is_demoted,
  is_renamed,
  is_new,
  is_deleted,
  is_now_type,
  @dummy_tag_csv,          
  is_lineage_updated,
  msl,
  @dummy_tag_csv2,         
  @dummy_tag_csv_min
)
SET 
  tag_csv = NULL,
  tag_csv2 = NULL,
  tag_csv_min = NULL;

SELECT COUNT(*) AS total_count, '153849' AS should_be FROM taxonomy_node_delta;