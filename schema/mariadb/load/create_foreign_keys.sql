
-- taxonomy_level
ALTER TABLE `taxonomy_level`
  ADD CONSTRAINT `FK_taxonomy_level_taxonomy_level` 
  FOREIGN KEY (`parent_id`) REFERENCES `taxonomy_level` (`id`);

-- taxonomy_node_merge_split
ALTER TABLE `taxonomy_node_merge_split`
    ADD CONSTRAINT `FK_taxonomy_node_merge_split_taxonomy_node1` 
    FOREIGN KEY (`next_ictv_id`) 
    REFERENCES `taxonomy_node` (`taxnode_id`) 
    ON UPDATE CASCADE 
    ON DELETE CASCADE;

-- species_isolates
ALTER TABLE `species_isolates` 
ADD CONSTRAINT `FK_species_isolates_taxonomy_genome_coverage` 
FOREIGN KEY (`genome_coverage`) 
REFERENCES `taxonomy_genome_coverage` (`name`);

ALTER TABLE `species_isolates` 
ADD CONSTRAINT `FK_species_isolates_taxonomy_host_source` 
FOREIGN KEY (`host_source`) 
REFERENCES `taxonomy_host_source` (`host_source`);

ALTER TABLE `species_isolates` 
ADD CONSTRAINT `FK_species_isolates_taxonomy_molecule` 
FOREIGN KEY (`molecule`) 
REFERENCES `taxonomy_molecule` (`abbrev`);

ALTER TABLE `species_isolates` 
ADD CONSTRAINT `FK_species_isolates_taxonomy_node` 
FOREIGN KEY (`taxnode_id`) 
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `species_isolates` 
ADD CONSTRAINT `FK_species_isolates_taxonomy_update_prev_taxnode_id` 
FOREIGN KEY (`update_prev_taxnode_id`) 
REFERENCES `taxonomy_node` (`taxnode_id`);

-- taxonomy_node
ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_change_in`
FOREIGN KEY (`in_change`)
REFERENCES `taxonomy_change_in` (`change`);

ALTER TABLE `taxonomy_node` 
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_change_out` 
FOREIGN KEY (`out_change`) 
REFERENCES `taxonomy_change_out` (`change`);

ALTER TABLE `taxonomy_node` 
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_genome_coverage` 
FOREIGN KEY (`genome_coverage`) 
REFERENCES `taxonomy_genome_coverage` (`genome_coverage`);

ALTER TABLE `taxonomy_node` 
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_host_source` 
FOREIGN KEY (`host_source`) 
REFERENCES `taxonomy_host_source` (`host_source`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_level_level_id`
FOREIGN KEY (`level_id`)
REFERENCES `taxonomy_level` (`id`)
ON DELETE CASCADE;

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_molecule_inher_molecule_id`
FOREIGN KEY (`inher_molecule_id`)
REFERENCES `taxonomy_molecule` (`id`);

ALTER TABLE `taxonomy_node` 
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_molecule_molecule_id` 
FOREIGN KEY (`molecule_id`) 
REFERENCES `taxonomy_molecule` (`id`);

ALTER TABLE `taxonomy_node` 
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_family_id` 
FOREIGN KEY (`family_id`) 
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node` 
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_genus_id` 
FOREIGN KEY (`genus_id`) 
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_ictv_id`
FOREIGN KEY (`ictv_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_order_id`
FOREIGN KEY (`order_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_species_id`
FOREIGN KEY (`species_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_subfamily_id`
FOREIGN KEY (`subfamily_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_tree_id`
FOREIGN KEY (`tree_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_class_id`
FOREIGN KEY (`class_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_kingdom_id`
FOREIGN KEY (`kingdom_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_phylum_id`
FOREIGN KEY (`phylum_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_realm_id`
FOREIGN KEY (`realm_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_subclass_id`
FOREIGN KEY (`subclass_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_subgenus_id`
FOREIGN KEY (`subgenus_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_subkingdom_id`
FOREIGN KEY (`subkingdom_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_suborder_id`
FOREIGN KEY (`suborder_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_subphylum_id`
FOREIGN KEY (`subphylum_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_node_subrealm_id`
FOREIGN KEY (`subrealm_id`)
REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_node`
ADD CONSTRAINT `FK_taxonomy_node_taxonomy_toc`
FOREIGN KEY (`tree_id`, `msl_release_num`)
REFERENCES `taxonomy_toc` (`tree_id`, `msl_release_num`);

-- taxonomy_json_rank
ALTER TABLE `taxonomy_json_rank`
  ADD CONSTRAINT `FK_taxonomy_json_rank_taxonomy_level` 
  FOREIGN KEY (`level_id`) REFERENCES `taxonomy_level` (`id`);

ALTER TABLE `taxonomy_json_rank`
  ADD CONSTRAINT `FK_taxonomy_json_rank_tree_id` 
  FOREIGN KEY (`tree_id`) REFERENCES `taxonomy_node` (`taxnode_id`);

-- taxonomy_json
ALTER TABLE `taxonomy_json`
  ADD CONSTRAINT `FK_taxonomy_json_parent_taxonomy_node` 
  FOREIGN KEY (`parent_taxnode_id`) REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_json`
  ADD CONSTRAINT `FK_taxonomy_json_taxonomy_node` 
  FOREIGN KEY (`taxnode_id`) REFERENCES `taxonomy_node` (`taxnode_id`);

ALTER TABLE `taxonomy_json`
  ADD CONSTRAINT `FK_taxonomy_json_tree_id` 
  FOREIGN KEY (`tree_id`) REFERENCES `taxonomy_node` (`taxnode_id`);