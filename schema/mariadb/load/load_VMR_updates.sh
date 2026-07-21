#!/usr/bin/env bash
#
# Safely update VMR data after it has been updated by ICTVvmr-update.
#
# This assumes that the data has then been exported by ../load/exportTables.sh after ICTVvmr-update SQL has run.
#
# The default scope replaces species_isolates only. The "all" scope also
# synchronizes taxonomy_genome_coverage, taxonomy_host_source, and
# taxonomy_molecule. Data is loaded and validated in a staging database before
# the live InnoDB tables are changed in a single transaction.
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$(cd "$SCRIPT_DIR/../../../data" && pwd)"
SCHEMA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DBNAME="ictv_taxonomy_temp"
SCOPE="species"
DRY_RUN=0
ASSUME_YES=0
POSITIONAL_COUNT=0

usage() {
  cat <<'EOF'
Usage:
  load_VMR_updates.sh [options]
  load_VMR_updates.sh [database] [species|all]

Options:
  -d, --database NAME   Target database (default: ictv_taxonomy_temp)
  -s, --scope SCOPE     Update scope: species or all (default: species)
      --dry-run         Run read-only preflight checks and show planned work
  -y, --yes             Skip the production database confirmation
  -h, --help            Show this help

Scopes:
  species  Replace species_isolates only.
  all      Replace species_isolates and synchronize taxonomy_genome_coverage,
           taxonomy_host_source, and taxonomy_molecule.

Examples:
  ./load_VMR_updates.sh
  ./load_VMR_updates.sh --database ictv_taxonomy_temp --scope all
  ./load_VMR_updates.sh ictv_taxonomy species --yes
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    -d|--database)
      (($# >= 2)) || die "$1 requires a database name"
      DBNAME="$2"
      shift 2
      ;;
    -s|--scope)
      (($# >= 2)) || die "$1 requires either species or all"
      SCOPE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      case "$POSITIONAL_COUNT" in
        0) DBNAME="$1" ;;
        1) SCOPE="$1" ;;
        *) die "too many positional arguments" ;;
      esac
      POSITIONAL_COUNT=$((POSITIONAL_COUNT + 1))
      shift
      ;;
  esac
done

[[ "$DBNAME" =~ ^[A-Za-z0-9_]+$ ]] ||
  die "database names may contain only letters, numbers, and underscores"
[[ ${#DBNAME} -le 64 ]] ||
  die "database name exceeds MariaDB's 64-character limit"

case "$SCOPE" in
  species|all) ;;
  *) die "scope must be either species or all" ;;
esac

command -v mariadb >/dev/null 2>&1 ||
  die "the mariadb client is not installed or not on PATH"
command -v flock >/dev/null 2>&1 ||
  die "flock is required to prevent concurrent local VMR updates"
command -v tee >/dev/null 2>&1 || die "tee is required for logging"

# The load SQL files contain paths relative to this directory.
cd "$SCRIPT_DIR"

# Keep cumulative logs, with each execution separated by a run header.
exec > >(tee -a "$SCRIPT_DIR/db_vmr_load.log") \
     2> >(tee -a "$SCRIPT_DIR/db_vmr_error.log" >&2)

RUN_ID="$(date -u +%Y%m%d_%H%M%S)"
STAGE_DB="vmr_stage_${RUN_ID}_$$"
LOCK_FILE="/tmp/ictv_vmr_update_${DBNAME}.lock"

echo
echo "=== VMR update run $RUN_ID UTC ==="
echo "Using SCRIPT_DIR=$SCRIPT_DIR"
echo "Using DATA_DIR=$DATA_DIR"
echo "Using SCHEMA_DIR=$SCHEMA_DIR"
echo "Target database: $DBNAME"
echo "Update scope: $SCOPE"
echo "Dry run: $DRY_RUN"

# Prevent two copies on this host from updating the same database.
exec {LOCK_FD}>"$LOCK_FILE"
flock -n "$LOCK_FD" ||
  die "another VMR update is already running for $DBNAME"

MARIADB_BASE=(
  mariadb
  --abort-source-on-error
  --default-character-set=utf8mb4
  --local-infile=1
  --show-warnings
)

declare -A CREATE_SQL=(
  [species_isolates]="$SCHEMA_DIR/table.species_isolates_create.sql"
  [taxonomy_genome_coverage]="$SCHEMA_DIR/table.taxonomy_genome_coverage_create.sql"
  [taxonomy_host_source]="$SCHEMA_DIR/table.taxonomy_host_source_create.sql"
  [taxonomy_molecule]="$SCHEMA_DIR/table.taxonomy_molecule_create.sql"
)

declare -A LOAD_SQL=(
  [species_isolates]="$SCRIPT_DIR/table.species_isolates_load_data.sql"
  [taxonomy_genome_coverage]="$SCRIPT_DIR/table.taxonomy_genome_coverage_load_data.sql"
  [taxonomy_host_source]="$SCRIPT_DIR/table.taxonomy_host_source_load_data.sql"
  [taxonomy_molecule]="$SCRIPT_DIR/table.taxonomy_molecule_load_data.sql"
)

declare -A DATA_FILE=(
  [species_isolates]="$DATA_DIR/species_isolates.utf8.txt"
  [taxonomy_genome_coverage]="$DATA_DIR/taxonomy_genome_coverage.utf8.txt"
  [taxonomy_host_source]="$DATA_DIR/taxonomy_host_source.utf8.txt"
  [taxonomy_molecule]="$DATA_DIR/taxonomy_molecule.utf8.txt"
)

declare -A EXPECTED_HEADER=(
  [species_isolates]=$'isolate_id\ttaxnode_id\tspecies_sort\tisolate_sort\tspecies_name\tisolate_type\tisolate_names\tisolate_abbrevs\tisolate_designation\tgenbank_accessions\trefseq_accessions\tgenome_coverage\tmolecule\thost_source\trefseq_organism\trefseq_taxids\tupdate_change\tupdate_prev_species\tupdate_prev_taxnode_id\tupdate_change_proposal\tnotes'
  [taxonomy_genome_coverage]=$'genome_coverage\tname\tpriority'
  [taxonomy_host_source]=$'host_source'
  [taxonomy_molecule]=$'id\tabbrev\tname\tbalt_group\tbalt_roman\tdescription\tleft_idx\tright_idx'
)

declare -A EXPECTED_COUNT=()
declare -A OLD_COUNT=()
declare -A BACKUP_TABLE=()
CREATED_BACKUPS=()

if [[ "$SCOPE" == "species" ]]; then
  SELECTED_TABLES=(species_isolates)
else
  # Parent tables are staged before their child table.
  SELECTED_TABLES=(
    taxonomy_genome_coverage
    taxonomy_host_source
    taxonomy_molecule
    species_isolates
  )
fi

STAGE_CREATED=0
PUBLISH_SUCCEEDED=0

query_scalar() {
  local sql="$1"
  "${MARIADB_BASE[@]}" --batch --skip-column-names --raw -e "$sql"
}

cleanup() {
  local status=$?
  trap - EXIT
  set +e

  if ((STAGE_CREATED == 1)); then
    if ((status == 0)); then
      echo "Dropping staging database $STAGE_DB"
      "${MARIADB_BASE[@]}" -e "DROP DATABASE IF EXISTS \`$STAGE_DB\`;"
    else
      echo "Staging database $STAGE_DB was preserved for failure analysis." >&2
    fi
  fi

  if ((status != 0 && PUBLISH_SUCCEEDED == 0 &&
      ${#CREATED_BACKUPS[@]} > 0)); then
    echo "Removing empty backup tables created by the failed run." >&2
    for backup in "${CREATED_BACKUPS[@]}"; do
      "${MARIADB_BASE[@]}" -D "$DBNAME" \
        -e "DROP TABLE IF EXISTS \`$backup\`;" >/dev/null 2>&1
    done
  fi

  if ((status != 0)); then
    if ((PUBLISH_SUCCEEDED == 1)); then
      echo "VMR publication committed, but post-publication validation failed." >&2
      echo "The rollback backups and staging database were retained." >&2
    else
      echo "VMR update failed before commit; live-table DML was rolled back." >&2
    fi
  fi

  exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

validate_zero() {
  local label="$1"
  local sql="$2"
  local count

  count="$(query_scalar "$sql")"
  [[ "$count" =~ ^[0-9]+$ ]] ||
    die "validation '$label' returned a non-numeric result: $count"
  ((count == 0)) ||
    die "validation failed: $label ($count offending row(s))"
  echo "Validated: $label"
}

validate_species_references() {
  local species_db="$1"
  local parent_db="$2"

  validate_zero "species taxnode_id values exist" "
    SELECT COUNT(*)
    FROM \`$species_db\`.species_isolates AS si
    LEFT JOIN \`$DBNAME\`.taxonomy_node AS tn
      ON tn.taxnode_id = si.taxnode_id
    WHERE si.taxnode_id IS NOT NULL
      AND tn.taxnode_id IS NULL;"

  validate_zero "species update_prev_taxnode_id values exist" "
    SELECT COUNT(*)
    FROM \`$species_db\`.species_isolates AS si
    LEFT JOIN \`$DBNAME\`.taxonomy_node AS tn
      ON tn.taxnode_id = si.update_prev_taxnode_id
    WHERE si.update_prev_taxnode_id IS NOT NULL
      AND tn.taxnode_id IS NULL;"

  validate_zero "species genome_coverage values exist" "
    SELECT COUNT(*)
    FROM \`$species_db\`.species_isolates AS si
    LEFT JOIN \`$parent_db\`.taxonomy_genome_coverage AS gc
      ON gc.name = si.genome_coverage
    WHERE si.genome_coverage IS NOT NULL
      AND gc.genome_coverage IS NULL;"

  validate_zero "species host_source values exist" "
    SELECT COUNT(*)
    FROM \`$species_db\`.species_isolates AS si
    LEFT JOIN \`$parent_db\`.taxonomy_host_source AS hs
      ON hs.host_source = si.host_source
    WHERE si.host_source IS NOT NULL
      AND hs.host_source IS NULL;"

  validate_zero "species molecule values exist" "
    SELECT COUNT(*)
    FROM \`$species_db\`.species_isolates AS si
    LEFT JOIN \`$parent_db\`.taxonomy_molecule AS tm
      ON tm.abbrev = si.molecule
    WHERE si.molecule IS NOT NULL
      AND tm.id IS NULL;"
}

validate_taxonomy_node_references() {
  local parent_db="$1"

  validate_zero "taxonomy_node genome_coverage values remain valid" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.taxonomy_node AS tn
    LEFT JOIN \`$parent_db\`.taxonomy_genome_coverage AS gc
      ON gc.genome_coverage = tn.genome_coverage
    WHERE tn.genome_coverage IS NOT NULL
      AND gc.genome_coverage IS NULL;"

  validate_zero "taxonomy_node host_source values remain valid" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.taxonomy_node AS tn
    LEFT JOIN \`$parent_db\`.taxonomy_host_source AS hs
      ON hs.host_source = tn.host_source
    WHERE tn.host_source IS NOT NULL
      AND hs.host_source IS NULL;"

  validate_zero "taxonomy_node molecule_id values remain valid" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.taxonomy_node AS tn
    LEFT JOIN \`$parent_db\`.taxonomy_molecule AS tm
      ON tm.id = tn.molecule_id
    WHERE tn.molecule_id IS NOT NULL
      AND tm.id IS NULL;"

  validate_zero "taxonomy_node inher_molecule_id values remain valid" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.taxonomy_node AS tn
    LEFT JOIN \`$parent_db\`.taxonomy_molecule AS tm
      ON tm.id = tn.inher_molecule_id
    WHERE tn.inher_molecule_id IS NOT NULL
      AND tm.id IS NULL;"
}

load_staging_table() {
  local table="$1"
  local output

  echo "Creating staging table $table"
  "${MARIADB_BASE[@]}" -D "$STAGE_DB" -vvv \
    < "${CREATE_SQL[$table]}"

  echo "Loading staging table $table"
  if ! output="$("${MARIADB_BASE[@]}" -D "$STAGE_DB" -vvv \
      < "${LOAD_SQL[$table]}" 2>&1)"; then
    echo "$output" >&2
    die "the load command failed for staging table $table"
  fi
  echo "$output"

  # LOAD DATA LOCAL can convert invalid values to warnings instead of failing.
  # --show-warnings emits these with a "Warning" prefix.
  if [[ "$output" =~ Warnings:[[:space:]]*[1-9][0-9]* ]] ||
      [[ "$output" == *"Warning (Code "* ]]; then
    die "the staging load for $table produced one or more warnings"
  fi
}

echo "Running preflight checks"

database_exists="$(query_scalar "
  SELECT COUNT(*)
  FROM information_schema.SCHEMATA
  WHERE SCHEMA_NAME = '$DBNAME';")"
[[ "$database_exists" == "1" ]] ||
  die "target database $DBNAME does not exist"

local_infile="$(query_scalar "SELECT @@GLOBAL.local_infile;")"
[[ "$local_infile" == "1" || "$local_infile" == "ON" ]] ||
  die "MariaDB local_infile is disabled"

required_tables="$(query_scalar "
  SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = '$DBNAME'
    AND TABLE_NAME IN (
      'species_isolates',
      'taxonomy_genome_coverage',
      'taxonomy_host_source',
      'taxonomy_molecule',
      'taxonomy_node'
    )
    AND ENGINE = 'InnoDB';")"
[[ "$required_tables" == "5" ]] ||
  die "the target must contain the five expected InnoDB VMR/dependency tables"

species_fk_count="$(query_scalar "
  SELECT COUNT(*)
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = '$DBNAME'
    AND TABLE_NAME = 'species_isolates'
    AND CONSTRAINT_TYPE = 'FOREIGN KEY'
    AND CONSTRAINT_NAME IN (
      'FK_species_isolates_taxonomy_genome_coverage',
      'FK_species_isolates_taxonomy_host_source',
      'FK_species_isolates_taxonomy_molecule',
      'FK_species_isolates_taxonomy_node',
      'FK_species_isolates_taxonomy_update_prev_taxnode_id'
    );")"
[[ "$species_fk_count" == "5" ]] ||
  die "species_isolates does not have all five expected foreign keys"

if [[ "$SCOPE" == "all" ]]; then
  taxonomy_node_fk_count="$(query_scalar "
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = '$DBNAME'
      AND TABLE_NAME = 'taxonomy_node'
      AND CONSTRAINT_TYPE = 'FOREIGN KEY'
      AND CONSTRAINT_NAME IN (
        'FK_taxonomy_node_taxonomy_genome_coverage',
        'FK_taxonomy_node_taxonomy_host_source',
        'FK_taxonomy_node_taxonomy_molecule_inher_molecule_id',
        'FK_taxonomy_node_taxonomy_molecule_molecule_id'
      );")"
  [[ "$taxonomy_node_fk_count" == "4" ]] ||
    die "taxonomy_node does not have all four expected VMR lookup foreign keys"
fi

for table in "${SELECTED_TABLES[@]}"; do
  [[ -r "${CREATE_SQL[$table]}" ]] ||
    die "missing create SQL: ${CREATE_SQL[$table]}"
  [[ -r "${LOAD_SQL[$table]}" ]] ||
    die "missing load SQL: ${LOAD_SQL[$table]}"
  [[ -r "${DATA_FILE[$table]}" ]] ||
    die "missing data file: ${DATA_FILE[$table]}"

  IFS= read -r header < "${DATA_FILE[$table]}" ||
    die "could not read ${DATA_FILE[$table]}"
  header="${header%$'\r'}"
  [[ "$header" == "${EXPECTED_HEADER[$table]}" ]] ||
    die "unexpected header in ${DATA_FILE[$table]}"

  line_count="$(awk 'END { print NR }' "${DATA_FILE[$table]}")"
  [[ "$line_count" =~ ^[0-9]+$ ]] ||
    die "could not count records in ${DATA_FILE[$table]}"
  ((line_count > 1)) ||
    die "${DATA_FILE[$table]} contains no data rows"

  EXPECTED_COUNT[$table]=$((line_count - 1))
  OLD_COUNT[$table]="$(query_scalar \
    "SELECT COUNT(*) FROM \`$DBNAME\`.\`$table\`;")"
  echo "  $table: current=${OLD_COUNT[$table]}, input=${EXPECTED_COUNT[$table]}"
done

if ((DRY_RUN == 1)); then
  echo "Dry run completed successfully; no database objects were changed."
  exit 0
fi

if [[ "$DBNAME" == "ictv_taxonomy" && "$ASSUME_YES" == "0" ]]; then
  [[ -t 0 ]] ||
    die "production updates require --yes when input is not interactive"
  read -r -p \
    "Update production database ictv_taxonomy? Type 'yes' to continue: " answer
  [[ "$answer" == "yes" ]] || die "production update cancelled"
fi

START_TIME="$(date +%s)"

echo "Creating staging database $STAGE_DB"
"${MARIADB_BASE[@]}" -e "
  CREATE DATABASE \`$STAGE_DB\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_general_ci;"
STAGE_CREATED=1

for table in "${SELECTED_TABLES[@]}"; do
  load_staging_table "$table"

  actual_count="$(query_scalar \
    "SELECT COUNT(*) FROM \`$STAGE_DB\`.\`$table\`;")"
  [[ "$actual_count" == "${EXPECTED_COUNT[$table]}" ]] ||
    die "staging count mismatch for $table: expected ${EXPECTED_COUNT[$table]}, found $actual_count"
  echo "Validated row count for $table: $actual_count"
done

echo "Validating staging data"
if [[ "$SCOPE" == "all" ]]; then
  PARENT_DB="$STAGE_DB"

  validate_zero "taxonomy_genome_coverage names are unique" "
    SELECT COUNT(*) FROM (
      SELECT name
      FROM \`$STAGE_DB\`.taxonomy_genome_coverage
      WHERE name IS NOT NULL
      GROUP BY name
      HAVING COUNT(*) > 1
    ) AS duplicates;"

  validate_zero "taxonomy_molecule abbreviations are unique" "
    SELECT COUNT(*) FROM (
      SELECT abbrev
      FROM \`$STAGE_DB\`.taxonomy_molecule
      GROUP BY abbrev
      HAVING COUNT(*) > 1
    ) AS duplicates;"

  validate_taxonomy_node_references "$STAGE_DB"
else
  PARENT_DB="$DBNAME"
fi

validate_species_references "$STAGE_DB" "$PARENT_DB"

echo "Creating rollback backup tables"
for table in "${SELECTED_TABLES[@]}"; do
  backup="${table}_bak_${RUN_ID}"
  [[ ${#backup} -le 64 ]] ||
    die "backup table name is too long: $backup"
  BACKUP_TABLE[$table]="$backup"

  "${MARIADB_BASE[@]}" -D "$DBNAME" -vvv -e \
    "CREATE TABLE \`$backup\` LIKE \`$table\`;"
  CREATED_BACKUPS+=("$backup")
done

echo "Publishing validated VMR data"

if [[ "$SCOPE" == "species" ]]; then
  "${MARIADB_BASE[@]}" -D "$DBNAME" -vvv <<SQL
SET SESSION foreign_key_checks = 1;
START TRANSACTION;

INSERT INTO \`${BACKUP_TABLE[species_isolates]}\` (
  isolate_id, taxnode_id, species_sort, isolate_sort, species_name,
  isolate_type, isolate_names, isolate_abbrevs, isolate_designation,
  genbank_accessions, refseq_accessions, genome_coverage, molecule,
  host_source, refseq_organism, refseq_taxids, update_change,
  update_prev_species, update_prev_taxnode_id, update_change_proposal, notes
)
SELECT
  isolate_id, taxnode_id, species_sort, isolate_sort, species_name,
  isolate_type, isolate_names, isolate_abbrevs, isolate_designation,
  genbank_accessions, refseq_accessions, genome_coverage, molecule,
  host_source, refseq_organism, refseq_taxids, update_change,
  update_prev_species, update_prev_taxnode_id, update_change_proposal, notes
FROM species_isolates;

DELETE FROM species_isolates;

INSERT INTO species_isolates (
  isolate_id, taxnode_id, species_sort, isolate_sort, species_name,
  isolate_type, isolate_names, isolate_abbrevs, isolate_designation,
  genbank_accessions, refseq_accessions, genome_coverage, molecule,
  host_source, refseq_organism, refseq_taxids, update_change,
  update_prev_species, update_prev_taxnode_id, update_change_proposal, notes
)
SELECT
  isolate_id, taxnode_id, species_sort, isolate_sort, species_name,
  isolate_type, isolate_names, isolate_abbrevs, isolate_designation,
  genbank_accessions, refseq_accessions, genome_coverage, molecule,
  host_source, refseq_organism, refseq_taxids, update_change,
  update_prev_species, update_prev_taxnode_id, update_change_proposal, notes
FROM \`$STAGE_DB\`.species_isolates;

COMMIT;
SQL
else
  "${MARIADB_BASE[@]}" -D "$DBNAME" -vvv <<SQL
SET SESSION foreign_key_checks = 1;
START TRANSACTION;

INSERT INTO \`${BACKUP_TABLE[taxonomy_genome_coverage]}\`
  (genome_coverage, name, priority)
SELECT genome_coverage, name, priority
FROM taxonomy_genome_coverage;

INSERT INTO \`${BACKUP_TABLE[taxonomy_host_source]}\` (host_source)
SELECT host_source
FROM taxonomy_host_source;

INSERT INTO \`${BACKUP_TABLE[taxonomy_molecule]}\`
  (id, abbrev, name, balt_group, balt_roman, description, left_idx, right_idx)
SELECT id, abbrev, name, balt_group, balt_roman, description, left_idx, right_idx
FROM taxonomy_molecule;

INSERT INTO \`${BACKUP_TABLE[species_isolates]}\` (
  isolate_id, taxnode_id, species_sort, isolate_sort, species_name,
  isolate_type, isolate_names, isolate_abbrevs, isolate_designation,
  genbank_accessions, refseq_accessions, genome_coverage, molecule,
  host_source, refseq_organism, refseq_taxids, update_change,
  update_prev_species, update_prev_taxnode_id, update_change_proposal, notes
)
SELECT
  isolate_id, taxnode_id, species_sort, isolate_sort, species_name,
  isolate_type, isolate_names, isolate_abbrevs, isolate_designation,
  genbank_accessions, refseq_accessions, genome_coverage, molecule,
  host_source, refseq_organism, refseq_taxids, update_change,
  update_prev_species, update_prev_taxnode_id, update_change_proposal, notes
FROM species_isolates;

-- Remove the old VMR child rows before changing referenced lookup values.
DELETE FROM species_isolates;

INSERT INTO taxonomy_genome_coverage (genome_coverage, name, priority)
SELECT genome_coverage, name, priority
FROM \`$STAGE_DB\`.taxonomy_genome_coverage
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  priority = VALUES(priority);

INSERT INTO taxonomy_host_source (host_source)
SELECT staged_hs.host_source
FROM \`$STAGE_DB\`.taxonomy_host_source AS staged_hs
LEFT JOIN taxonomy_host_source AS live_hs
  ON live_hs.host_source = staged_hs.host_source
WHERE live_hs.host_source IS NULL;

INSERT INTO taxonomy_molecule
  (id, abbrev, name, balt_group, balt_roman, description, left_idx, right_idx)
SELECT id, abbrev, name, balt_group, balt_roman, description, left_idx, right_idx
FROM \`$STAGE_DB\`.taxonomy_molecule
ON DUPLICATE KEY UPDATE
  abbrev = VALUES(abbrev),
  name = VALUES(name),
  balt_group = VALUES(balt_group),
  balt_roman = VALUES(balt_roman),
  description = VALUES(description),
  left_idx = VALUES(left_idx),
  right_idx = VALUES(right_idx);

DELETE live_gc
FROM taxonomy_genome_coverage AS live_gc
LEFT JOIN \`$STAGE_DB\`.taxonomy_genome_coverage AS staged_gc
  ON staged_gc.genome_coverage = live_gc.genome_coverage
WHERE staged_gc.genome_coverage IS NULL;

DELETE live_hs
FROM taxonomy_host_source AS live_hs
LEFT JOIN \`$STAGE_DB\`.taxonomy_host_source AS staged_hs
  ON staged_hs.host_source = live_hs.host_source
WHERE staged_hs.host_source IS NULL;

DELETE live_tm
FROM taxonomy_molecule AS live_tm
LEFT JOIN \`$STAGE_DB\`.taxonomy_molecule AS staged_tm
  ON staged_tm.id = live_tm.id
WHERE staged_tm.id IS NULL;

INSERT INTO species_isolates (
  isolate_id, taxnode_id, species_sort, isolate_sort, species_name,
  isolate_type, isolate_names, isolate_abbrevs, isolate_designation,
  genbank_accessions, refseq_accessions, genome_coverage, molecule,
  host_source, refseq_organism, refseq_taxids, update_change,
  update_prev_species, update_prev_taxnode_id, update_change_proposal, notes
)
SELECT
  isolate_id, taxnode_id, species_sort, isolate_sort, species_name,
  isolate_type, isolate_names, isolate_abbrevs, isolate_designation,
  genbank_accessions, refseq_accessions, genome_coverage, molecule,
  host_source, refseq_organism, refseq_taxids, update_change,
  update_prev_species, update_prev_taxnode_id, update_change_proposal, notes
FROM \`$STAGE_DB\`.species_isolates;

COMMIT;
SQL
fi

PUBLISH_SUCCEEDED=1

echo "Running post-publication validation"
for table in "${SELECTED_TABLES[@]}"; do
  actual_count="$(query_scalar \
    "SELECT COUNT(*) FROM \`$DBNAME\`.\`$table\`;")"
  [[ "$actual_count" == "${EXPECTED_COUNT[$table]}" ]] ||
    die "published count mismatch for $table: expected ${EXPECTED_COUNT[$table]}, found $actual_count"

  backup_count="$(query_scalar \
    "SELECT COUNT(*) FROM \`$DBNAME\`.\`${BACKUP_TABLE[$table]}\`;")"
  [[ "$backup_count" == "${OLD_COUNT[$table]}" ]] ||
    die "backup count mismatch for ${BACKUP_TABLE[$table]}: expected ${OLD_COUNT[$table]}, found $backup_count"

  echo "  $table: published=$actual_count, backup=$backup_count"
done

validate_species_references "$DBNAME" "$DBNAME"
if [[ "$SCOPE" == "all" ]]; then
  validate_taxonomy_node_references "$DBNAME"
fi

END_TIME="$(date +%s)"
ELAPSED_TIME=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED_TIME / 60))
SECONDS=$((ELAPSED_TIME % 60))

echo "VMR update completed successfully."
echo "Rollback backup tables:"
for table in "${SELECTED_TABLES[@]}"; do
  echo "  ${BACKUP_TABLE[$table]}"
done
echo "Total execution time: ${MINUTES} minutes and ${SECONDS} seconds"
