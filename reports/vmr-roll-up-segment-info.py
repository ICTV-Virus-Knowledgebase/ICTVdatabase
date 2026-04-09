#!/usr/bin/env python3
"""Roll up segment metadata from vmr-add-segment-info.py output."""

from __future__ import annotations

import argparse
import csv
import sys
from collections import OrderedDict
from pathlib import Path
from typing import TextIO


COUNT_COLUMN = "segment_count"
NAMES_COLUMN = "segment_names"
DEFAULT_GROUP = ["ICTV_ID", "Family", "Genus", "Species"]
OUT_COLUMNS = ("segments_consistent", "segment_counts", "segment_name_lists")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Group vmr-add-segment-info.py output and roll up segment consistency."
        )
    )
    parser.add_argument(
        "-i",
        "--in",
        "--vmr",
        dest="vmr",
        default="-",
        help="Input TSV file from vmr-add-segment-info.py. Use '-' for stdin.",
    )
    parser.add_argument(
        "--group",
        nargs="+",
        default=DEFAULT_GROUP,
        help=(
            "Group-by columns. Accepts repeated names and/or comma-separated lists. "
            f"Default: {','.join(DEFAULT_GROUP)}"
        ),
    )
    parser.add_argument(
        "-o",
        "--out",
        default="-",
        help="Output TSV file. Use '-' for stdout. Default: %(default)s",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Log per-row processing details to stderr.",
    )
    return parser.parse_args()


def normalize_group_columns(raw_values: list[str]) -> list[str]:
    group_cols: list[str] = []
    for value in raw_values:
        for part in value.split(","):
            name = part.strip()
            if name:
                group_cols.append(name)
    return group_cols


def open_input(path_str: str) -> tuple[str, TextIO]:
    if path_str == "-":
        return "<stdin>", sys.stdin
    path = Path(path_str)
    try:
        handle = path.open("r", encoding="utf-8", newline="")
    except FileNotFoundError as exc:
        raise SystemExit(f"Input file not found: {path}") from exc
    return str(path), handle


def open_output(path_str: str) -> tuple[str, TextIO]:
    if path_str == "-":
        return "<stdout>", sys.stdout
    path = Path(path_str)
    try:
        handle = path.open("w", encoding="utf-8", newline="")
    except OSError as exc:
        raise SystemExit(f"Could not open output file for writing: {path}") from exc
    return str(path), handle


def summarize_file(kind: str, filename: str, row_count: int, col_count: int) -> None:
    print(
        f"{kind}: {filename} rows={row_count} cols={col_count}",
        file=sys.stderr,
    )


def pair_sort_key(item: tuple[str, str, int]) -> tuple[int, int]:
    count_text, _names_text, first_seen = item
    try:
        count_value = int(count_text)
    except ValueError:
        count_value = 10**9
    return count_value, first_seen


def main() -> int:
    args = parse_args()
    group_columns = normalize_group_columns(args.group)
    if not group_columns:
        raise SystemExit("At least one --group column is required.")

    input_name, input_handle = open_input(args.vmr)
    output_name, output_handle = open_output(args.out)

    if args.vmr != "-" and args.out != "-":
        in_path = Path(args.vmr).resolve()
        out_path = Path(args.out).resolve()
        if in_path == out_path:
            raise SystemExit("Refusing to overwrite the input file in place.")

    input_rows = 0
    input_cols = 0
    output_rows = 0
    output_cols = len(group_columns) + len(OUT_COLUMNS)
    groups: OrderedDict[tuple[str, ...], OrderedDict[tuple[str, str], int]] = OrderedDict()

    with input_handle:
        reader = csv.DictReader(input_handle, delimiter="\t")
        if reader.fieldnames is None:
            raise SystemExit(f"Input file has no header row: {input_name}")

        input_cols = len(reader.fieldnames)
        required = group_columns + [COUNT_COLUMN, NAMES_COLUMN]
        missing = [name for name in required if name not in reader.fieldnames]
        if missing:
            raise SystemExit(
                f"Input file is missing required columns: {', '.join(missing)}"
            )

        seen_index = 0
        for line_number, row in enumerate(reader, start=2):
            input_rows += 1
            group_key = tuple(row[col] for col in group_columns)
            pair = (row[COUNT_COLUMN], row[NAMES_COLUMN])

            if group_key not in groups:
                groups[group_key] = OrderedDict()
            if pair not in groups[group_key]:
                groups[group_key][pair] = seen_index
                seen_index += 1

            if args.verbose:
                group_text = ",".join(
                    f"{col}={row[col]!r}" for col in group_columns
                )
                print(
                    (
                        f"line={line_number} {group_text} "
                        f"segment_count={row[COUNT_COLUMN]!r} "
                        f"segment_names={row[NAMES_COLUMN]!r}"
                    ),
                    file=sys.stderr,
                )

    fieldnames = group_columns + list(OUT_COLUMNS)
    writer = csv.DictWriter(
        output_handle,
        fieldnames=fieldnames,
        delimiter="\t",
        lineterminator="\n",
    )
    writer.writeheader()

    for group_key, pair_map in groups.items():
        ordered_pairs = sorted(
            ((count, names, first_seen) for (count, names), first_seen in pair_map.items()),
            key=pair_sort_key,
        )
        counts = ";".join(count for count, _names, _seen in ordered_pairs)
        names = ";".join(name_list for _count, name_list, _seen in ordered_pairs)
        consistent = "yes" if len(ordered_pairs) == 1 else "no"

        row = {col: value for col, value in zip(group_columns, group_key)}
        row["segments_consistent"] = consistent
        row["segment_counts"] = counts
        row["segment_name_lists"] = names
        writer.writerow(row)
        output_rows += 1

    if output_handle is not sys.stdout:
        output_handle.close()

    summarize_file("Read", input_name, input_rows, input_cols)
    summarize_file("Wrote", output_name, output_rows, output_cols)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
