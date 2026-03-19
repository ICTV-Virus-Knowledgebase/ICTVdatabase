/* ================================================================
   Stored procedure  : VMR_update_from_new_MSL
   Converted from    : SQL-Server to MariaDB
   Target            : MariaDB 11.8.x
   Purpose           : Reconcile species_isolates against latest MSL
   ================================================================ */
DELIMITER $$

DROP PROCEDURE IF EXISTS VMR_update_from_new_MSL $$
CREATE PROCEDURE VMR_update_from_new_MSL()
BEGIN
    /* -------------------------------------------------------------
       Baseline row counts before updates
       ------------------------------------------------------------- */
    SELECT
        '[species_isolates]' AS row_count,
        COUNT(*) AS ct,
        COUNT(CASE WHEN update_change = 'abolished' THEN 1 END) AS abolish_ct,
        COUNT(*) - COUNT(CASE WHEN update_change = 'abolished' THEN 1 END) AS ct_non_ab
    FROM species_isolates;

    /* -------------------------------------------------------------
       Move current values into "prev" fields; reset change-tracking
       ------------------------------------------------------------- */
    UPDATE species_isolates
    SET
        update_change = NULL,
        update_change_proposal = NULL,
        update_prev_taxnode_id = taxnode_id,
        update_prev_species = species_name
    WHERE update_change IS NULL
       OR update_change <> 'abolished';

    /* -------------------------------------------------------------
       NO-CHANGE species
       ------------------------------------------------------------- */
    UPDATE species_isolates si
    JOIN taxonomy_node_dx dx
      ON dx.prev_id = si.update_prev_taxnode_id
    SET
        si.species_name = dx.name,
        si.update_change = 'same',
        si.update_change_proposal = NULL,
        si.taxnode_id = dx.taxnode_id
    WHERE si.update_change IS NULL
      AND dx.prev_name = si.update_prev_species
      AND COALESCE(dx.prev_tags, '') = '';

    /* -------------------------------------------------------------
       Normalize legacy rows already marked as abolished but missing
       update_change marker (historical data edge-case)
       ------------------------------------------------------------- */
    UPDATE species_isolates
    SET update_change = 'abolished'
    WHERE update_change IS NULL
      AND species_name = 'abolished';

    /* -------------------------------------------------------------
       RENAMED / MOVED species
       ------------------------------------------------------------- */
    UPDATE species_isolates si
    JOIN taxonomy_node_dx dx
      ON dx.prev_id = si.update_prev_taxnode_id
    SET
        si.species_name = dx.name,
        si.update_change = dx.prev_tags,
        si.update_change_proposal = dx.prev_proposal,
        si.taxnode_id = dx.taxnode_id
    WHERE (dx.prev_tags LIKE '%renamed%' OR dx.prev_tags LIKE '%moved%')
      AND dx.msl_release_num = (SELECT MAX(msl_release_num) FROM taxonomy_toc)
      AND si.update_change IS NULL;

    /* -------------------------------------------------------------
       ABOLISHED species
       Use taxonomy_node_delta because abolished rows are not in
       taxonomy_node_dx
       ------------------------------------------------------------- */
    UPDATE species_isolates si
    JOIN taxonomy_node_delta dx
      ON dx.prev_taxid = si.update_prev_taxnode_id
    SET
        si.species_name = 'abolished',
        si.update_change = 'abolished',
        si.update_change_proposal = dx.proposal,
        si.taxnode_id = dx.new_taxid
    WHERE dx.is_deleted = 1
      AND dx.msl = (SELECT MAX(msl_release_num) FROM taxonomy_toc)
      AND si.update_change IS NULL;

    /* -------------------------------------------------------------
       INSERT newly created/updated species into VMR (E records)
       ------------------------------------------------------------- */
    INSERT INTO species_isolates (
        species_name,
        isolate_type,
        isolate_names,
        isolate_designation,
        genbank_accessions,
        isolate_abbrevs,
        taxnode_id,
        molecule,
        host_source,
        genome_coverage,
        update_change,
        update_change_proposal,
        update_prev_taxnode_id,
        update_prev_species
    )
SELECT
        dx.name AS species_name,
        'E' AS isolate_type,
        dx.exemplar_name AS isolate_names,
        dx.isolate_csv AS isolate_designation,
        dx.genbank_accession_csv AS genbank_accessions,
        dx.abbrev_csv AS isolate_abbrevs,
        dx.taxnode_id,
        mol.abbrev AS molecule,
        dx.host_source,
        gc.name AS genome_coverage,
        CASE WHEN dx.prev_name IS NULL THEN 'created' ELSE 'updated' END AS update_change,
        dx.prev_proposal AS update_change_proposal,
        dx.prev_id AS update_prev_taxnode_id,
        CASE WHEN dx.prev_name IS NULL THEN 'created' ELSE dx.prev_name END AS update_prev_species
    FROM taxonomy_node_dx dx
    LEFT JOIN taxonomy_genome_coverage gc
      ON gc.genome_coverage = dx.genome_coverage
    LEFT JOIN taxonomy_molecule mol
      ON mol.id = dx.inher_molecule_id
    WHERE dx.msl_release_num = (SELECT MAX(msl_release_num) FROM taxonomy_toc)
      and dx.genbank_accession_csv is not null
      and dx.in_change in ('new', 'split')
      AND dx.level_id = 600
      AND dx.is_hidden = 0
      AND NOT EXISTS (
          SELECT 1
          FROM species_isolates s
          -- WHERE s.taxnode_id = dx.taxnode_id
          where s.genbank_accessions  = dx.genbank_accession_csv 
          and s.species_name = dx.name 
            AND s.isolate_type = 'E'
   );

    /* -------------------------------------------------------------
       Enforce one exemplar row per non-abolished species.
       Merge operations can legitimately map multiple previous exemplar
       rows into the same new species; keep one E and demote others to A.
       Preference: keep row where previous species name already matches
       current species_name, then lowest isolate_id.
       ------------------------------------------------------------- */
    UPDATE species_isolates si
    JOIN (
        SELECT
            isolate_id,
            ROW_NUMBER() OVER (
                PARTITION BY species_name
                ORDER BY
                    CASE
                        WHEN update_prev_species = species_name THEN 0
                        ELSE 1
                    END,
                    isolate_id
            ) AS rn
        FROM species_isolates
        WHERE isolate_type = 'E'
          AND species_name <> 'abolished'
    ) x
      ON x.isolate_id = si.isolate_id
    SET si.isolate_type = 'A'
    WHERE x.rn > 1;

    /* -------------------------------------------------------------
       Summary: completed updates
       ------------------------------------------------------------- */
    SELECT
        '[species_isolates] DONE' AS title,
        update_change,
        COUNT(*) AS ct_change
    FROM species_isolates
    GROUP BY update_change;

    /* -------------------------------------------------------------
       Summary: records still unresolved
       ------------------------------------------------------------- */
    SELECT
        '[species_isolates] TODO' AS title,
        delta.tag_csv2,
        COUNT(*) AS ct,
        COUNT(update_prev_taxnode_id) AS ct_old_taxnode_id
    FROM species_isolates si
    LEFT JOIN taxonomy_node_delta delta
      ON si.update_prev_taxnode_id = delta.prev_taxid
    WHERE si.update_change IS NULL
    GROUP BY delta.tag_csv2;

    /* -------------------------------------------------------------
       Report abolished species that still have accessions/coverage
       ------------------------------------------------------------- */
    SELECT
        'abolished exemplars, with genbnak entries' AS report,
        si.*,
        CONCAT('https://ictv.global/ictv/proposals/', si.update_change_proposal) AS proposal_url
    FROM species_isolates si
    WHERE si.update_change = 'abolished'
      AND (
          si.genome_coverage <> 'No entry in Genbank'
          OR si.genbank_accessions <> ''
      );
END $$

DELIMITER ;

-- Run:
-- CALL VMR_update_from_new_MSL();
-- CALL species_isolates_update_sorts();
-- CALL QC_module_vmr_export_species_count(NULL);
