-- taxonomy_json
LOAD DATA LOCAL INFILE '../../../data//taxonomy_json.utf8.txt'
INTO TABLE taxonomy_json
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
id,
taxnode_id,
child_counts,
child_json,
has_assigned_siblings,
has_species,
has_unassigned_siblings,
is_ghost_node,
`json`,
parent_distance,
parent_id,
parent_taxnode_id,
rank_index,
source,
tree_id
);