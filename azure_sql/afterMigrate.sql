/* Set schema where Flyway stores its data*/
DECLARE @flywaySchema NVARCHAR(128) = N'dbo';
DECLARE @flywayTable NVARCHAR(128) = N'schema_version';

/* Set new changelog table name */
DECLARE @versionTable NVARCHAR(128) = N'schema_version';

--========================--
-- Do not edit below here --
--========================--

/* Tables used temporarily during migration
 put into guest schema for low probability of conflicts */
DECLARE @changelogStartTable NVARCHAR(128) = N'migration_start';
DECLARE @changelogObjectTable NVARCHAR(128) = N'premigration_objects';
DECLARE @changelogTempSchema NVARCHAR(128) = N'guest';

DECLARE @sqlLogInsert NVARCHAR(MAX) = N''; 

/* Add all created, modified, and dropped objects to the log */
SELECT @sqlLogInsert = N'
    DECLARE @endVersionID INT = NULL;
    DECLARE @migrationEnd DATETIME = GETDATE();' +

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
