#!/usr/bin/env python3
"""Append segment metadata columns to an ICTV VMR export TSV."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Iterable, TextIO

# input column names
ACC_COLUMN = "Virus GENBANK accession"
COV_COLUMN = "Genome coverage"

# output column names
OUT_COLUMNS = ("segment_count", "segment_names")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Read a VMR TSV and append segment_count and segment_names columns."
        )
    )
    parser.add_argument(
        "-i",
        "--in",
        "--vmr",
        dest="vmr",
        default="../data/vmr_export.utf8.txt",
        help="Input VMR TSV file. Default: %(default)s",
    )
    parser.add_argument(
        "-o",
        "--out",
        default="-",
        help="Output TSV file. Use '-' for stdout. Default: %(default)s",
    )
    parser.add_argument(
        "-n",
        "--unnamed-seg",
        default="-",
        help="Placeholder for unnamed segments. Default: %(default)s",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Log per-row processing details to stderr.",
    )
    return parser.parse_args()


def open_input(path_str: str) -> tuple[Path, TextIO]:
    path = Path(path_str)
    try:
        handle = path.open("r", encoding="utf-8", newline="")
    except FileNotFoundError as exc:
        raise SystemExit(f"Input file not found: {path}") from exc
    return path, handle


def open_output(path_str: str) -> tuple[str, TextIO]:
    if path_str == "-":
        return "<stdout>", sys.stdout
    path = Path(path_str)
    try:
        handle = path.open("w", encoding="utf-8", newline="")
    except OSError as exc:
        raise SystemExit(f"Could not open output file for writing: {path}") from exc
    return str(path), handle


def should_mark_unknown(acc: str, cov: str) -> bool:
    return bool(
        re.search(r"partial", acc, flags=re.IGNORECASE)
        or re.search(r"no entry", cov, flags=re.IGNORECASE)
        or re.search(r"partial", cov, flags=re.IGNORECASE)
    )


def split_segments(acc: str) -> list[str]:
    return [part.strip() for part in acc.split(";") if part.strip()]


def extract_segment_names(segments: Iterable[str], unnamed_seg: str) -> list[str]:
    names: list[str] = []
    for segment in segments:
        if ":" in segment:
            raw_name, _raw_accession = segment.split(":", 1)
            name = raw_name.strip() or unnamed_seg
        else:
            name = unnamed_seg
        names.append(name)
    return names


def summarize_file(kind: str, filename: str, row_count: int, col_count: int) -> None:
    print(
        f"{kind}: {filename} rows={row_count} cols={col_count}",
        file=sys.stderr,
    )


def main() -> int:
    args = parse_args()
    input_path, input_handle = open_input(args.vmr)
    output_name, output_handle = open_output(args.out)

    if args.out != "-" and Path(args.out).resolve() == input_path.resolve():
        raise SystemExit("Refusing to overwrite the input file in place.")

    row_count = 0
    input_col_count = 0
    output_col_count = 0

    with input_handle:
        header_line = input_handle.readline()
        if not header_line:
            raise SystemExit(f"Input file has no header row: {input_path}")

        header = header_line.rstrip("\r\n").split("\t")
        missing = [name for name in (ACC_COLUMN, COV_COLUMN) if name not in header]
        if missing:
            raise SystemExit(
                f"Input file is missing required columns: {', '.join(missing)}"
            )

        acc_idx = header.index(ACC_COLUMN)
        cov_idx = header.index(COV_COLUMN)
        input_col_count = len(header)
        output_col_count = input_col_count + len(OUT_COLUMNS)
        output_handle.write(
            header_line.rstrip("\r\n") + "\t" + "\t".join(OUT_COLUMNS) + "\n"
        )

        for line_number, raw_line in enumerate(input_handle, start=2):
            row_count += 1
            line = raw_line.rstrip("\r\n")
            fields = line.split("\t")

            if len(fields) != input_col_count:
                raise SystemExit(
                    f"Line {line_number} has {len(fields)} columns, expected {input_col_count}"
                )

            acc = fields[acc_idx]
            cov = fields[cov_idx]

            if should_mark_unknown(acc, cov):
                segment_count = -1
                segment_names = args.unnamed_seg
            else:
                segments = split_segments(acc)
                segment_count = len(segments)
                names = extract_segment_names(segments, args.unnamed_seg)
                segment_names = ",".join(names)

            if args.verbose:
                print(
                    (
                        f"line={line_number} acc={acc!r} cov={cov!r} "
                        f"segment_count={segment_count} segment_names={segment_names!r}"
                    ),
                    file=sys.stderr,
                )

            output_handle.write(f"{line}\t{segment_count}\t{segment_names}\n")

    if output_handle is not sys.stdout:
        output_handle.close()

    summarize_file("Read", str(input_path), row_count, input_col_count)
    summarize_file("Wrote", output_name, row_count, output_col_count)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
