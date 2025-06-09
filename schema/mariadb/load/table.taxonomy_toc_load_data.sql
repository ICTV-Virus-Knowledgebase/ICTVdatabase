-- taxonomy_toc
LOAD DATA LOCAL INFILE '../../../data//taxonomy_toc.utf8.txt'
INTO TABLE taxonomy_toc
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  tree_id,
  msl_release_num,
  comments
);

-- SELECT COUNT(*) AS total_count, '41' AS should_be FROM taxonomy_toc;