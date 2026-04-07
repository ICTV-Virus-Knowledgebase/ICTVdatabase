#!/usr/bin/env python3
"""Generate the NCBI LinkOut full-text export from MariaDB."""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path

DEFAULT_BASE_URL_SUFFIX = "taxonomy/taxondetails?taxnode_id="
DEFAULT_DATABASE = "ictv_taxonomy"
SEPARATOR = "---------------------------------------------------------------"


def parse_args() -> argparse.Namespace:
    # Keep the script self-contained inside ncbi_linkout/ so it can be run
    # from anywhere without requiring the caller to pass XML/output paths.
    script_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description=(
            "Export the ICTV taxonomy LinkOut file by querying MariaDB through "
            "the mariadb CLI and writing the final .ft file directly."
        )
    )
    parser.add_argument(
        "--msl",
        type=int,
        help="MSL release number to export. Uses the latest release if omitted or less than 1.",
    )
    parser.add_argument(
        "--database",
        default=DEFAULT_DATABASE,
        help=f"MariaDB database name. Defaults to {DEFAULT_DATABASE}.",
    )
    parser.add_argument(
        "--provider-info",
        type=Path,
        default=script_dir / "providerinfo.xml",
        help="Path to providerinfo.xml. Defaults to the copy in ncbi_linkout/.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=script_dir / "ncbi_linkout.ft",
        help="Destination .ft file. Defaults to ncbi_linkout/ncbi_linkout.ft.",
    )
    parser.add_argument(
        "--base-url-suffix",
        default=DEFAULT_BASE_URL_SUFFIX,
        help=(
            "Suffix appended to the provider root URL from providerinfo.xml. "
            f"Defaults to {DEFAULT_BASE_URL_SUFFIX!r}."
        ),
    )
    parser.add_argument(
        "--newline-style",
        choices=("lf", "crlf"),
        default="lf",
        help="Line ending style for the output file. Defaults to lf.",
    )
    parser.add_argument(
        "--mariadb",
        default="mariadb",
        help="MariaDB client binary to invoke. Defaults to mariadb.",
    )
    parser.add_argument(
        "--defaults-file",
        help="Optional MariaDB defaults file passed as --defaults-file=PATH.",
    )
    parser.add_argument(
        "--defaults-extra-file",
        help="Optional MariaDB defaults file passed as --defaults-extra-file=PATH.",
    )
    parser.add_argument("--host", help="MariaDB host.")
    parser.add_argument("--port", type=int, help="MariaDB TCP port.")
    parser.add_argument("--socket", help="MariaDB Unix socket path.")
    parser.add_argument("--user", help="MariaDB user name.")
    return parser.parse_args()


def load_provider_info(path: Path) -> tuple[str, str]:
    # providerinfo.xml is the authoritative source for the LinkOut provider
    # metadata that should not be duplicated in the exporter.
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, OSError) as exc:
        raise RuntimeError(f"Unable to read provider info XML at {path}: {exc}") from exc

    provider_id = (root.findtext("ProviderId") or "").strip()
    provider_url = (root.findtext("Url") or "").strip()
    if not provider_id:
        raise RuntimeError(f"ProviderId is missing in {path}")
    if not provider_url:
        raise RuntimeError(f"Url is missing in {path}")
    return provider_id, provider_url


def build_base_url(provider_url: str, suffix: str) -> str:
    # providerinfo.xml only stores the site root, so the taxonomy-specific
    # LinkOut suffix stays in Python for now.
    return f"{provider_url.rstrip('/')}/{suffix.lstrip('/')}"


def build_mariadb_command(args: argparse.Namespace, sql: str) -> list[str]:
    # Use the mariadb CLI instead of a Python DB driver so the script works
    # with the same local authentication flow as the existing shell workflow.
    command = [args.mariadb]
    if args.defaults_file:
        command.append(f"--defaults-file={args.defaults_file}")
    if args.defaults_extra_file:
        command.append(f"--defaults-extra-file={args.defaults_extra_file}")

    command.extend(["--batch", "--raw", "--skip-column-names"])

    if args.host:
        command.append(f"--host={args.host}")
    if args.port:
        command.append(f"--port={args.port}")
    if args.socket:
        command.append(f"--socket={args.socket}")
    if args.user:
        command.append(f"--user={args.user}")

    command.extend(["-D", args.database, "-e", sql])
    return command


def run_mariadb_sql(args: argparse.Namespace, sql: str) -> str:
    command = build_mariadb_command(args, sql)
    result = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip() or "MariaDB command failed without stderr output."
        raise RuntimeError(stderr)
    return result.stdout


def resolve_msl(args: argparse.Namespace) -> int:
    # Match the stored procedure behavior: if the caller does not choose an
    # MSL explicitly, export the latest release present in taxonomy_node.
    if args.msl is not None and args.msl > 0:
        return args.msl

    output = run_mariadb_sql(args, "SELECT MAX(msl_release_num) FROM taxonomy_node;")
    msl = output.strip()
    if not msl:
        raise RuntimeError("Could not resolve the latest MSL release number from taxonomy_node.")
    return int(msl)


def normalize_group_name(name: str) -> str:
    # MariaDB's default collation in this database is accent-insensitive, which
    # causes names like "Junin virus" and "Junín virus" to
    # collapse into one GROUP BY bucket. Normalize to NFC first so canonically
    # equivalent Unicode spellings still match, then casefold so case-only
    # variants continue to group together.
    return unicodedata.normalize("NFC", name).casefold()


def fetch_linkout_rows(args: argparse.Namespace, msl: int) -> list[tuple[str, str]]:
    # This follows the original SQL Server procedure behavior of including all
    # names up to the selected MSL, not only the rows from the exact release.
    #
    # Raw rows are fetched first and grouped in Python so accent-preserving
    # names such as "Junín" and "Junin" remain distinct even though the
    # MariaDB collation treats them as equal in SQL GROUP BY.
    #
    # left_idx remains the primary sort key because that is what the stored
    # procedure used. name/taxnode_id are added as tie-breakers so repeated
    # exports are deterministic when multiple rows share the same left_idx.
    sql = f"""
SELECT
    left_idx,
    msl_release_num,
    taxnode_id,
    name
FROM taxonomy_node_names
WHERE msl_release_num <= {msl}
  AND name IS NOT NULL
  AND name <> 'Unassigned'
ORDER BY left_idx, name, taxnode_id;
""".strip()
    output = run_mariadb_sql(args, sql)
    reader = csv.reader(output.splitlines(), delimiter="\t")

    grouped_rows: dict[str, dict[str, int | str]] = {}
    for line_number, row in enumerate(reader, start=1):
        if not row:
            continue
        if len(row) != 4:
            raise RuntimeError(
                f"Unexpected row shape from MariaDB at output line {line_number}: {row!r}"
            )
        left_idx_str, msl_release_num_str, taxnode_id_str, name = row
        left_idx = int(left_idx_str)
        msl_release_num = int(msl_release_num_str)
        taxnode_id = int(taxnode_id_str)
        group_key = normalize_group_name(name)

        existing = grouped_rows.get(group_key)
        if existing is None:
            grouped_rows[group_key] = {
                "left_idx": left_idx,
                "msl_release_num": msl_release_num,
                "taxnode_id": taxnode_id,
                "name": name,
            }
            continue

        if left_idx > int(existing["left_idx"]):
            existing["left_idx"] = left_idx
        if taxnode_id > int(existing["taxnode_id"]):
            existing["taxnode_id"] = taxnode_id

        # Prefer the latest visible spelling/capitalization for the emitted
        # name while still preserving the historical max(taxnode_id) behavior.
        if (
            msl_release_num > int(existing["msl_release_num"])
            or (
                msl_release_num == int(existing["msl_release_num"])
                and taxnode_id >= int(existing["taxnode_id"])
            )
        ):
            existing["msl_release_num"] = msl_release_num
            existing["name"] = name

    rows = [
        (str(int(item["taxnode_id"])), str(item["name"]))
        for item in sorted(
            grouped_rows.values(),
            key=lambda item: (int(item["left_idx"]), str(item["name"]), int(item["taxnode_id"])),
        )
    ]
    return rows


def render_linkout(provider_id: str, base_url: str, rows: list[tuple[str, str]], newline: str) -> str:
    # NCBI expects a header block followed by one repeated block per taxon.
    # Build the file as logical lines first, then join once with the selected
    # newline style so we never need a post-processing cleanup script.
    lines = [
        SEPARATOR,
        f"prid:   {provider_id}",
        "dbase:  taxonomy",
        "stype:  taxonomy/phylogenetic",
        f"!base:  {base_url}",
        SEPARATOR,
    ]

    for taxnode_id, name in rows:
        lines.extend(
            [
                f"linkid:   {taxnode_id}",
                f"query:  {name} [name]",
                "base:  &base;",
                f"rule:  {taxnode_id}",
                f"name:  {name}",
                SEPARATOR,
            ]
        )

    return newline.join(lines) + newline


def main() -> int:
    args = parse_args()
    provider_id, provider_url = load_provider_info(args.provider_info)
    base_url = build_base_url(provider_url, args.base_url_suffix)
    newline = "\n" if args.newline_style == "lf" else "\r\n"

    # Resolve metadata first, then fetch the rows, then render/write the final
    # file. Keeping these phases separate makes the export easier to inspect.
    msl = resolve_msl(args)
    rows = fetch_linkout_rows(args, msl)
    output_text = render_linkout(provider_id, base_url, rows, newline)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(output_text, encoding="utf-8", newline="")

    print(f"Wrote {len(rows)} linkout records for MSL {msl} to {args.output}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
