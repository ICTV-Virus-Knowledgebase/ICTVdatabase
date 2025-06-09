-- taxonomy_host_source
LOAD DATA LOCAL INFILE '../../../data//taxonomy_host_source.utf8.txt'
INTO TABLE taxonomy_host_source
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
host_source
);

-- SELECT COUNT(*) AS total_count, '26' AS should_be FROM taxonomy_host_source;