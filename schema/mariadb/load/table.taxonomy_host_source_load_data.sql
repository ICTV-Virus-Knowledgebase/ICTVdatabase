-- taxonomy_host_source
LOAD DATA LOCAL INFILE '../../../data/taxonomy_host_source.utf8.txt'
INTO TABLE taxonomy_host_source
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY "'"
ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
host_source
);