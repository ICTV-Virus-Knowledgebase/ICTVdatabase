
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE  PROCEDURE [dbo].[QC_run_modules]
	@module_filter VARCHAR(200) = '%' 
AS
/*
--
-- RUN ALL QC MODULES (SPs named QC_module_%)
--
-- run all
exec [QC_run_modules]

-- run specific
exec [QC_run_modules] 'taxonomy_node'

*/

DECLARE @sp_name AS varchar(200)
SET @sp_name = '%'
DECLARE @sql as NVARCHAR(200)

DECLARE qc_module_cursor SCROLL CURSOR FOR
SELECT 
    SPECIFIC_NAME as ProcedureName
FROM 
    INFORMATION_SCHEMA.ROUTINES
WHERE 
    ROUTINE_TYPE = 'PROCEDURE'
    AND SPECIFIC_SCHEMA = SCHEMA_NAME()
	AND NOT (
		SPECIFIC_NAME like 'dt_%'
		or 
		SPECIFIC_NAME like 'sp_%diagram%'
	)
	AND SPECIFIC_NAME like 'QC_module_%'+@module_filter+'%'
ORDER BY 
    ProcedureName

OPEN qc_module_cursor

-- Perform the first fetch.
FETCH NEXT FROM qc_module_cursor INTO @sp_name

-- Check @@FETCH_STATUS to see if there are any more rows to fetch.
WHILE @@FETCH_STATUS = 0
BEGIN
	--
	-- DO GRANT TO [PUBLIC]
	--
  SET @sql = 'EXEC [dbo].['+@sp_name+']'
  PRINT 'SQL: ' + @sql
  EXEC sp_executesql @statement=@sql

   -- This is executed as long as the previous fetch succeeds.
   FETCH NEXT FROM qc_module_cursor
   INTO @sp_name
END

CLOSE qc_module_cursor
DEALLOCATE qc_module_cursor
GO

