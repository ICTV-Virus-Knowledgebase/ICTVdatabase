CREATE TABLE `taxonomy_node` (
  `taxnode_id` INT NOT NULL,
  `parent_id` INT,
  `tree_id` INT NOT NULL,
  `msl_release_num` INT,
  `level_id` INT,
  `name` VARCHAR(100),
  `ictv_id` INT,
  `molecule_id` INT,
  `abbrev_csv` LONGTEXT,
  `genbank_accession_csv` LONGTEXT,
  `genbank_refseq_accession_csv` LONGTEXT,
  `refseq_accession_csv` LONGTEXT,
  `isolate_csv` LONGTEXT,
  `notes` LONGTEXT,
  `is_ref` INT NOT NULL,
  `is_official` INT NOT NULL,
  `is_hidden` INT NOT NULL,
  `is_deleted` INT NOT NULL,
  `is_deleted_next_year` INT NOT NULL,
  `is_typo` INT NOT NULL,
  `is_renamed_next_year` INT NOT NULL,
  `is_obsolete` INT NOT NULL,
  `in_change` VARCHAR(10),
  `in_target` VARCHAR(255),
  `in_filename` VARCHAR(255),
  `in_notes` LONGTEXT,
  `out_change` VARCHAR(10),
  `out_target` VARCHAR(255),
  `out_filename` VARCHAR(255),
  `out_notes` LONGTEXT,
  `start_num_sort` INT,
  `row_num` VARCHAR(25),
  `filename` VARCHAR(255),
  `xref` VARCHAR(255),
  `realm_id` INT,
  `realm_kid_ct` INT,
  `realm_desc_ct` INT,
  `subrealm_id` INT,
  `subrealm_kid_ct` INT,
  `subrealm_desc_ct` INT,
  `kingdom_id` INT,
  `kingdom_kid_ct` INT,
  `kingdom_desc_ct` INT,
  `subkingdom_id` INT,
  `subkingdom_kid_ct` INT,
  `subkingdom_desc_ct` INT,
  `phylum_id` INT,
  `phylum_kid_ct` INT,
  `phylum_desc_ct` INT,
  `subphylum_id` INT,
  `subphylum_kid_ct` INT,
  `subphylum_desc_ct` INT,
  `class_id` INT,
  `class_kid_ct` INT,
  `class_desc_ct` INT,
  `subclass_id` INT,
  `subclass_kid_ct` INT,
  `subclass_desc_ct` INT,
  `order_id` INT,
  `order_kid_ct` INT,
  `order_desc_ct` INT,
  `suborder_id` INT,
  `suborder_kid_ct` INT,
  `suborder_desc_ct` INT,
  `family_id` INT,
  `family_kid_ct` INT,
  `family_desc_ct` INT,
  `subfamily_id` INT,
  `subfamily_kid_ct` INT,
  `subfamily_desc_ct` INT,
  `genus_id` INT,
  `genus_kid_ct` INT,
  `genus_desc_ct` INT,
  `subgenus_id` INT,
  `subgenus_kid_ct` INT,
  `subgenus_desc_ct` INT,
  `species_id` INT,
  `species_kid_ct` INT,
  `species_desc_ct` INT,
  `taxa_kid_cts` VARCHAR(200),
  `taxa_desc_cts` VARCHAR(200),
  `inher_molecule_id` INT,
  `left_idx` INT,
  `right_idx` INT,
  `node_depth` INT,
  `lineage` VARCHAR(500),
  `cleaned_name` VARCHAR(100) GENERATED ALWAYS AS (
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    REPLACE(REPLACE(`name`, 'í', 'i'), 'é', 'e'), 'ó', 'o'), 'ú', 'u'), 'á', 'a'),
    'ì', 'i'), 'è', 'e'), 'ò', 'o'), 'ù', 'u'), 'à', 'a'), 'î', 'i'), 'ê', 'e'),
    'ô', 'o'), 'û', 'u'), 'â', 'a'), 'ü', 'u'), 'ö', 'o'), 'ï', 'i'), 'ë', 'e'),
    'ä', 'a'), 'ç', 'c'), 'ñ', 'n'), '‘', ''''), '’', ''''), '`', ' '), '  ', ' '),
    'ā', 'a'), 'ī', 'i'), 'ĭ', 'i'), 'ǎ', 'a'), 'ē', 'e'), 'ō', 'o')
  ) PERSISTENT,
  `cleaned_problem` VARCHAR(100) GENERATED ALWAYS AS (
    CASE 
      WHEN INSTR(`name`, 'í') > 0 THEN 'í (accented i)'
      WHEN INSTR(`name`, 'é') > 0 THEN 'é (accented e)'
      WHEN INSTR(`name`, 'ó') > 0 THEN 'ó (accented o)'
      WHEN INSTR(`name`, 'ú') > 0 THEN 'ú (accented u)'
      WHEN INSTR(`name`, 'á') > 0 THEN 'á (accented a)'
      WHEN INSTR(`name`, 'ì') > 0 THEN 'ì (accented i)'
      WHEN INSTR(`name`, 'è') > 0 THEN 'è (accented e)'
      WHEN INSTR(`name`, 'ò') > 0 THEN 'ò (accented o)'
      WHEN INSTR(`name`, 'ù') > 0 THEN 'ù (accented u)'
      WHEN INSTR(`name`, 'à') > 0 THEN 'à (accented a)'
      WHEN INSTR(`name`, 'î') > 0 THEN 'î (accented i)'
      WHEN INSTR(`name`, 'ê') > 0 THEN 'ê (accented e)'
      WHEN INSTR(`name`, 'ô') > 0 THEN 'ô (accented o)'
      WHEN INSTR(`name`, 'û') > 0 THEN 'û (accented u)'
      WHEN INSTR(`name`, 'â') > 0 THEN 'â (accented a)'
      WHEN INSTR(`name`, 'ü') > 0 THEN 'ü (accented u)'
      WHEN INSTR(`name`, 'ö') > 0 THEN 'ö (accented o)'
      WHEN INSTR(`name`, 'ï') > 0 THEN 'ï (accented i)'
      WHEN INSTR(`name`, 'ë') > 0 THEN 'ë (accented e)'
      WHEN INSTR(`name`, 'ä') > 0 THEN 'ä (accented a)'
      WHEN INSTR(`name`, 'ç') > 0 THEN 'ç (accented c)'
      WHEN INSTR(`name`, 'ñ') > 0 THEN 'ñ (accented n)'
      WHEN INSTR(`name`, '‘') > 0 THEN '‘ (Microsoft curvy open single-quote)'
      WHEN INSTR(`name`, '’') > 0 THEN '’ (Microsoft curvy close single-quote)'
      WHEN INSTR(`name`, '`') > 0 THEN '` (ASCII back-quote)'
      WHEN INSTR(`name`, '  ') > 0 THEN '(double space)'
      WHEN INSTR(`name`, 'ā') > 0 THEN 'a-macron'
      WHEN INSTR(`name`, 'ī') > 0 THEN 'i-macron'
      WHEN INSTR(`name`, 'ĭ') > 0 THEN 'i-breve'
      WHEN INSTR(`name`, 'ǎ') > 0 THEN 'a-caron'
      WHEN INSTR(`name`, 'ē') > 0 THEN 'e-macron'
      WHEN INSTR(`name`, 'ō') > 0 THEN 'o-macron'
    END
  ) PERSISTENT,
  `flags` VARCHAR(255) GENERATED ALWAYS AS (
    CONCAT(
      CASE WHEN `tree_id` = `taxnode_id` THEN 'root;' ELSE '' END,
      CASE WHEN `is_hidden` = 1 THEN 'hidden;' ELSE '' END,
      CASE WHEN `is_deleted` = 1 THEN 'deleted;' ELSE '' END,
      CASE WHEN `is_deleted_next_year` = 1 THEN 'removed_next_year;' ELSE '' END,
      CASE WHEN `is_typo` = 1 THEN 'typo;' ELSE '' END,
      CASE WHEN `is_renamed_next_year` = 1 THEN 'renamed_next_year;' ELSE '' END,
      CASE WHEN `is_obsolete` = 1 THEN 'obsolete;' ELSE '' END
    )
  ) PERSISTENT,
  `_numKids` INT GENERATED ALWAYS AS (
    ((`right_idx` - `left_idx`) - 1) / 2
  ) PERSISTENT,
  `_out_target_parent` VARCHAR(255) GENERATED ALWAYS AS (
    RTRIM(LTRIM(REVERSE(SUBSTRING(REPLACE(REVERSE(`out_target`), ';', REPEAT(' ', 1000)), 500, 1500))))
  ) PERSISTENT,
  `_out_target_name` VARCHAR(255) GENERATED ALWAYS AS (
    RTRIM(LTRIM(REVERSE(SUBSTRING(REPLACE(REVERSE(`out_target`), ';', REPEAT(' ', 1000)), 0, 500))))
  ) PERSISTENT,
  `exemplar_name` VARCHAR(255),
  `genome_coverage` VARCHAR(50),
  `host_source` VARCHAR(50),
  PRIMARY KEY (`taxnode_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Foreign Key Constraints
ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_change_in
FOREIGN KEY (in_change)
REFERENCES taxonomy_change_in (`change`);

ALTER TABLE taxonomy_node 
ADD CONSTRAINT FK_taxonomy_node_taxonomy_change_out 
FOREIGN KEY (out_change) REFERENCES taxonomy_change_out (`change`);

ALTER TABLE taxonomy_node 
ADD CONSTRAINT FK_taxonomy_node_taxonomy_genome_coverage 
FOREIGN KEY (genome_coverage) REFERENCES taxonomy_genome_coverage (genome_coverage);

ALTER TABLE taxonomy_node 
ADD CONSTRAINT FK_taxonomy_node_taxonomy_host_source 
FOREIGN KEY (host_source) REFERENCES taxonomy_host_source (host_source);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_level_level_id
FOREIGN KEY (level_id)
REFERENCES taxonomy_level (id)
ON DELETE CASCADE;

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_molecule_inher_molecule_id
FOREIGN KEY (inher_molecule_id)
REFERENCES taxonomy_molecule (id);

ALTER TABLE taxonomy_node 
ADD CONSTRAINT FK_taxonomy_node_taxonomy_molecule_molecule_id 
FOREIGN KEY (molecule_id) REFERENCES taxonomy_molecule (id);

ALTER TABLE taxonomy_node 
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_family_id 
FOREIGN KEY (family_id) REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node 
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_genus_id 
FOREIGN KEY (genus_id) REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_ictv_id
FOREIGN KEY (ictv_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_order_id
FOREIGN KEY (order_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_species_id
FOREIGN KEY (species_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_subfamily_id
FOREIGN KEY (subfamily_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_tree_id
FOREIGN KEY (tree_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_class_id
FOREIGN KEY (class_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_kingdom_id
FOREIGN KEY (kingdom_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_phylum_id
FOREIGN KEY (phylum_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_realm_id
FOREIGN KEY (realm_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_subclass_id
FOREIGN KEY (subclass_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_subgenus_id
FOREIGN KEY (subgenus_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_subkingdom_id
FOREIGN KEY (subkingdom_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_suborder_id
FOREIGN KEY (suborder_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_subphylum_id
FOREIGN KEY (subphylum_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_node_subrealm_id
FOREIGN KEY (subrealm_id)
REFERENCES taxonomy_node (taxnode_id);

ALTER TABLE taxonomy_node
ADD CONSTRAINT FK_taxonomy_node_taxonomy_toc
FOREIGN KEY (tree_id, msl_release_num)
REFERENCES taxonomy_toc (tree_id, msl_release_num);