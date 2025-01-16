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
  is_lineage_updated,
  msl
);