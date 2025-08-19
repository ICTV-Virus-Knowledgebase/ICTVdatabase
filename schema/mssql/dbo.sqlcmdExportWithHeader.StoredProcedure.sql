
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[sqlcmdExportWithHeader]
    @schema  sysname,
    @table   sysname,
    @where   NVARCHAR(MAX) = NULL,   -- e.g. N'WHERE is_active = 1'
    @orderBy NVARCHAR(MAX) = NULL    -- e.g. N'ORDER BY id'
AS
BEGIN
	/*
	 * ExportWithHEader for SQLCMD
	 *
	 * In order to avoid column width truncation at 256 chars, we have to use
	 *     SQLCMD -y 0
	 * HOWEVER, that (mysteriously) also turns off column headers. 
	 * 
	 * So, instead of just querying tables/views directly, we use this SP 
	 * which adds the headers back as a first data line. 
	 *
	 * CHANGE_LOG:
	 * 20250819 CurtisH created, and update export_current_msl_tables.bat
	 *
	 * TESTS:

		-- table 
		exec dbo.ExportWithHeader  'dbo', 'taxonomy_toc'

		-- view
		exec dbo.ExportWithHeader  'dbo', 'vmr_export'

		-- tbale with long notes
		exec dbo.ExportWithHeader  'dbo', 'taxonomy_node_delta'

	 */
    SET NOCOUNT ON;

    DECLARE @qualified NVARCHAR(512) = QUOTENAME(@schema) + N'.' + QUOTENAME(@table);
    DECLARE @header NVARCHAR(MAX);
    DECLARE @data   NVARCHAR(MAX);
    DECLARE @sql    NVARCHAR(MAX);

    IF OBJECT_ID('tempdb..#cols') IS NOT NULL DROP TABLE #cols;
    CREATE TABLE #cols (
        column_id INT NOT NULL,
        colname   sysname NOT NULL,
        typename  sysname NOT NULL
    );

    INSERT INTO #cols (column_id, colname, typename)
    SELECT
        c.column_id,
        c.name,
        t.name
    FROM sys.columns c
    JOIN sys.objects o  ON o.object_id = c.object_id
    JOIN sys.schemas s  ON s.schema_id = o.schema_id
    JOIN sys.types   t  ON t.user_type_id = c.user_type_id
    WHERE o.type IN ('U','V')   -- <- allow TABLEs and VIEWs
      AND s.name = @schema
      AND o.name = @table;

    -- Build header row: SELECT 'col1','col2',...
    SELECT @header =
        STUFF((
            SELECT N', CAST(''' + colname + N''' AS NVARCHAR(MAX))'
            FROM #cols
            ORDER BY column_id
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, N'');

    -- Build data row: SELECT CAST([col] AS NVARCHAR(MAX)), ... with type-specific handling
    SELECT @data =
        STUFF((
            SELECT N', ' +
                   CASE
                       WHEN typename IN ('varbinary','binary','image')
                           THEN N'CONVERT(NVARCHAR(MAX), master.dbo.fn_varbintohexstr(' + QUOTENAME(colname) + N'))'
                       WHEN typename IN ('datetime','smalldatetime','datetime2','date','time','datetimeoffset')
                           THEN N'CONVERT(NVARCHAR(30), ' + QUOTENAME(colname) + N', 126)'  -- ISO 8601
                       WHEN typename = 'uniqueidentifier'
                           THEN N'CONVERT(NVARCHAR(36), ' + QUOTENAME(colname) + N')'
                       ELSE N'CONVERT(NVARCHAR(MAX), ' + QUOTENAME(colname) + N')'
                   END
            FROM #cols
            ORDER BY column_id
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, N'');

    SET @sql = N'
        SELECT ' + @header + N'
        UNION ALL
        SELECT ' + @data + N'
        FROM ' + @qualified + N'
        ' + COALESCE(@where,  N'') + N'
        ' + COALESCE(@orderBy, N'') + N';';

    --PRINT @sql;  -- uncomment to inspect the generated query
    EXEC sp_executesql @sql;
END
GO

