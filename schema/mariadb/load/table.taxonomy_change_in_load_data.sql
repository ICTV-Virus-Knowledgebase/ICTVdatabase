-- taxonomy_change_in
LOAD DATA LOCAL INFILE '../../../data//taxonomy_change_in.utf8.osx.txt'
INTO TABLE taxonomy_change_in
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
`change`,
notes
);

SELECT COUNT(*) AS total_count, '2' AS should_be FROM taxonomy_change_in;