-- load species_isolates data
LOAD DATA LOCAL INFILE '../../../data//species_isolates.utf8.txt'
INTO TABLE species_isolates
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
  isolate_id,
  taxnode_id,
  species_sort,
  isolate_sort,
  species_name,
  isolate_type,
  isolate_names,
  @computed_col,               -- <-- Skip the _isolate_name column
  isolate_abbrevs,
  isolate_designation,
  genbank_accessions,
  refseq_accessions,
  genome_coverage,
  molecule,
  host_source,
  refseq_organism,
  refseq_taxids,
  update_change,
  update_prev_species,
  update_prev_taxnode_id,
  update_change_proposal,
  notes
);

-- check number of rows:
-- SELECT COUNT(*) AS total_count, '16521' AS should_be FROM species_isolates;

-- set auto increment column to the value of the last isolate_id + 1
-- Now compute the next ID in a user variable
SET @autoIncVal := (
  SELECT COALESCE(MAX(isolate_id), 0) + 1
  FROM species_isolates
);

-- Build a dynamic ALTER TABLE statement that uses the literal value
SET @sql = CONCAT('ALTER TABLE species_isolates AUTO_INCREMENT = ', @autoIncVal);

-- Prepare and execute
PREPARE st FROM @sql;
EXECUTE st;
DEALLOCATE PREPARE st;
