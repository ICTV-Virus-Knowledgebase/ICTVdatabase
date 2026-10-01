# MariaDB exports

Run `bash schema/mariadb/export/exportTables.sh` from the repository root.
The special case taxa report is exported to TSV, converted to
`data/report.special_case_taxa.xlsx`, and its TSV
is deleted only after successful conversion. Other exports retain their TSV files.
If conversion fails, the TSV and any previous workbook remain available.

## Python environment for XLSX

`exportXlsx.sh` automatically creates `schema/mariadb/export/.venv-xlsx` on first
use and installs the pinned packages in `requirements-xlsx.txt` there. It requires
Python 3.9 or newer with `venv`/pip support and package access for initial setup.
The environment is ignored by Git and reused without installing packages again
unless the pinned versions change. System Python and any activated environment
are not modified. No environment activation is required.

To use a different dedicated virtual environment, set `ICTV_XLSX_VENV` to its
absolute path. For example, the temporary environment used for the initial manual
exports was `/tmp/ictv-xlsx-venv`; it may be reused while it exists:

```bash
ICTV_XLSX_VENV=/tmp/ictv-xlsx-venv bash schema/mariadb/export/exportTables.sh
```

To convert a TSV manually (this keeps the source TSV):

```bash
bash schema/mariadb/export/exportXlsx.sh input.utf8.txt output.xlsx
```

The converter uses `report.special_case_taxa.template.xlsx`
in this directory as its template, including its SQL tab and conditional formatting.
Keep this template alongside `tsv_to_xlsx.py`; export data replaces its sample rows. Pass `--template PATH` to the
wrapper to select another compatible template. Header names and order must match.
