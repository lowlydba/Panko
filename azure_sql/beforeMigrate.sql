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
DECLARE @flywayTable sysname = N'schema_changelog';

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

DECLARE @sqlLogCreate NVARCHAR(MAX) = N'';

/* Create changelog table if doesn't exist, this way no separate setup required */
SELECT @sqlLogCreate = N'
    DECLARE @migrationStart DATETIME2 = NULL;
    DECLARE @startVersionID INT = 0;
    ' +

    /* Create tables to store pre-migration metadata*/
    N'DROP TABLE IF EXISTS ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogStartTable) + ';
    CREATE TABLE ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogStartTable) + ' (
		   [start_version_id] INT NOT NULL
		  ,[migration_start] DATETIME2 NOT NULL
		  );

    DROP TABLE IF EXISTS ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogObjectTable) + ';
    CREATE TABLE ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogObjectTable) + ' (
		   [name] [sysname] NOT NULL
		  ,[schema_name] [sysname] NOT NULL
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
				[migration_start] DATETIME2 NOT NULL,
				[migration_end] DATETIME2 NOT NULL,
				[schema] [sysname] NULL,
				[name] [sysname] NULL,
				[type_desc] [nvarchar](128) NULL,
				[change] [nvarchar](50) NULL
		  )
	   END
    ' +

    /* Get the first version of the migration */
    N'SELECT  @startversionID = MAX([installed_rank]) + 1
    FROM  ' + QUOTENAME(@flywaySchema) + '.' + QUOTENAME(@versionTable) + ';
    ' +

    /* Artificial delay to make sure working tables don't get wrapped into the migration window */
    N'WAITFOR DELAY ''00:00:01'';
    ' +

    /* Set migration start time after logging tables created */
    N'SET @migrationStart = GETDATE();
    ' +

    /* Capture latest schema version and timestamp before migration starts */
    N'INSERT INTO ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogStartTable) + 
              '([start_version_id]
							,[migration_start])
    SELECT @startVersionID
		,@migrationStart;
    ' +

    /* Capture list of objects to compare after migration for any drops that occur */
    N'INSERT INTO ' + QUOTENAME(@changelogTempSchema) + '.' + QUOTENAME(@changelogObjectTable) + 
                '([name]
							  ,[schema_name]
							  ,[type_desc]
							  ,[object_id])
    SELECT [name]
		,SCHEMA_NAME([schema_id])
		,[type_desc]
		,[OBJECT_ID]
    FROM [sys].[all_objects];';

EXEC sp_executesql @sqlLogCreate; 
