#!/usr/bin/env bash
#
# run through the steps to drop, create, load and QC
#

# log queries and errors into different logs
exec > >(tee db_setup.log) 2> >(tee db_error.log >&2)

# Set default database name if not provided
if [ -n "$1" ]; then
    DBNAME="$1"
else
    DBNAME="ictv_taxonomy_temp"  # default database name
fi

echo "Target database: $DBNAME"

# Create the database if it doesn't exist.
mariadb -e "CREATE DATABASE IF NOT EXISTS \`$DBNAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Track start time
START_TIME=$(date +%s)

# drop tables
mariadb -D "$DBNAME" -vvv --show-warnings < drop_tables.sql

# create tables
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_change_in_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_change_out_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_genome_coverage_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_host_source_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_level_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_molecule_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_toc_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.species_isolates_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_node_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_node_merge_split_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_node_delta_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_json_rank_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_json_create.sql

# Function to compute expected row count (excluding header)
# and then run a query that compares the expected count with the actual row count.
# Usage: check_row_count <table_name> <data_file_path>
check_row_count() {

  local table="$1"
  local file="$2"

  # Compute expected row count from file (subtract header)
  local expected=$(( $(wc -l < "$file") - 1 ))
  
  echo "Expected rows for table $table: $expected"
  
  # Run the query using a heredoc
  mariadb -D "$DBNAME" -vvv --show-warnings <<EOF
SELECT COUNT(*) AS total_count, $expected AS should_be FROM $table;
EOF
}

# load data into the tables and call check_row_count to compare 
# rows in data file with what got loaded into the table.
mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_change_in_load_data.sql
check_row_count taxonomy_change_in "../../../data/taxonomy_change_in.utf8.txt"

mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_change_out_load_data.sql
check_row_count taxonomy_change_out "../../../data/taxonomy_change_out.utf8.txt"

mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_genome_coverage_load_data.sql
check_row_count taxonomy_genome_coverage "../../../data/taxonomy_genome_coverage.utf8.txt"

mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_host_source_load_data.sql
check_row_count taxonomy_host_source "../../../data/taxonomy_host_source.utf8.txt"

mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_level_load_data.sql
check_row_count taxonomy_level "../../../data/taxonomy_level.utf8.txt"

mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_molecule_load_data.sql
check_row_count taxonomy_molecule "../../../data/taxonomy_molecule.utf8.txt"

mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_toc_load_data.sql
check_row_count taxonomy_toc "../../../data/taxonomy_toc.utf8.txt"

mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_node_load_data.sql
check_row_count taxonomy_node "../../../data/taxonomy_node_mariadb_etl.utf8.txt"

mariadb -D "$DBNAME" -vvv --show-warnings < table.species_isolates_load_data.sql
check_row_count species_isolates "../../../data/species_isolates.utf8.txt"

mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_node_merge_split_load_data.sql
check_row_count taxonomy_node_merge_split "../../../data/taxonomy_node_merge_split.utf8.txt"

mariadb -D "$DBNAME" -vvv --show-warnings < table.taxonomy_node_delta_load_data.sql
check_row_count taxonomy_node_delta "../../../data/taxonomy_node_delta.utf8.txt"

# add views
mariadb -D "$DBNAME" -vvv --show-warnings < view.taxonomy_node_names_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.taxonomy_node_changes_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.MSL_export_fast_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.species_historic_name_lut_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.species_isolates_alpha_num1_num2_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.species_latest_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.taxonomy_node_dx_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.taxonomy_node_export_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.taxonomy_node_x_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.taxonomy_toc_dx_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.view_taxa_level_counts_by_release_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.view_taxonomy_stats_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.virus_isolates_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < view.vmr_export_create.sql


# add indexes
mariadb -D "$DBNAME" -vvv --show-warnings < add_indexes.sql

# add foreign keys to tables
mariadb -D "$DBNAME" -vvv --show-warnings < add_foreign_keys.sql

# add user defined functions
mariadb -D "$DBNAME" -vvv --show-warnings < udf.count_accents_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < udf.getChildTaxaCounts_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < udf.udf_getMSL_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < udf.udf_getTaxNodeChildInfo_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < udf.udf_getTreeID_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < udf.udf_rankCountsToStringWithPurals_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < udf.udf_singularOrPluralTaxLevelNames_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < udf.vgd_strrchr_create.sql

# add stored procedures
mariadb -D "$DBNAME" -vvv --show-warnings < sp.createParentGhostNodes_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.createIntermediateGhostNodes_create.sql
# createGhostNodes calls createParentGhostNodes and createIntermediateGhostNodes
mariadb -D "$DBNAME" -vvv --show-warnings < sp.createGhostNodes_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.initializeJsonColumn_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.initializeTaxonomyJsonFromTaxonomyNode_create.sql
# populateTaxonomyJSON calls initializeTaxonomyJsonFromTaxonomyNode, createGhostNodes, and initializeJsonColumn
mariadb -D "$DBNAME" -vvv --show-warnings < sp.populateTaxonomyJSON_create.sql
# populateTaxonomyJsonForAllReleases calls populateTaxonomyJSON
mariadb -D "$DBNAME" -vvv --show-warnings < sp.populateTaxonomyJsonForAllReleases_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.exportReleasesJSON_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.exportTaxonomyJSON_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.get_taxon_names_in_msl_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.getTaxonReleaseHistory_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.getVirusIsolates_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.initializeTaxonomyJsonRanks_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.MSL_delta_counts_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.MSL_delta_report_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.MSL_export_fast_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.MSL_export_official_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.QC_module_taxonomy_node_suffixes_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.QC_run_modules_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.QC_module_ictv_id_deltas_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.QC_module_taxonomy_node_delta_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.QC_module_taxonomy_node_hidden_nodes_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.QC_module_taxonomy_node_ictv_resurrection_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.QC_module_taxonomy_node_orphan_taxa_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.QC_module_virus_prop_tabs_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.QC_module_vmr_export_species_count_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.rebuild_delta_nodes_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.searchTaxonomy_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.sp_simplify_molecule_id_settings_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.species_isolates_update_sorts_create.sql
mariadb -D "$DBNAME" -vvv --show-warnings < sp.NCBI_linkout_ft_export_create.sql

# Triggers
# Not yet created
# mariadb -D "$DBNAME" -vvv --show-warnings < tr.TR_taxonomy_node_UPDATE_indexes.sql

# Update SPs with errors that need to be checked:
# mariadb -D "$DBNAME" -vvv --show-warnings < sp.taxonomy_node_compute_indexes_create.sql
# mariadb -D "$DBNAME" -vvv --show-warnings < sp.rebuild_node_merge_split_create.sql
# mariadb -D "$DBNAME" -vvv --show-warnings < sp.NCBI_linkout_ft_export_create.sql

# Run SPs to populate taxonomy_json and taxonomy_json_rank
mariadb -D "$DBNAME" -vvv --show-warnings < populate_taxonomy_json_rank.sql
mariadb -D "$DBNAME" -vvv --show-warnings < populate_taxonomy_json.sql

# Execution time:
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))

MINUTES=$((ELAPSED_TIME / 60))
SECONDS=$((ELAPSED_TIME % 60))

echo "Total execution time: ${MINUTES} minutes and ${SECONDS} seconds"
