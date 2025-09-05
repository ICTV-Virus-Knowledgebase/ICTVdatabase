#!/usr/bin/env bash
#
# Export all MariaDB tables from ictv_taxonomy
#

set -euo pipefail

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

#------------------------------#
# Export table data to tsv file
#------------------------------#

# species_isolates
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$species_isolates" ORDER BY isolate_id" > species_isolates.utf8.tsv
# taxonomy_toc
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_toc" ORDER BY msl_release_num" > taxonomy_toc.utf8.tsv
# taxonomy_node
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_node" ORDER BY taxnode_id" > taxonomy_node.utf8.tsv
# taxonomy_level
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_level"" > taxonomy_level.utf8.tsv
# taxonomy_molecule
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_molecule"" > taxonomy_molecule.utf8.tsv
# taxonomy_host_source
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_host_source"" > taxonomy_host_source.utf8.tsv
# taxonomy_genome_coverage
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_genome_coverage"" > taxonomy_genome_coverage.utf8.tsv
# taxonomy_change_in
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_change_in"" > taxonomy_change_in.utf8.tsv
# taxonomy_change_out
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_change_out"" > taxonomy_change_out.utf8.tsv
# taxonomy_node_delta
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_node_delta" ORDER BY msl, prev_taxid, new_taxid" > taxonomy_node_delta.utf8.tsv
# taxonomy_node_merge_split
mariadb -D "$DATABASE" --default-character-set=utf8mb4 --batch --raw -e "SELECT * FROM "$taxonomy_node_merge_split" ORDER BY prev_ictv_id, next_ictv_id" > taxonomy_node_merge_split.utf8.tsv
