/*
Panko
Copyright (c) 2020 John McCall

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Source: https://github.com/LowlyDBA/Panko
*/

/* Set schema where Flyway stores its data*/
DECLARE @flywaySchema sysname = N'dbo';
DECLARE @flywayTable sysname = N'schema_version';

/* Set new changelog table name */
DECLARE @versionTable sysname = N'schema_version';

--========================--
-- Do not edit below here --
--========================--

/* Tables used temporarily during migration
 put into guest schema for low probability of conflicts */
DECLARE @changelogStartTable sysname = N'migration_start';
DECLARE @changelogObjectTable sysname = N'premigration_objects';
DECLARE @changelogTempSchema sysname = N'guest';

DECLARE @sqlLogInsert NVARCHAR(MAX) = N''; 

/* Add all created, modified, and dropped objects to the log */
SELECT @sqlLogInsert = N'
    DECLARE @endVersionID INT = NULL;
    DECLARE @migrationEnd DATETIME2 = GETDATE();' +

    /* Get last version ID of migration */
    N'SELECT  @endversionID = MAX([installed_rank])
    FROM  ' + QUOTENAME(@flywaySchema) + '.' + QUOTENAME(@flywayTable) + ';' +

    --Objects modified/created during migration
    N'INSERT INTO ' + QUOTENAME(@flywaySchema) + '.' + QUOTENAME(@changelogTable) + '(
						   [first_version_id]
						  ,[last_version_id]
						  ,[migration_start]
						  ,[migration_end]
						  ,[schema]
						  ,[name]
						  ,[type_desc]
						  ,[change])
    SELECT [cst].[start_version_id]
		,@endVersionID
		,[cst].[migration_start]
		,@migrationEnd
		,SCHEMA_NAME([ao].[schema_id])
		,[ao].[name]
		,[ao].[type_desc]
		,CASE
			WHEN [ao].[create_date] >= [cst].[migration_start]
				AND [ao].[create_date] <= @migrationEnd
			   THEN ''created''
			ELSE ''modified''
		 END
    FROM [sys].[all_objects] AS [ao]
	    CROSS JOIN ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogStartTable) + ' AS [cst]
    WHERE (([ao].[create_date] >= [cst].[migration_start] AND [ao].[create_date] <= @migrationEnd)
	   OR ([ao].[modify_date] >= [cst].[migration_start] AND [ao].[modify_date] <= @migrationEnd));

    --Objects that no longer exist but did before
    INSERT INTO ' + QUOTENAME(@flywaySchema) + '.' + QUOTENAME(@changelogTable) + '(
						   [first_version_id]
						  ,[last_version_id]
						  ,[migration_start]
						  ,[migration_end]
						  ,[schema]
						  ,[name]
						  ,[type_desc]
						  ,[change])
    SELECT [cst].[start_version_id]
		,@endVersionID
		,[cst].[migration_start]
		,@migrationEnd
		,[sao].[schema_name]
		,[sao].[name]
		,[sao].[type_desc]
		,''dropped''
    FROM [dbo].[start_all_objects_temp] AS [sao]
	   CROSS JOIN ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogObjectTable) + ' AS [cst]
	   LEFT JOIN [sys].[all_objects] AS [ao] ON [ao].[object_id] = [sao].[object_id]
    WHERE [ao].[object_id] IS NULL;' +
    
    --Cleanup working tables
    N'DROP TABLE IF EXISTS ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogStartTable) + ';
    DROP TABLE IF EXISTS ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogObjectTable) + ';'

EXEC sp_executesql @sqlLogInsert;
