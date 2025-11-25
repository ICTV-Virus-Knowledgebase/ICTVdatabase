#!/usr/bin/env bash
#
# Export all MariaDB tables from ictv_taxonomy
#

set -euo pipefail

# exportTables script aboslute path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Relative path to data dir from SCRIPT_DIR
DATA_DIR="$(cd "$SCRIPT_DIR/../../../data" && pwd)"

# Target database
DATABASE="ictv_taxonomy"

# Do I want to hard code the tables?
# Tables
species_isolates="species_isolates"
taxonomy_toc="taxonomy_toc"
taxonomy_node="taxonomy_node"
taxonomy_level="taxonomy_level"
taxonomy_molecule="taxonomy_molecule"
taxonomy_host_source="taxonomy_host_source"
taxonomy_genome_coverage="taxonomy_genome_coverage"
taxonomy_change_in="taxonomy_change_in"
taxonomy_change_out="taxonomy_change_out"
taxonomy_node_delta="taxonomy_node_delta"
taxonomy_node_merge_split="taxonomy_node_merge_split"

#-----------------------------------------#
# Export table data to tsv formatted file
#-----------------------------------------#

# species_isolates
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$species_isolates" ORDER BY isolate_id" > "$DATA_DIR/species_isolates.utf8.txt"
# taxonomy_toc
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_toc" ORDER BY msl_release_num" > "$DATA_DIR/taxonomy_toc.utf8.txt"
# taxonomy_node
# mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_node" ORDER BY taxnode_id" > "taxonomy_node.utf8.txt"
# taxonomy_level
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_level"" > "$DATA_DIR/taxonomy_level.utf8.txt"
# taxonomy_molecule
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_molecule"" > "$DATA_DIR/taxonomy_molecule.utf8.txt"
# taxonomy_host_source
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_host_source"" > "$DATA_DIR/taxonomy_host_source.utf8.txt"
# taxonomy_genome_coverage
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_genome_coverage"" > "$DATA_DIR/taxonomy_genome_coverage.utf8.txt"
# taxonomy_change_in
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_change_in"" > "$DATA_DIR/taxonomy_change_in.utf8.txt"
# taxonomy_change_out
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_change_out"" > "$DATA_DIR/taxonomy_change_out.utf8.txt"
# taxonomy_node_delta
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_node_delta" ORDER BY msl, prev_taxid, new_taxid" > "$DATA_DIR/taxonomy_node_delta.utf8.txt"
# taxonomy_node_merge_split
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_node_merge_split" ORDER BY prev_ictv_id, next_ictv_id" > "$DATA_DIR/taxonomy_node_merge_split.utf8.txt"

# taxonomy_node
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw \
  -e "SELECT \
    taxnode_id,
    parent_id,
    tree_id,
    msl_release_num,
    level_id,
    name,
    ictv_id,
    molecule_id,
    abbrev_csv,
    genbank_accession_csv,
    genbank_refseq_accession_csv,
    refseq_accession_csv,
    isolate_csv,
    notes,
    is_ref,
    is_official,
    is_hidden,
    is_deleted,
    is_deleted_next_year,
    is_typo,
    is_renamed_next_year,
    is_obsolete,
    in_change,
    in_target,
    in_filename,
    in_notes,
    out_change,
    out_target,
    out_filename,
    out_notes,
    start_num_sort,
    row_num,
    filename,
    xref,
    realm_id,
    realm_kid_ct,
    realm_desc_ct,
    subrealm_id,
    subrealm_kid_ct,
    subrealm_desc_ct,
    kingdom_id,
    kingdom_kid_ct,
    kingdom_desc_ct,
    subkingdom_id,
    subkingdom_kid_ct,
    subkingdom_desc_ct,
    phylum_id,
    phylum_kid_ct,
    phylum_desc_ct,
    subphylum_id,
    subphylum_kid_ct,
    subphylum_desc_ct,
    class_id,
    class_kid_ct,
    class_desc_ct,
    subclass_id,
    subclass_kid_ct,
    subclass_desc_ct,
    order_id,
    order_kid_ct,
    order_desc_ct,
    suborder_id,
    suborder_kid_ct,
    suborder_desc_ct,
    family_id,
    family_kid_ct,
    family_desc_ct,
    subfamily_id,
    subfamily_kid_ct,
    subfamily_desc_ct,
    genus_id,
    genus_kid_ct,
    genus_desc_ct,
    subgenus_id,
    subgenus_kid_ct,
    subgenus_desc_ct,
    species_id,
    species_kid_ct,
    species_desc_ct,
    taxa_kid_cts,
    taxa_desc_cts,
    inher_molecule_id,
    left_idx,
    right_idx,
    node_depth,
    lineage,
    exemplar_name,
    genome_coverage,
    host_source
   FROM $taxonomy_node
   ORDER BY taxnode_id" \
  > "$DATA_DIR/taxonomy_node_mariadb_etl.utf8.txt"