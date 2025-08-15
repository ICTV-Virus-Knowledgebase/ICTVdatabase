-- taxonomy_node
CREATE INDEX idx_taxonomy_node_parent_level_tree ON taxonomy_node (parent_id, level_id, tree_id);
CREATE INDEX idx_taxonomy_node_taxnode_tree ON taxonomy_node (taxnode_id, tree_id);
CREATE INDEX idx_taxonomy_node_tree_level ON taxonomy_node (tree_id, level_id);
-- Created to speed up speed up Release History page when it opens
CREATE INDEX idx_node_hidden_msl_name_treelevel ON taxonomy_node (is_hidden, msl_release_num, name, tree_id, level_id);
CREATE INDEX idx_tn_name ON taxonomy_node (name);
-- Created by Don for Find the Species
CREATE INDEX idx_tn_name_mslrelease ON taxonomy_node (name, msl_release_num);
-- Created by Don for Find the Species
CREATE INDEX idx_tn_tree_id ON taxonomy_node (tree_id);
-- Created for searchTaxononmy SP to speed up searches
CREATE INDEX idx_tn_allreleases_order ON taxonomy_node (is_hidden, is_deleted, msl_release_num, left_idx);
-- Created as an additional speed boost for searchTaxonomy SP
CREATE INDEX idx_tn_sibling_order ON taxonomy_node (parent_id, level_id, left_idx, taxnode_id);


-- taxonomy_molecule
CREATE INDEX abbrev ON taxonomy_molecule (abbrev);

-- taxonomy_genome_coverage
CREATE INDEX name ON taxonomy_genome_coverage (name);

-- taxonomy_node_merge_split
CREATE INDEX taxonomy_node_merge_split_next_ictv_id_IDX ON taxonomy_node_merge_split (next_ictv_id);
CREATE INDEX taxonomy_node_merge_split_prev_ictv_id_IDX ON taxonomy_node_merge_split (prev_ictv_id);

-- taxonomy_node_delta
CREATE INDEX idx_taxonomy_node_delta_prev_taxid ON taxonomy_node_delta (prev_taxid);
CREATE INDEX idx_taxonomy_node_delta_new_taxid ON taxonomy_node_delta (new_taxid);

-- taxonomy_json
CREATE INDEX idx_taxonomy_json_taxnode_tree_ghost ON taxonomy_json (taxnode_id, tree_id, is_ghost_node);
CREATE INDEX idx_taxonomy_json_parent_taxnode_tree_ghost ON taxonomy_json (parent_taxnode_id, tree_id, is_ghost_node);
CREATE INDEX idx_taxonomy_json_id ON taxonomy_json (id);
CREATE INDEX idx_tj_tree_rank ON taxonomy_json (tree_id, rank_index);
CREATE INDEX idx_tj_tree_parent ON taxonomy_json (tree_id, parent_id);

-- taxonomy_json_rank
CREATE INDEX idx_taxonomy_json_rank_level_tree ON taxonomy_json_rank (level_id, tree_id);
CREATE INDEX idx_tjr_tree_rank ON taxonomy_json_rank (tree_id, rank_index);


