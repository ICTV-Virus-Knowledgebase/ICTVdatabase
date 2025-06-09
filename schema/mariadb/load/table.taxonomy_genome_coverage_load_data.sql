-- taxonomy_genome_coverage
LOAD DATA LOCAL INFILE '../../../data//taxonomy_genome_coverage.utf8.txt'
INTO TABLE taxonomy_genome_coverage
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
genome_coverage,
name,
priority
);

-- SELECT COUNT(*) AS total_count, '4' AS should_be FROM taxonomy_genome_coverage;
