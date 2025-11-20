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
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_node" ORDER BY taxnode_id" > "$DATA_DIR/taxonomy_node.utf8.txt"
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