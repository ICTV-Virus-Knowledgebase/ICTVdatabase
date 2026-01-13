-- taxonomy_change_out
LOAD DATA LOCAL INFILE '../../../data/taxonomy_change_out.utf8.txt'
INTO TABLE taxonomy_change_out
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY "'"
ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
`change`,
notes
);