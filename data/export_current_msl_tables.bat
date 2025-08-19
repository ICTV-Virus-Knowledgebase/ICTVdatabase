@REM
@REM export tables to tsv needed for proposal_validator's current_msl/ cache
@REM
@REM 20250807 CurtisH disable column truncation, add SP sqlcmdExportWithHeader, re-factor code with SQLCMD_FLAGS var
@REM 20250807 CurtisH switch copy back to ICTVdatabase/data/
@REM 20250307 CurtisH switch copy back to ICTVdatabase/data/
@REM 20250306 CurtisH switch export file suffix to .utf8.dos.txt
@REM 20250227 CurtisH MSL40v1 fix taxobnomy_node_marisdb_etl to also be MSL40
@REM 20250130 CurtisH MSL40v1
@REM 20250113 CurtisH MSL39v4 +taxonomy_node_mariadb_etl, +virus_prop 
@REM 20230614 CurtisH MSL38
@REM
@REM basic method from 
@REM   https://stackoverflow.com/questions/1355876/export-table-to-file-with-column-headers-column-names-using-the-bcp-utility-an
@REM utf-8 (-f o:65001 ) from 
@REM   https://stackoverflow.com/questions/41561658/i-need-dump-table-from-sql-server-to-csv-in-utf-8
@REM
@REM ------------- FLAGS -----------------
@REM -h -1 removes headers (incompatible with -y 0).
@REM -y 0 disables column truncation
@REM -w 65535 prevents wrapping.
@REM -f o:65001 forces UTF-8 output.
@REM -s"^I" is a literal tab as the delimiter.
@REM -W trim trailing spaces from output

@ECHO OFF
@REM Common sqlcmd flags
SET SQLCMD_FLAGS=-d ICTVonline40 -s"	" -f o:65001 -y 0 -w 65535
@ECHO ON

@REM primary data tables
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_toc'" > "taxonomy_toc.utf8.dos.txt"

@REM used by ProposalQC 
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_node_export'" > "taxonomy_node_export.utf8.dos.txt"
@REM used for ETL to MariaDB, until MariaDB is primary
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_node_mariadb_etl'" > "taxonomy_node_mariadb_etl.utf8.dos.txt"

@REM replaced with species_isolates
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'species_isolates'" > "species_isolates.utf8.dos.txt"

@REM CV tables
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_level'" > "taxonomy_level.utf8.dos.txt"
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_molecule'" > "taxonomy_molecule.utf8.dos.txt"
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_host_source'" > "taxonomy_host_source.utf8.dos.txt"
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_genome_coverage'" > "taxonomy_genome_coverage.utf8.dos.txt"
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_change_in'" > "taxonomy_change_in.utf8.dos.txt"
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_change_out'" > "taxonomy_change_out.utf8.dos.txt"



@REM cache tables
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_node_delta'" > "taxonomy_node_delta.utf8.dos.txt"
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'taxonomy_node_merge_split'" > "taxonomy_node_merge_split.utf8.dos.txt"

@REM convenience views
sqlcmd %SQLCMD_FLAGS% -Q "EXEC dbo.sqlcmdExportWithHeader 'dbo', 'vmr_export'" > "vmr_export.utf8.dos.txt"

@REM copy back to laptop
copy /Y  *.txt \\tsclient\ICTV\ICTVdatabase.main\data
copy /Y  *.bat \\tsclient\ICTV\ICTVdatabase.main\data
