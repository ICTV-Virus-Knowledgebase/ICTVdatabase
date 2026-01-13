-- taxonomy_change_in
LOAD DATA LOCAL INFILE '../../../data/taxonomy_change_in.utf8.txt'
INTO TABLE taxonomy_change_in
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