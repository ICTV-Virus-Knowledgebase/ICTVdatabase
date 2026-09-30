START TRANSACTION;

-- Record both new genera as successors of the same previous-release genus.
UPDATE taxonomy_node
SET in_change = 'split',
    in_target = 'Tombusviridae;Necrovirus'
WHERE msl_release_num = 27
  AND (
      (taxnode_id = 20125728 AND name = 'Alphanecrovirus')
      OR
      (taxnode_id = 20125729 AND name = 'Betanecrovirus')
  );

-- Remove the incorrect abolition annotation.
-- Retain the existing proposal filename and notes.
UPDATE taxonomy_node
SET out_change = NULL,
    out_target = NULL
WHERE taxnode_id = 20111341
  AND msl_release_num = 26
  AND name = 'Necrovirus'
  AND out_change = 'abolish';

-- Record the change as a split in notes and in_notes instead of new.
UPDATE taxonomy_node 
set notes = '2011.009a-mP: split Alphanecrovirus from the genus Necrovirus. Originally misrecorded in the database as new.',
	in_notes = '2011.009a-mP: split Alphanecrovirus from the genus Necrovirus. Originally misrecorded in the database as new.'
WHERE msl_release_num = 27
	AND taxnode_id = 20125728 AND name = 'Alphanecrovirus';

UPDATE taxonomy_node 
set notes = '2011.009a-mP: split Betanecrovirus from the genus Necrovirus. Originally misrecorded in the database as new.',
	in_notes = '2011.009a-mP : split Betanecrovirus from the genus Necrovirus. Originally misrecorded in the database as new.'
WHERE msl_release_num = 27
	AND taxnode_id = 20125729 AND name = 'Betanecrovirus';

-- Rebuild the entire affected release, without debug filtering.
CALL rebuild_delta_nodes(27, NULL, NULL);

COMMIT;

-- Rebuild relationships after committing the source/delta correction.
-- This procedure uses TRUNCATE, which implicitly commits.
CALL rebuild_node_merge_split();