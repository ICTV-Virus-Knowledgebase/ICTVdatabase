#!/usr/bin/env bash
#
# Restore VMR data from backup tables created by load_VMR_updates.sh.
#
# The original backup tables are never renamed, changed, or deleted. Before
# restoring them, this script creates another timestamped backup of the current
# live data so the restore itself can also be reversed.
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DBNAME="ictv_taxonomy_temp"
BACKUP_ID=""
SCOPE="auto"
DRY_RUN=0
ASSUME_YES=0
LIST_BACKUPS=0
POSITIONAL_COUNT=0

usage() {
  cat <<'EOF'
Usage:
  load_VMR_update_restore.sh --backup-id YYYYMMDD_HHMMSS [options]
  load_VMR_update_restore.sh [database] YYYYMMDD_HHMMSS [auto|species|all]
  load_VMR_update_restore.sh --list [--database NAME]

Options:
  -b, --backup-id ID    Backup timestamp created by load_VMR_updates.sh
  -d, --database NAME   Target database (default: ictv_taxonomy_temp)
  -s, --scope SCOPE     Restore scope: auto, species, or all (default: auto)
      --list             List available VMR backup sets and exit
      --dry-run          Validate the backup without changing database objects
  -y, --yes             Skip the restore confirmation
  -h, --help            Show this help

Scopes:
  auto     Infer species or all from the tables in the backup set.
  species  Restore species_isolates only.
  all      Restore species_isolates, taxonomy_genome_coverage,
           taxonomy_host_source, and taxonomy_molecule.

Examples:
  ./load_VMR_update_restore.sh --list
  ./load_VMR_update_restore.sh --backup-id 20260721_190520 --dry-run
  ./load_VMR_update_restore.sh \
    --database ictv_taxonomy --backup-id 20260721_190520 --scope all
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    -b|--backup-id)
      (($# >= 2)) || die "$1 requires a backup ID"
      BACKUP_ID="$2"
      shift 2
      ;;
    -d|--database)
      (($# >= 2)) || die "$1 requires a database name"
      DBNAME="$2"
      shift 2
      ;;
    -s|--scope)
      (($# >= 2)) || die "$1 requires auto, species, or all"
      SCOPE="$2"
      shift 2
      ;;
    --list)
      LIST_BACKUPS=1
      shift
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
        1) BACKUP_ID="$1" ;;
        2) SCOPE="$1" ;;
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
  auto|species|all) ;;
  *) die "scope must be auto, species, or all" ;;
esac

if ((LIST_BACKUPS == 0)); then
  [[ "$BACKUP_ID" =~ ^[0-9]{8}_[0-9]{6}$ ]] ||
    die "backup ID must use the format YYYYMMDD_HHMMSS"
fi

command -v mariadb >/dev/null 2>&1 ||
  die "the mariadb client is not installed or not on PATH"
command -v flock >/dev/null 2>&1 ||
  die "flock is required to prevent concurrent VMR updates and restores"
command -v tee >/dev/null 2>&1 || die "tee is required for logging"

cd "$SCRIPT_DIR"

exec > >(tee -a "$SCRIPT_DIR/db_vmr_restore.log") \
     2> >(tee -a "$SCRIPT_DIR/db_vmr_restore_error.log" >&2)

RUN_ID="$(date -u +%Y%m%d_%H%M%S)"
LOCK_FILE="/tmp/ictv_vmr_update_${DBNAME}.lock"

echo
echo "=== VMR restore run $RUN_ID UTC ==="
echo "Target database: $DBNAME"
echo "Requested backup ID: ${BACKUP_ID:-not applicable}"
echo "Requested scope: $SCOPE"
echo "Dry run: $DRY_RUN"

exec {LOCK_FD}>"$LOCK_FILE"
flock -n "$LOCK_FD" ||
  die "a VMR update or restore is already running for $DBNAME"

MARIADB_BASE=(
  mariadb
  --abort-source-on-error
  --default-character-set=utf8mb4
)
MARIADB_VERBOSE=("${MARIADB_BASE[@]}" --show-warnings)

query_scalar() {
  local sql="$1"
  "${MARIADB_BASE[@]}" --batch --skip-column-names --raw -e "$sql"
}

database_exists="$(query_scalar "
  SELECT COUNT(*)
  FROM information_schema.SCHEMATA
  WHERE SCHEMA_NAME = '$DBNAME';")"
[[ "$database_exists" == "1" ]] ||
  die "target database $DBNAME does not exist"

if ((LIST_BACKUPS == 1)); then
  echo "Available VMR backup sets:"
  "${MARIADB_BASE[@]}" --table -e "
    SELECT
      backup_id,
      CASE
        WHEN COUNT(*) = 1
          AND SUM(base_table = 'species_isolates') = 1
          THEN 'species'
        WHEN COUNT(DISTINCT base_table) = 4
          AND SUM(base_table = 'species_isolates') = 1
          AND SUM(base_table = 'taxonomy_genome_coverage') = 1
          AND SUM(base_table = 'taxonomy_host_source') = 1
          AND SUM(base_table = 'taxonomy_molecule') = 1
          THEN 'all'
        ELSE 'incomplete'
      END AS scope,
      GROUP_CONCAT(base_table ORDER BY base_table SEPARATOR ', ') AS tables
    FROM (
      SELECT
        SUBSTRING_INDEX(TABLE_NAME, '_bak_', -1) AS backup_id,
        LEFT(TABLE_NAME, LOCATE('_bak_', TABLE_NAME) - 1) AS base_table
      FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = '$DBNAME'
        AND TABLE_TYPE = 'BASE TABLE'
        AND (
          TABLE_NAME LIKE 'species_isolates_bak_%'
          OR TABLE_NAME LIKE 'taxonomy_genome_coverage_bak_%'
          OR TABLE_NAME LIKE 'taxonomy_host_source_bak_%'
          OR TABLE_NAME LIKE 'taxonomy_molecule_bak_%'
        )
    ) AS backups
    GROUP BY backup_id
    ORDER BY backup_id DESC;"
  exit 0
fi

declare -A SOURCE_TABLE=(
  [species_isolates]="species_isolates_bak_${BACKUP_ID}"
  [taxonomy_genome_coverage]="taxonomy_genome_coverage_bak_${BACKUP_ID}"
  [taxonomy_host_source]="taxonomy_host_source_bak_${BACKUP_ID}"
  [taxonomy_molecule]="taxonomy_molecule_bak_${BACKUP_ID}"
)

ALL_TABLES=(
  taxonomy_genome_coverage
  taxonomy_host_source
  taxonomy_molecule
  species_isolates
)

table_exists() {
  local table="$1"
  query_scalar "
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = '$DBNAME'
      AND TABLE_NAME = '$table'
      AND TABLE_TYPE = 'BASE TABLE'
      AND ENGINE = 'InnoDB';"
}

species_backup_exists="$(table_exists "${SOURCE_TABLE[species_isolates]}")"
parent_backup_count=0
for table in taxonomy_genome_coverage taxonomy_host_source taxonomy_molecule; do
  exists="$(table_exists "${SOURCE_TABLE[$table]}")"
  parent_backup_count=$((parent_backup_count + exists))
done

if [[ "$SCOPE" == "auto" ]]; then
  if [[ "$species_backup_exists" == "1" && "$parent_backup_count" == "3" ]]; then
    SCOPE="all"
  elif [[ "$species_backup_exists" == "1" && "$parent_backup_count" == "0" ]]; then
    SCOPE="species"
  else
    die "backup set $BACKUP_ID is missing tables or contains an incomplete scope"
  fi
fi

if [[ "$SCOPE" == "species" ]]; then
  [[ "$species_backup_exists" == "1" ]] ||
    die "backup table ${SOURCE_TABLE[species_isolates]} does not exist"
  SELECTED_TABLES=(species_isolates)
else
  [[ "$species_backup_exists" == "1" && "$parent_backup_count" == "3" ]] ||
    die "all four backup tables are required for scope all"
  SELECTED_TABLES=("${ALL_TABLES[@]}")
fi

echo "Resolved restore scope: $SCOPE"

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
    AND TABLE_TYPE = 'BASE TABLE'
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

validate_schema_match() {
  local live_table="$1"
  local backup_table="$2"

  validate_zero "$backup_table schema matches $live_table" "
    SELECT COUNT(*)
    FROM (
      SELECT live_cols.ORDINAL_POSITION
      FROM information_schema.COLUMNS AS live_cols
      LEFT JOIN information_schema.COLUMNS AS backup_cols
        ON backup_cols.TABLE_SCHEMA = '$DBNAME'
       AND backup_cols.TABLE_NAME = '$backup_table'
       AND backup_cols.ORDINAL_POSITION = live_cols.ORDINAL_POSITION
      WHERE live_cols.TABLE_SCHEMA = '$DBNAME'
        AND live_cols.TABLE_NAME = '$live_table'
        AND NOT (
          live_cols.COLUMN_NAME <=> backup_cols.COLUMN_NAME
          AND live_cols.COLUMN_TYPE <=> backup_cols.COLUMN_TYPE
          AND live_cols.IS_NULLABLE <=> backup_cols.IS_NULLABLE
          AND live_cols.COLUMN_DEFAULT <=> backup_cols.COLUMN_DEFAULT
          AND live_cols.EXTRA <=> backup_cols.EXTRA
          AND live_cols.GENERATION_EXPRESSION <=> backup_cols.GENERATION_EXPRESSION
          AND live_cols.CHARACTER_SET_NAME <=> backup_cols.CHARACTER_SET_NAME
          AND live_cols.COLLATION_NAME <=> backup_cols.COLLATION_NAME
        )

      UNION ALL

      SELECT backup_cols.ORDINAL_POSITION
      FROM information_schema.COLUMNS AS backup_cols
      LEFT JOIN information_schema.COLUMNS AS live_cols
        ON live_cols.TABLE_SCHEMA = '$DBNAME'
       AND live_cols.TABLE_NAME = '$live_table'
       AND live_cols.ORDINAL_POSITION = backup_cols.ORDINAL_POSITION
      WHERE backup_cols.TABLE_SCHEMA = '$DBNAME'
        AND backup_cols.TABLE_NAME = '$backup_table'
        AND live_cols.COLUMN_NAME IS NULL
    ) AS schema_differences;"
}

validate_species_references() {
  local species_table="$1"
  local genome_table="$2"
  local host_table="$3"
  local molecule_table="$4"

  validate_zero "backup species taxnode_id values exist" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.\`$species_table\` AS si
    LEFT JOIN \`$DBNAME\`.taxonomy_node AS tn
      ON tn.taxnode_id = si.taxnode_id
    WHERE si.taxnode_id IS NOT NULL
      AND tn.taxnode_id IS NULL;"

  validate_zero "backup species update_prev_taxnode_id values exist" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.\`$species_table\` AS si
    LEFT JOIN \`$DBNAME\`.taxonomy_node AS tn
      ON tn.taxnode_id = si.update_prev_taxnode_id
    WHERE si.update_prev_taxnode_id IS NOT NULL
      AND tn.taxnode_id IS NULL;"

  validate_zero "backup species genome_coverage values exist" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.\`$species_table\` AS si
    LEFT JOIN \`$DBNAME\`.\`$genome_table\` AS gc
      ON gc.name = si.genome_coverage
    WHERE si.genome_coverage IS NOT NULL
      AND gc.genome_coverage IS NULL;"

  validate_zero "backup species host_source values exist" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.\`$species_table\` AS si
    LEFT JOIN \`$DBNAME\`.\`$host_table\` AS hs
      ON hs.host_source = si.host_source
    WHERE si.host_source IS NOT NULL
      AND hs.host_source IS NULL;"

  validate_zero "backup species molecule values exist" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.\`$species_table\` AS si
    LEFT JOIN \`$DBNAME\`.\`$molecule_table\` AS tm
      ON tm.abbrev = si.molecule
    WHERE si.molecule IS NOT NULL
      AND tm.id IS NULL;"
}

validate_taxonomy_node_references() {
  local genome_table="$1"
  local host_table="$2"
  local molecule_table="$3"

  validate_zero "taxonomy_node genome_coverage values remain valid" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.taxonomy_node AS tn
    LEFT JOIN \`$DBNAME\`.\`$genome_table\` AS gc
      ON gc.genome_coverage = tn.genome_coverage
    WHERE tn.genome_coverage IS NOT NULL
      AND gc.genome_coverage IS NULL;"

  validate_zero "taxonomy_node host_source values remain valid" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.taxonomy_node AS tn
    LEFT JOIN \`$DBNAME\`.\`$host_table\` AS hs
      ON hs.host_source = tn.host_source
    WHERE tn.host_source IS NOT NULL
      AND hs.host_source IS NULL;"

  validate_zero "taxonomy_node molecule_id values remain valid" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.taxonomy_node AS tn
    LEFT JOIN \`$DBNAME\`.\`$molecule_table\` AS tm
      ON tm.id = tn.molecule_id
    WHERE tn.molecule_id IS NOT NULL
      AND tm.id IS NULL;"

  validate_zero "taxonomy_node inher_molecule_id values remain valid" "
    SELECT COUNT(*)
    FROM \`$DBNAME\`.taxonomy_node AS tn
    LEFT JOIN \`$DBNAME\`.\`$molecule_table\` AS tm
      ON tm.id = tn.inher_molecule_id
    WHERE tn.inher_molecule_id IS NOT NULL
      AND tm.id IS NULL;"
}

declare -A SOURCE_COUNT=()
declare -A CURRENT_COUNT=()
declare -A SAFETY_TABLE=()
CREATED_SAFETY_BACKUPS=()
RESTORE_COMMITTED=0

cleanup() {
  local status=$?
  trap - EXIT
  set +e

  if ((status != 0 && RESTORE_COMMITTED == 0 &&
      ${#CREATED_SAFETY_BACKUPS[@]} > 0)); then
    echo "Removing empty pre-restore safety backup tables." >&2
    for table in "${CREATED_SAFETY_BACKUPS[@]}"; do
      "${MARIADB_BASE[@]}" -D "$DBNAME" \
        -e "DROP TABLE IF EXISTS \`$table\`;" >/dev/null 2>&1
    done
  fi

  if ((status != 0)); then
    if ((RESTORE_COMMITTED == 1)); then
      echo "The restore committed, but post-restore validation failed." >&2
      echo "The source and pre-restore safety backups were retained." >&2
    else
      echo "The restore failed before commit; live-table DML was rolled back." >&2
    fi
  fi

  exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "Validating source backup set"
for table in "${SELECTED_TABLES[@]}"; do
  source_table="${SOURCE_TABLE[$table]}"
  validate_schema_match "$table" "$source_table"

  SOURCE_COUNT[$table]="$(query_scalar "
    SELECT COUNT(*) FROM \`$DBNAME\`.\`$source_table\`;")"
  CURRENT_COUNT[$table]="$(query_scalar "
    SELECT COUNT(*) FROM \`$DBNAME\`.\`$table\`;")"

  [[ "${SOURCE_COUNT[$table]}" =~ ^[0-9]+$ ]] ||
    die "backup count for $source_table is not numeric"
  ((${SOURCE_COUNT[$table]} > 0)) ||
    die "backup table $source_table is empty"

  echo "  $table: current=${CURRENT_COUNT[$table]}, backup=${SOURCE_COUNT[$table]}"
done

if [[ "$SCOPE" == "all" ]]; then
  validate_zero "backup taxonomy_genome_coverage names are unique" "
    SELECT COUNT(*) FROM (
      SELECT name
      FROM \`$DBNAME\`.\`${SOURCE_TABLE[taxonomy_genome_coverage]}\`
      WHERE name IS NOT NULL
      GROUP BY name
      HAVING COUNT(*) > 1
    ) AS duplicates;"

  validate_zero "backup taxonomy_molecule abbreviations are unique" "
    SELECT COUNT(*) FROM (
      SELECT abbrev
      FROM \`$DBNAME\`.\`${SOURCE_TABLE[taxonomy_molecule]}\`
      GROUP BY abbrev
      HAVING COUNT(*) > 1
    ) AS duplicates;"

  GENOME_SOURCE="${SOURCE_TABLE[taxonomy_genome_coverage]}"
  HOST_SOURCE="${SOURCE_TABLE[taxonomy_host_source]}"
  MOLECULE_SOURCE="${SOURCE_TABLE[taxonomy_molecule]}"

  validate_taxonomy_node_references \
    "$GENOME_SOURCE" "$HOST_SOURCE" "$MOLECULE_SOURCE"
else
  GENOME_SOURCE="taxonomy_genome_coverage"
  HOST_SOURCE="taxonomy_host_source"
  MOLECULE_SOURCE="taxonomy_molecule"
fi

validate_species_references \
  "${SOURCE_TABLE[species_isolates]}" \
  "$GENOME_SOURCE" "$HOST_SOURCE" "$MOLECULE_SOURCE"

if ((DRY_RUN == 1)); then
  echo "Restore dry run completed successfully; no database objects were changed."
  exit 0
fi

if ((ASSUME_YES == 0)); then
  [[ -t 0 ]] ||
    die "restores require --yes when input is not interactive"
  read -r -p \
    "Restore backup $BACKUP_ID into $DBNAME? Type 'restore $BACKUP_ID' to continue: " \
    answer
  [[ "$answer" == "restore $BACKUP_ID" ]] || die "restore cancelled"
fi

START_TIME="$(date +%s)"

echo "Creating pre-restore safety backup tables"
for table in "${SELECTED_TABLES[@]}"; do
  safety_table="${table}_bak_${RUN_ID}"
  [[ ${#safety_table} -le 64 ]] ||
    die "safety backup table name is too long: $safety_table"
  [[ "$(table_exists "$safety_table")" == "0" ]] ||
    die "safety backup table already exists: $safety_table"

  SAFETY_TABLE[$table]="$safety_table"
  "${MARIADB_VERBOSE[@]}" -D "$DBNAME" -vvv -e \
    "CREATE TABLE \`$safety_table\` LIKE \`$table\`;"
  CREATED_SAFETY_BACKUPS+=("$safety_table")
done

echo "Restoring VMR data from backup $BACKUP_ID"

if [[ "$SCOPE" == "species" ]]; then
  "${MARIADB_VERBOSE[@]}" -D "$DBNAME" -vvv <<SQL
SET SESSION foreign_key_checks = 1;
START TRANSACTION;

INSERT INTO \`${SAFETY_TABLE[species_isolates]}\` (
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
FROM \`${SOURCE_TABLE[species_isolates]}\`;

COMMIT;
SQL
else
  "${MARIADB_VERBOSE[@]}" -D "$DBNAME" -vvv <<SQL
SET SESSION foreign_key_checks = 1;
START TRANSACTION;

INSERT INTO \`${SAFETY_TABLE[taxonomy_genome_coverage]}\`
  (genome_coverage, name, priority)
SELECT genome_coverage, name, priority
FROM taxonomy_genome_coverage;

INSERT INTO \`${SAFETY_TABLE[taxonomy_host_source]}\` (host_source)
SELECT host_source
FROM taxonomy_host_source;

INSERT INTO \`${SAFETY_TABLE[taxonomy_molecule]}\`
  (id, abbrev, name, balt_group, balt_roman, description, left_idx, right_idx)
SELECT id, abbrev, name, balt_group, balt_roman, description, left_idx, right_idx
FROM taxonomy_molecule;

INSERT INTO \`${SAFETY_TABLE[species_isolates]}\` (
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

INSERT INTO taxonomy_genome_coverage (genome_coverage, name, priority)
SELECT genome_coverage, name, priority
FROM \`${SOURCE_TABLE[taxonomy_genome_coverage]}\`
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  priority = VALUES(priority);

INSERT INTO taxonomy_host_source (host_source)
SELECT source_hs.host_source
FROM \`${SOURCE_TABLE[taxonomy_host_source]}\` AS source_hs
LEFT JOIN taxonomy_host_source AS live_hs
  ON live_hs.host_source = source_hs.host_source
WHERE live_hs.host_source IS NULL;

INSERT INTO taxonomy_molecule
  (id, abbrev, name, balt_group, balt_roman, description, left_idx, right_idx)
SELECT id, abbrev, name, balt_group, balt_roman, description, left_idx, right_idx
FROM \`${SOURCE_TABLE[taxonomy_molecule]}\`
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
LEFT JOIN \`${SOURCE_TABLE[taxonomy_genome_coverage]}\` AS source_gc
  ON source_gc.genome_coverage = live_gc.genome_coverage
WHERE source_gc.genome_coverage IS NULL;

DELETE live_hs
FROM taxonomy_host_source AS live_hs
LEFT JOIN \`${SOURCE_TABLE[taxonomy_host_source]}\` AS source_hs
  ON source_hs.host_source = live_hs.host_source
WHERE source_hs.host_source IS NULL;

DELETE live_tm
FROM taxonomy_molecule AS live_tm
LEFT JOIN \`${SOURCE_TABLE[taxonomy_molecule]}\` AS source_tm
  ON source_tm.id = live_tm.id
WHERE source_tm.id IS NULL;

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
FROM \`${SOURCE_TABLE[species_isolates]}\`;

COMMIT;
SQL
fi

RESTORE_COMMITTED=1

echo "Running post-restore validation"
for table in "${SELECTED_TABLES[@]}"; do
  restored_count="$(query_scalar "
    SELECT COUNT(*) FROM \`$DBNAME\`.\`$table\`;")"
  [[ "$restored_count" == "${SOURCE_COUNT[$table]}" ]] ||
    die "restored count mismatch for $table: expected ${SOURCE_COUNT[$table]}, found $restored_count"

  safety_count="$(query_scalar "
    SELECT COUNT(*) FROM \`$DBNAME\`.\`${SAFETY_TABLE[$table]}\`;")"
  [[ "$safety_count" == "${CURRENT_COUNT[$table]}" ]] ||
    die "safety backup count mismatch for ${SAFETY_TABLE[$table]}: expected ${CURRENT_COUNT[$table]}, found $safety_count"

  echo "  $table: restored=$restored_count, pre-restore backup=$safety_count"
done

validate_species_references \
  "species_isolates" \
  "taxonomy_genome_coverage" \
  "taxonomy_host_source" \
  "taxonomy_molecule"

if [[ "$SCOPE" == "all" ]]; then
  validate_taxonomy_node_references \
    "taxonomy_genome_coverage" \
    "taxonomy_host_source" \
    "taxonomy_molecule"
fi

END_TIME="$(date +%s)"
ELAPSED_TIME=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED_TIME / 60))
SECONDS=$((ELAPSED_TIME % 60))

echo "VMR restore completed successfully."
echo "Restored from backup tables:"
for table in "${SELECTED_TABLES[@]}"; do
  echo "  ${SOURCE_TABLE[$table]}"
done
echo "Pre-restore safety backup tables:"
for table in "${SELECTED_TABLES[@]}"; do
  echo "  ${SAFETY_TABLE[$table]}"
done
echo "The source backup tables were not modified."
echo "Total execution time: ${MINUTES} minutes and ${SECONDS} seconds"
