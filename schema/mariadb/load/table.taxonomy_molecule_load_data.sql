-- taxonomy_molecule
LOAD DATA LOCAL INFILE '../../../data/taxonomy_molecule.utf8.txt'
INTO TABLE taxonomy_molecule
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  id,
  abbrev,
  `name`,
  balt_group,
  balt_roman,
  `description`,
  left_idx,
  right_idx
);

-- SELECT COUNT(*) AS total_count, '16' AS should_be FROM taxonomy_molecule;