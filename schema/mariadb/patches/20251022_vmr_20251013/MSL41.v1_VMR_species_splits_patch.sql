---------------------------------------------------------------------------------------
-- Procedure:
-- load MSL40v2 database
-- run proposal processor MSL41v1 msl_load.sql
-- run VMR_update_from_new_MSL
-- run this patch to fix species that got split and isolates that otherwise got moved
---------------------------------------------------------------------------------------
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- VMR_update_from_new_MSL needs fixes for species split and creating a new species from the additional isolate of an older species
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

start transaction;

select * from species_isolates si 
where si.genbank_accessions = 'PQ490709';

SET @source_id := 1030540;
SET @destination_id := 1030377;

UPDATE species_isolates AS dst
JOIN species_isolates AS src
  ON src.isolate_id = @source_id
SET
    dst.taxnode_id = src.taxnode_id,
    dst.species_sort = src.species_sort,
    dst.isolate_sort = src.isolate_sort,
    dst.species_name = src.species_name,
    dst.isolate_type = src.isolate_type,
    dst.isolate_names = src.isolate_names,
    dst.isolate_abbrevs = src.isolate_abbrevs,
    dst.isolate_designation = src.isolate_designation,
    dst.refseq_accessions = src.refseq_accessions,
    dst.genome_coverage = src.genome_coverage,
    dst.molecule = src.molecule,
    dst.host_source = src.host_source,
    dst.refseq_organism = src.refseq_organism,
    dst.refseq_taxids = src.refseq_taxids,
    dst.update_change = 'split',
    dst.update_change_proposal = src.update_change_proposal,
    dst.notes = 'hand coded for MSL41.v1'
WHERE dst.isolate_id = @destination_id;

delete from species_isolates as si
where si.isolate_id = @source_id;

select * from species_isolates si 
where si.genbank_accessions = 'PQ490709';

-- rollback;
commit;

-- ----------------------------------------------------------

start transaction;

select * from species_isolates si 
where si.genbank_accessions = 'DQ235151';

SET @source_id := 1031736;
SET @destination_id := 1012799;

UPDATE species_isolates AS dst
JOIN species_isolates AS src
  ON src.isolate_id = @source_id
SET
    dst.taxnode_id = src.taxnode_id,
    dst.species_sort = src.species_sort,
    dst.isolate_sort = src.isolate_sort,
    dst.species_name = src.species_name,
    dst.isolate_type = src.isolate_type,
    dst.isolate_names = src.isolate_names,
    dst.isolate_abbrevs = src.isolate_abbrevs,
    dst.isolate_designation = src.isolate_designation,
    dst.refseq_accessions = src.refseq_accessions,
    dst.genome_coverage = src.genome_coverage,
    dst.molecule = src.molecule,
    dst.host_source = src.host_source,
    dst.refseq_organism = src.refseq_organism,
    dst.refseq_taxids = src.refseq_taxids,
    dst.update_change = 'split',
    dst.update_change_proposal = src.update_change_proposal,
    dst.notes = 'hand coded for MSL41.v1'
WHERE dst.isolate_id = @destination_id;

delete from species_isolates as si
where si.isolate_id = @source_id;

select * from species_isolates si 
where si.genbank_accessions = 'DQ235151';

-- rollback;
commit;

-- ----------------------------------------------------------

start transaction;

select * from species_isolates si 
where si.genbank_accessions in ('U27495', 'JF819648')
or si.species_name like '%zilberi%';

-- Select * from taxonomy_node tn 
-- where tn.genbank_accession_csv in ('U27495', 'JF819648');
-- 
-- select * from taxonomy_node tn 
-- where tn.genbank_accession_csv = 'MG599943';
-- 
-- select * from species_isolates si 
-- where si.genbank_accessions like '%MG599943%';

-- SELECT
--         dx.name AS species_name,
--         'E' AS isolate_type,
--         dx.exemplar_name AS isolate_names,
--         dx.isolate_csv AS isolate_designation,
--         dx.genbank_accession_csv AS genbank_accessions,
--         dx.abbrev_csv AS isolate_abbrevs,
--         dx.taxnode_id,
--         mol.abbrev AS molecule,
--         dx.host_source,
--         gc.name AS genome_coverage,
--         CASE WHEN dx.prev_name IS NULL THEN 'created' ELSE 'updated' END AS update_change,
--         dx.prev_proposal AS update_change_proposal,
--         dx.prev_id AS update_prev_taxnode_id,
--         CASE WHEN dx.prev_name IS NULL THEN 'created' ELSE dx.prev_name END AS update_prev_species
--     FROM taxonomy_node_dx dx
--     LEFT JOIN taxonomy_genome_coverage gc
--       ON gc.genome_coverage = dx.genome_coverage
--     LEFT JOIN taxonomy_molecule mol
--       ON mol.id = dx.inher_molecule_id
--     WHERE dx.msl_release_num = (SELECT MAX(msl_release_num) FROM taxonomy_toc)
--       and dx.genbank_accession_csv is not null
--       and dx.in_change in ('new', 'split')
--       AND dx.level_id = 600
--       AND dx.is_hidden = 0
--       AND NOT EXISTS (
--           SELECT 1
--           FROM species_isolates s
--           -- WHERE s.taxnode_id = dx.taxnode_id
--           where s.genbank_accessions  = dx.genbank_accession_csv 
--           and s.species_name = dx.name 
--             AND s.isolate_type = 'E'
--    );

SET @source_id := 1031735;
SET @destination_id := 1009069;

-- move the zilibri E to make it the the E for neudoerflense

UPDATE species_isolates AS dst
JOIN species_isolates AS src
  ON src.isolate_id = @source_id
SET
    dst.taxnode_id = src.taxnode_id,
    dst.species_sort = src.species_sort,
    dst.isolate_sort = src.isolate_sort,
    dst.species_name = src.species_name,
    dst.isolate_type = src.isolate_type,
    dst.isolate_names = src.isolate_names,
    dst.isolate_abbrevs = src.isolate_abbrevs,
    dst.isolate_designation = src.isolate_designation,
    dst.refseq_accessions = src.refseq_accessions,
    dst.genome_coverage = src.genome_coverage,
    dst.molecule = src.molecule,
    dst.host_source = src.host_source,
    dst.refseq_organism = src.refseq_organism,
    dst.refseq_taxids = src.refseq_taxids,
    dst.update_change = 'split',
    dst.update_change_proposal = src.update_change_proposal,
    dst.notes = 'hand coded for MSL41.v1'
WHERE dst.isolate_id = @destination_id;

-- We just stole the explemplar from zilberi so designate the correct accession as E
UPDATE species_isolates AS dst
JOIN species_isolates AS src
  ON src.isolate_id = @source_id
SET
    dst.isolate_type = src.isolate_type,
    dst.notes = 'hand coded for MSL41.v1'
    
WHERE dst.isolate_id = 1031734;

delete from species_isolates as si
where si.isolate_id = @source_id;

select * from species_isolates si 
where si.genbank_accessions in ('U27495', 'JF819648')
or si.species_name like '%zilberi%';

-- rollback;
commit;

-- ----------------------------------------------------------