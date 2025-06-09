-- taxonomy_json_rank
LOAD DATA LOCAL INFILE '../../../data//taxonomy_json_rank.utf8.txt'
INTO TABLE taxonomy_json_rank
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  id,
  level_id,
  rank_index,
  rank_name,
  tree_id
);