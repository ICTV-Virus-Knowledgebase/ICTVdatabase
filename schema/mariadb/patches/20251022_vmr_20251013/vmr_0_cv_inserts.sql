-- Source workbook: /Users/curtish/Documents/ICTV/ICTVvmrUpdate/VMRs/VMR_MSL40.v1.20250307.editor_DBS_22_July.rch_dbs_rch.xlsx
-- Generated: 2025-10-21 19:02:28 UTC
-- Script version: unknown
Errors encountered; SQL generation may be incorrect.

-- Column 'Genome coverage' value 'Not Compliant' from 'Column Values' row(s) 6
INSERT INTO taxonomy_genome_coverage (
    genome_coverage, `name`, priority
) VALUES (
    'NC','Not Compliant', 150
);

-- Column 'Host source' value 'fungi (S)' from 'Column Values' row(s) 9
INSERT INTO taxonomy_host_source (
    host_source
) VALUES (
    'fungi (S)'
);
