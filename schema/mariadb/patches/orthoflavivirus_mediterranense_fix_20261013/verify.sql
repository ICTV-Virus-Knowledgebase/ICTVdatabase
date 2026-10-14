-- Read-only verification after applying orthoflavivirus_mediterranense_fix.sql.

-- Expect mediterranense: new / NULL. The other two species remain split.
SELECT taxnode_id, ictv_id, name, in_change, in_target, in_filename, in_notes
FROM taxonomy_node
WHERE taxnode_id IN (202523328, 202523329, 202523330)
ORDER BY taxnode_id;

-- Expect mediterranense: NULL predecessor, New, only is_new = 1.
-- Expect zilberi/neudoerflense: predecessor 202403114, Split,Moved,.
SELECT msl, prev_taxid, new_taxid, tag_csv2, is_new, is_split, is_moved,
       proposal, notes
FROM taxonomy_node_delta
WHERE new_taxid IN (202523328, 202523329, 202523330)
ORDER BY new_taxid;

-- Expect exactly one row: identity 202523330 -> 202523330, all counts zero.
SELECT * FROM taxonomy_node_merge_split
WHERE prev_ictv_id = 202523330 OR next_ictv_id = 202523330
ORDER BY prev_ictv_id, next_ictv_id;

-- Expect both valid forward split links from encephalitidis to remain.
SELECT * FROM taxonomy_node_merge_split
WHERE prev_ictv_id = 19790934 AND next_ictv_id IN (202523328, 202523329)
ORDER BY next_ictv_id;

-- Expect created / created / NULL for mediterranense; retain DQ235151 and ID.
SELECT isolate_id, taxnode_id, species_name, isolate_type, genbank_accessions,
       update_change, update_prev_species, update_prev_taxnode_id,
       update_change_proposal, species_sort, isolate_sort, notes
FROM species_isolates
WHERE taxnode_id IN (202523328, 202523329, 202523330)
ORDER BY taxnode_id, isolate_id;
