#!/usr/bin/env bash
# Run the workbook converter in a dedicated, reusable virtual environment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${ICTV_XLSX_VENV:-$SCRIPT_DIR/.venv-xlsx}"

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  echo "Creating XLSX export environment: $VENV_DIR"
  python3 -m venv "$VENV_DIR"
fi

# Avoid network access on subsequent exports when pinned dependencies are present.
if ! "$VENV_DIR/bin/python" - "$SCRIPT_DIR/requirements-xlsx.txt" <<'PY'
import sys
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path

for line in Path(sys.argv[1]).read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    name, required = line.split("==")
    try:
        if version(name) != required:
            sys.exit(1)
    except PackageNotFoundError:
        sys.exit(1)
PY
then
  "$VENV_DIR/bin/python" -m pip install -r "$SCRIPT_DIR/requirements-xlsx.txt"
fi

exec "$VENV_DIR/bin/python" "$SCRIPT_DIR/tsv_to_xlsx.py" "$@"
