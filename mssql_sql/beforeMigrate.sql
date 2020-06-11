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

/* Set Flyway's configured table and desired name of new changelog table */
DECLARE @versionTable sysname = N'schema_version';
DECLARE @changelogTable sysname = N'schema_changelog';

--========================--
-- Do not edit below here --
--========================--

DECLARE @sqlNextVersion NVARCHAR(MAX) = N''; 
DECLARE @parmDefinitionNextVersion NVARCHAR(MAX) = N'';

DECLARE @sqlLogCreate NVARCHAR(MAX) = N'';

DECLARE @migrationStart DATETIME = GETDATE();
DECLARE @startVersionID INT = 0;

/* Create temp tables to store pre-migration metadata*/
CREATE TABLE ##changelog_start (
	    [start_version_id] INT NOT NULL
	   ,[migration_start] DATETIME NOT NULL
	   );

CREATE TABLE ##start_all_objects (
	    [name] NVARCHAR(128) NOT NULL
	   ,[schema_name] NVARCHAR(128) NOT NULL
	   ,[type_desc] NVARCHAR(128) NOT NULL
	   ,[object_id] INT NOT NULL
	   );

/* Create changelog table if doesn't exist, this way no separate setup required */
SELECT @sqlLogCreate = N'
IF  OBJECT_ID(''' + QUOTENAME(@flywaySchema) + '.' + QUOTENAME(@changelogTable) + ''') IS NULL
    BEGIN
	   CREATE TABLE ' + QUOTENAME(@flywaySchema) + '.' + QUOTENAME(@changelogTable) + '(
			 [start_version_id] [int] NOT NULL,
			 [end_version_id] [int] NOT NULL,
			 [migration_start] DATETIME NOT NULL,
			 [migration_end] DATETIME NOT NULL,
			 [schema] [nvarchar](128) NULL,
			 [name] [sysname] NULL,
			 [type_desc] [nvarchar](60) NULL,
			 [change] [nvarchar](50) NULL
	   )
    END';
EXEC sp_executesql @sqlLogCreate; 

/* Get first version ID from upcoming migration */
SELECT @sqlNextVersion = N'
SELECT  @startversionID_out = MAX([installed_rank]) + 1
FROM  ' + QUOTENAME(@flywaySchema) + '.' + QUOTENAME(@versionTable) + ';'
SELECT @parmDefinitionNextVersion = N'@startVersionID_out INT OUTPUT';
EXEC sp_executesql @sqlNextVersion, @parmDefinitionNextVersion,  @startversionID_out = @startVersionID OUTPUT;

/* Capture latest schema version and timestamp before migration starts */
INSERT INTO [##changelog_start]([start_version_id]
                               ,[migration_start])
SELECT @startVersionID
      ,@migrationStart;

/* Capture list of objects to compare after migration for any drops that occur */
INSERT INTO [##start_all_objects]([name]
                                 ,[schema_name]
                                 ,[type_desc]
                                 ,[object_id])
SELECT [name]
      ,SCHEMA_NAME(schema_id)
      ,[type_desc]
      ,[OBJECT_ID]
FROM [sys].[all_objects];


