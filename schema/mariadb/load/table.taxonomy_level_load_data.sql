-- taxonomy_level
LOAD DATA LOCAL INFILE '../../../data/taxonomy_level.utf8.txt'
INTO TABLE taxonomy_level
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  id,
  parent_id,
  `name`,
  plural,
  suffix,
  suffix_viroid,
  suffix_nuc_acid,
  suffix_viriform,
  notes
);

-- SELECT COUNT(*) AS total_count, '16' AS should_be FROM taxonomy_level;