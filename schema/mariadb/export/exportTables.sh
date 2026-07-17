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

# Views
vmr_export="vmr_export"
taxonomy_node_export="taxonomy_node_export"

TMP_DIR="$(mktemp -d /tmp/ictv_mariadb_export.XXXXXX)"
chmod 0777 "$TMP_DIR"

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

export_query() {
  local output_filename="$1"
  local query="$2"
  local tmp_file="$TMP_DIR/$output_filename"
  local dest_file="$DATA_DIR/$output_filename"

  echo "Exporting $output_filename"

  rm -f "$tmp_file"

  # Keep the existing header row so the LOAD DATA scripts can continue to use
  # IGNORE 1 ROWS. The data body is exported by the server with CSV-style TSV
  # quoting, then copied into the repo by this shell user to preserve ownership.
  mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw \
    -e "$query LIMIT 1" | sed -n '1p' > "$dest_file"

  mariadb -D "$DATABASE" --default-character-set=utf8mb4 <<SQL
$query
INTO OUTFILE '$tmp_file'
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '\\\\'
LINES TERMINATED BY '\n';
SQL

  cat "$tmp_file" >> "$dest_file"
  rm -f "$tmp_file"
}

#-----------------------------------------#
# Export table data to tsv formatted file
#-----------------------------------------#

# species_isolates (exclude generated _isolate_name)
export_query "species_isolates.utf8.txt" "SELECT
  isolate_id,
  taxnode_id,
  species_sort,
  isolate_sort,
  species_name,
  isolate_type,
  isolate_names,
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
FROM $species_isolates
ORDER BY isolate_id"

# taxonomy_toc
export_query "taxonomy_toc.utf8.txt" "SELECT * FROM $taxonomy_toc ORDER BY msl_release_num"

# taxonomy_level
export_query "taxonomy_level.utf8.txt" "SELECT * FROM $taxonomy_level"

# taxonomy_molecule
export_query "taxonomy_molecule.utf8.txt" "SELECT * FROM $taxonomy_molecule"

# taxonomy_host_source
export_query "taxonomy_host_source.utf8.txt" "SELECT * FROM $taxonomy_host_source"

# taxonomy_genome_coverage
export_query "taxonomy_genome_coverage.utf8.txt" "SELECT * FROM $taxonomy_genome_coverage"

# taxonomy_change_in
export_query "taxonomy_change_in.utf8.txt" "SELECT * FROM $taxonomy_change_in"

# taxonomy_change_out
export_query "taxonomy_change_out.utf8.txt" "SELECT * FROM $taxonomy_change_out"

# taxonomy_node_delta (exclude generated tag_csv columns)
export_query "taxonomy_node_delta.utf8.txt" "SELECT
  prev_taxid,
  new_taxid,
  proposal,
  notes,
  is_merged,
  is_split,
  is_moved,
  is_promoted,
  is_demoted,
  is_renamed,
  is_new,
  is_deleted,
  is_now_type,
  is_lineage_updated,
  msl
FROM $taxonomy_node_delta
ORDER BY msl, prev_taxid, new_taxid"

# taxonomy_node_merge_split
export_query "taxonomy_node_merge_split.utf8.txt" "SELECT * FROM $taxonomy_node_merge_split ORDER BY prev_ictv_id, next_ictv_id"

# vmr_export
export_query "vmr_export.utf8.txt" "SELECT * FROM $vmr_export"

# taxonomy_node_export view
export_query "taxonomy_node_export.utf8.txt" "SELECT * FROM $taxonomy_node_export"

# taxonomy_node
export_query "taxonomy_node_mariadb_etl.utf8.txt" "SELECT
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
ORDER BY taxnode_id"
