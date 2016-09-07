/* Set schema where Flyway stores its data*/
DECLARE @flywaySchema NVARCHAR(128) = N'dbo';
DECLARE @flywayTable NVARCHAR(128) = N'schema_changelog';

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

DECLARE @sqlLogCreate NVARCHAR(MAX) = N'';

/* Create changelog table if doesn't exist, this way no separate setup required */
SELECT @sqlLogCreate = N'
DECLARE @migrationStart DATETIME = NULL;
DECLARE @startVersionID INT = 0;
' +

/* Create tables to store pre-migration metadata*/
N'DROP TABLE IF EXISTS ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogStartTable) + ';
CREATE TABLE ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogStartTable) + ' (
	    [start_version_id] INT NOT NULL
	   ,[migration_start] DATETIME NOT NULL
	   );

DROP TABLE IF EXISTS ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogObjectTable) + ';
CREATE TABLE ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogObjectTable) + ' (
	    [name] NVARCHAR(128) NOT NULL
	   ,[schema_name] NVARCHAR(128) NOT NULL
	   ,[type_desc] NVARCHAR(128) NOT NULL
	   ,[object_id] INT NOT NULL
	   );
' +

/*Check if log table exists, create if not. Avoids need for a setup script */
N'IF  OBJECT_ID(''' + QUOTENAME(@flywaySchema) + '.' + QUOTENAME(@flywayTable) + ''') IS NULL
    BEGIN
	   CREATE TABLE ' + QUOTENAME(@flywaySchema) + '.' + QUOTENAME(@flywayTable) + '(
			 [first_version_id] [int] NOT NULL,
			 [last_version_id] [int] NOT NULL,
			 [migration_start] DATETIME NOT NULL,
			 [migration_end] DATETIME NOT NULL,
			 [schema] [nvarchar](128) NULL,
			 [name] [sysname] NULL,
			 [type_desc] [nvarchar](60) NULL,
			 [change] [nvarchar](50) NULL
	   )
    END
' +

/* Get the first version of the migration */
N'SELECT  @startversionID = MAX([installed_rank]) + 1
FROM  ' + QUOTENAME(@flywaySchema) + '.' + QUOTENAME(@versionTable) + ';
' +

/* Artificial delay to make sure create tables don't get wrapped into the migration start/end window */
N'WAITFOR DELAY ''00:00:01'';
' +

/* Set migration start time after logging tables created */
N'SET @migrationStart = GETDATE();
' +

/* Capture latest schema version and timestamp before migration starts */
N'INSERT INTO ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogStartTable) + '([start_version_id]
                               ,[migration_start])
SELECT @startVersionID
      ,@migrationStart;
' +

/* Capture list of objects to compare after migration for any drops that occur */
N'INSERT INTO ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogObjectTable) + '([name]
                                 ,[schema_name]
                                 ,[type_desc]
                                 ,[object_id])
SELECT [name]
      ,SCHEMA_NAME(schema_id)
      ,[type_desc]
      ,[OBJECT_ID]
FROM [sys].[all_objects];';

EXEC sp_executesql @sqlLogCreate; 
