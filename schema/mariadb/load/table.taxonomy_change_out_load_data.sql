-- taxonomy_change_out
LOAD DATA LOCAL INFILE '../../../data//taxonomy_change_out.utf8.txt'
INTO TABLE taxonomy_change_out
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
`change`,
notes
);

-- SELECT COUNT(*) AS total_count, '7' AS should_be FROM taxonomy_change_out;