-- taxonomy_genome_coverage
LOAD DATA LOCAL INFILE '../../../data/taxonomy_genome_coverage.utf8.txt'
INTO TABLE taxonomy_genome_coverage
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY "'"
ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
genome_coverage,
name,
priority
);
