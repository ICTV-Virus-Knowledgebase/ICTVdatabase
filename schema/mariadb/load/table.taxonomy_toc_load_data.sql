-- taxonomy_toc
LOAD DATA LOCAL INFILE '../../../data/taxonomy_toc.utf8.txt'
INTO TABLE taxonomy_toc
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  tree_id,
  msl_release_num,
  version_tag,
  comments
);

-- SELECT COUNT(*) AS total_count, '41' AS should_be FROM taxonomy_toc;