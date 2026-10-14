-- Correct the MSL41 source classification of Orthoflavivirus mediterranense.
-- Requires the repository versions of rebuild_delta_nodes and
-- rebuild_node_merge_split. Run with a client that stops on SQL errors.
-- See README.md for transaction boundaries and recovery instructions.
-- No correction-history row or explanatory database note is added.

DELIMITER $$

BEGIN NOT ATOMIC
    DECLARE v_count INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS mediterranense_protected_deltas;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Accept the original source state or the corrected state (safe rerun).
    SELECT COUNT(*) INTO v_count
    FROM taxonomy_node
    WHERE taxnode_id = 202523330
      AND ictv_id = 202523330
      AND msl_release_num = 41
      AND level_id = 600
      AND name = 'Orthoflavivirus mediterranense'
      AND is_deleted = 0 AND is_hidden = 0
      AND (
          (in_change = 'split' AND in_target =
              'Riboviria;Orthornavirae;Kitrinoviricota;Flasuviricetes;Amarillovirales;Flaviviridae;Orthoflavivirus;Orthoflavivirus encephalitidis')
          OR (in_change = 'new' AND in_target IS NULL)
      );
    IF v_count <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Expected MSL41 mediterranense source row not found; no correction applied';
    END IF;

    -- This patch targets the supplied MSL41 state, not subsequent taxonomy.
    IF EXISTS (
        SELECT 1 FROM taxonomy_node
        WHERE ictv_id = 202523330 AND taxnode_id <> 202523330
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'mediterranense has other release nodes; review patch scope before applying';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM species_isolates
    WHERE taxnode_id = 202523330
      AND species_name = 'Orthoflavivirus mediterranense'
      AND isolate_type = 'E';
    IF v_count <> 1 OR EXISTS (
        SELECT 1 FROM species_isolates
        WHERE (taxnode_id = 202523330 AND species_name <> 'Orthoflavivirus mediterranense')
           OR (species_name = 'Orthoflavivirus mediterranense'
               AND NOT (taxnode_id <=> 202523330))
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Expected reconciled mediterranense VMR rows not found; no correction applied';
    END IF;

    -- These remain splits from encephalitidis, with their existing move flag.
    SELECT COUNT(*) INTO v_count
    FROM taxonomy_node_delta
    WHERE msl = 41
      AND new_taxid IN (202523328, 202523329)
      AND prev_taxid = 202403114
      AND is_split = 1 AND is_new = 0 AND is_moved = 1;
    IF v_count <> 2 OR (
        SELECT COUNT(*) FROM taxonomy_node_delta
        WHERE new_taxid IN (202523328, 202523329)
    ) <> 2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Expected zilberi/neudoerflense split deltas not found; no correction applied';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS mediterranense_protected_deltas;
    CREATE TEMPORARY TABLE mediterranense_protected_deltas AS
        SELECT * FROM taxonomy_node_delta
        WHERE new_taxid IN (202523328, 202523329);

    -- in_target must also be cleared: rebuild_delta_nodes joins it to the
    -- previous release even for an in_change of 'new'. Preserve proposal,
    -- linenum=7 provenance, species notes, identity and all biological data.
    UPDATE taxonomy_node
    SET in_change = 'new', in_target = NULL
    WHERE taxnode_id = 202523330;

    -- Match the new-species convention in VMR_update_from_new_MSL.
    -- Retain isolate IDs/accessions and the existing proposal and editor notes.
    UPDATE species_isolates
    SET update_change = 'created',
        update_prev_species = 'created',
        update_prev_taxnode_id = NULL
    WHERE taxnode_id = 202523330
      AND species_name = 'Orthoflavivirus mediterranense';

    -- Always rebuild the ENTIRE release. p_debug_taxid is not a safe way to
    -- scope this call: the procedure first deletes every delta for the MSL.
    CALL rebuild_delta_nodes(41, NULL, NULL);

    SELECT COUNT(*) INTO v_count
    FROM taxonomy_node_delta
    WHERE msl = 41 AND new_taxid = 202523330
      AND prev_taxid IS NULL
      AND is_new = 1
      AND is_split = 0 AND is_moved = 0 AND is_merged = 0
      AND is_promoted = 0 AND is_demoted = 0 AND is_renamed = 0
      AND is_deleted = 0 AND is_now_type = 0 AND is_lineage_updated = 0;
    IF v_count <> 1 OR (
        SELECT COUNT(*) FROM taxonomy_node_delta WHERE new_taxid = 202523330
    ) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'mediterranense did not rebuild as one New delta; rolling back correction';
    END IF;

    -- Check all columns of the two protected deltas, including provenance.
    IF EXISTS (
        SELECT * FROM mediterranense_protected_deltas
        EXCEPT
        SELECT * FROM taxonomy_node_delta WHERE new_taxid IN (202523328, 202523329)
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A protected split delta changed; rolling back correction';
    END IF;
    IF EXISTS (
        SELECT * FROM taxonomy_node_delta WHERE new_taxid IN (202523328, 202523329)
        EXCEPT
        SELECT * FROM mediterranense_protected_deltas
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'An unexpected protected split delta appeared; rolling back correction';
    END IF;

    DROP TEMPORARY TABLE mediterranense_protected_deltas;
    COMMIT;

    -- Separate phase: this SP starts/commits a transaction and TRUNCATE
    -- implicitly commits. A failure here CANNOT undo the correction above.
    -- Rerun this patch after resolving the failure to complete the rebuild.
    CALL rebuild_node_merge_split();

    -- A newly created species has its identity entry only. The rebuild removes
    -- the false forward, reverse and transitive links, including sibling links.
    IF EXISTS (
        SELECT 1 FROM taxonomy_node_merge_split
        WHERE (prev_ictv_id = 202523330 OR next_ictv_id = 202523330)
          AND prev_ictv_id <> next_ictv_id
    ) OR (
        SELECT COUNT(*) FROM taxonomy_node_merge_split
        WHERE prev_ictv_id = 202523330 AND next_ictv_id = 202523330
          AND is_split = 0 AND is_merged = 0 AND is_recreated = 0
          AND dist = 0 AND rev_count = 0
    ) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Correction committed, but mediterranense relationship rebuild needs review';
    END IF;

    -- No sort inputs changed; species_isolates_update_sorts is unnecessary.
    -- Do not rerun VMR_update_from_new_MSL: it resets VMR tracking globally.
    SELECT 'Orthoflavivirus mediterranense corrected to a new species' AS result;
END $$

DELIMITER ;
