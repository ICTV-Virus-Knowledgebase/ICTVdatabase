# ICTVdatabase

Data and Schema from the website of the International Committee on the Taxonomy of Viruses (ICTV)
	* https://ICTV.global 

This database contains the current official taxonomy, down to the rank of species, as well as all the historical taxonomy from previous years. The taxa are linked across years (technically, Master Species List (MSL) releases), changes are linked to the supporting official documents that describe the rationales behind the changes. 

## Schema

Create scripts for the current MSSQL schema are found in [./schema/](schema/)

See schema documentation: [./schema/README.md](schema/README.md)

## Data dump

A dump of the core tables to TSV (tab seprated text file) can be found in [./data/](data/)

### Reading the data with Python

[data/read_data.py](data/read_data.py) is a minimal example that parses the ICTV
taxonomy TSV export and loads it into a pandas DataFrame. It also prints the
DataFrame dimensions and first five rows so you can confirm that the data loaded
successfully.

The script requires Python 3 and pandas. A virtual environment is not required,
but using one is recommended so that the dependency is isolated from other
Python projects:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install pandas
python data/read_data.py
```

Run these commands from the repository root. When finished, run `deactivate` to
leave the virtual environment.

## NCBI Linkout

Latest NCBI Linkout feature file ncbi_linkout.ft, and supporting scripts can be found in [./ncbi_linkout](ncbi_linkout/)(


