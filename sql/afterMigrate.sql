/* Set schema and table for version info from Flyway config */
DECLARE @versionSchema NVARCHAR(128) = N'administrative';
DECLARE @versionTable NVARCHAR(128) = N'schema_version';

/* Set schema and table for changelog table */
DECLARE @changelogSchema NVARCHAR(128) = N'administrative';
DECLARE @changelogTable NVARCHAR(128) = N'schema_changelog';

--========================--
-- Do not edit below here --
--========================--

DECLARE @sqlEndVersion NVARCHAR(MAX) = N''; 
DECLARE @parmDefinitionEndVersion NVARCHAR(MAX) = N'';

DECLARE @sqlLogInsert NVARCHAR(MAX) = N''; 

DECLARE @migrationEnd DATETIME = GETDATE();
DECLARE @migrationStart DATETIME = NULL;

DECLARE @endVersionID INT = NULL;
DECLARE @startVersionID INT = NULL;

CREATE TABLE  #changelog (
	   [start_version_id] [int] NOT NULL,
	   [end_version_id] [int] NOT NULL,
	   [migration_start] DATETIME NOT NULL,
	   [migration_end] DATETIME NOT NULL,
	   [schema] [nvarchar](128) NULL,
	   [name] [sysname] NULL,
	   [type_desc] [nvarchar](60) NULL,
	   [change] [nvarchar](50) NULL
	   );

/* Get last version ID of migration */
SELECT @sqlEndVersion = N'
SELECT  @endversionID_out = MAX([installed_rank])
FROM  ' + QUOTENAME(@versionSchema) + '.' + QUOTENAME(@versionTable) + ';'
SELECT @parmDefinitionEndVersion = N'@endVersionID_out INT OUTPUT';
EXEC sp_executesql @sqlEndVersion, @parmDefinitionEndVersion,  @endversionID_out = @endVersionID OUTPUT;

/* Grab start version and start time of the migration */
SELECT @startVersionID = [start_version_id]
	 ,@migrationStart = [migration_start]
FROM ##changelog_start;

/* Store all logged changes into temp table for dynamic SQL construction: */

--Objects modified/created during migration
INSERT INTO #changelog
SELECT @startVersionID
	 ,@endVersionID
	 ,@migrationStart
	 ,@migrationEnd
	 ,SCHEMA_NAME([ao].[schema_id])
	 ,[ao].[name]
	 ,[ao].[type_desc]
	 ,CASE
           WHEN [ao].[create_date] >= @migrationStart
                AND [ao].[create_date] <= @migrationEnd
              THEN 'created'
           ELSE 'modified'
       END
FROM [sys].[all_objects] AS [ao] 
WHERE (([ao].[create_date] >= @migrationStart AND [ao].[create_date] <= @migrationEnd)
    OR ([ao].[modify_date] >= @migrationStart AND [ao].[modify_date] <= @migrationEnd));

--Objects that no longer exist but did before
INSERT INTO #changelog
SELECT @startVersionID
	 ,@endVersionID
	 ,@migrationStart
	 ,@migrationEnd
	 ,[sao].[schema_name]
	 ,[sao].[name]
	 ,[sao].[type_desc]
	 ,'dropped'
FROM [##start_all_objects] AS [sao]
    LEFT JOIN [sys].[all_objects] AS [ao] ON [ao].[object_id] = [sao].[object_id]
WHERE [ao].[object_id] IS NULL;

/* Add all created, modified, and dropped objects to the log */
SELECT @sqlLogInsert = N'
INSERT INTO ' + QUOTENAME(@changelogSchema) + '.' + QUOTENAME(@changelogTable) + '(
					    [start_version_id]
					   ,[end_version_id]
					   ,[migration_start]
					   ,[migration_end]
					   ,[schema]
					   ,[name]
					   ,[type_desc]
					   ,[change])
SELECT [start_version_id] 
	 ,[end_version_id]
	 ,[migration_start] 
	 ,[migration_end] 
	 ,[schema]
	 ,[name]
	 ,[type_desc]
	 ,[change]
FROM #changelog';

EXEC sp_executesql @sqlLogInsert;
