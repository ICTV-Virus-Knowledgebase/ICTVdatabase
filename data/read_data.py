"""Minimal example for loading the ICTV taxonomy TSV into pandas."""

import io
import re
from pathlib import Path

import pandas as pd


ICTV_TSV_NULL_FIELD_RE = re.compile(
    r"(^|\t)\\N(?=\t|\r?\n|$)", re.MULTILINE
)


def read_ictv_tsv(path, **kwargs):
    """Read an ICTV TSV export into a pandas DataFrame."""
    with open(path, encoding="utf-8", newline="") as file:
        content = file.read()

    # With escapechar enabled, pandas strips the backslash from unquoted \N values.
    content = ICTV_TSV_NULL_FIELD_RE.sub(r"\1", content)

    read_csv_kwargs = {
        "sep": "\t",
        "dtype": str,
        "escapechar": "\\",
        "keep_default_na": True,
        "na_values": ["NULL"],
    }
    read_csv_kwargs.update(kwargs)

    return pd.read_csv(io.StringIO(content), **read_csv_kwargs)


def main():
    taxonomy_file = Path(__file__).with_name("taxonomy_node_export.utf8.txt")
    taxonomy = read_ictv_tsv(
        taxonomy_file,
        on_bad_lines=lambda row: row[:-1],
        engine="python",
    )

    print(f"Loaded {len(taxonomy):,} rows and {len(taxonomy.columns)} columns")
    print(taxonomy.head())


if __name__ == "__main__":
    main()
