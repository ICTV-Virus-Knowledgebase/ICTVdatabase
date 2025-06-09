-- taxonomy_node_merge_split
LOAD DATA LOCAL INFILE '../../../data//taxonomy_node_merge_split.utf8.txt'
INTO TABLE taxonomy_node_merge_split
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  prev_ictv_id,
  next_ictv_id,
  is_merged,
  is_split,
  dist,
  rev_count
);

-- SELECT COUNT(*) AS total_count, '37475' AS should_be FROM taxonomy_node_merge_split;