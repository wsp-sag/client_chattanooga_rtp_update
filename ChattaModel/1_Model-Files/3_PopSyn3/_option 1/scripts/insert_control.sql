--Setting up control tables for Chattanooga MPO PopSynIII
--Binny M paul, binny.paul@rsginc.com, 042015
-----------------------------------------------------------------------------------

SET NOCOUNT ON;

IF OBJECT_ID('[dbo].[control_totals_maz]') IS NOT NULL 
	DROP TABLE [dbo].[control_totals_maz];
IF OBJECT_ID('[dbo].[control_totals_taz]') IS NOT NULL 
	DROP TABLE [dbo].[control_totals_taz];
IF OBJECT_ID('[dbo].[control_totals_meta]') IS NOT NULL 
	DROP TABLE [dbo].[control_totals_meta];
IF OBJECT_ID('[dbo].[geographicCWalk]') IS NOT NULL 
	DROP TABLE [dbo].[geographicCWalk];
IF OBJECT_ID('[dbo].[tractIDList]') IS NOT NULL 
	DROP TABLE tractIDList;
IF OBJECT_ID('[dbo].[TAZ_POP]') IS NOT NULL 
	DROP TABLE TAZ_POP;
IF OBJECT_ID('[dbo].[TAZ_PUMA_STATE_POP]') IS NOT NULL 
	DROP TABLE TAZ_PUMA_STATE_POP;
IF OBJECT_ID('[dbo].[TAZ_PUMA_STATE_POP_COMPARE]') IS NOT NULL 
	DROP TABLE TAZ_PUMA_STATE_POP_COMPARE;
IF OBJECT_ID('[dbo].[FINAL_TAZ_PUMA_MAPPING]') IS NOT NULL 
	DROP TABLE FINAL_TAZ_PUMA_MAPPING;	
GO

/*###################################################################################################*/
--									INPUT FILE LOCATIONS
/*###################################################################################################*/

DECLARE @infile_maz NVARCHAR(MAX);
DECLARE @infile_taz NVARCHAR(MAX);
DECLARE @infile_meta NVARCHAR(MAX);
DECLARE @geographicCWalk_File NVARCHAR(MAX);
DECLARE @query NVARCHAR(MAX);
DECLARE @tractList NVARCHAR(MAX);

--Input files
SET @infile_maz = (SELECT filename FROM csv_filenames WHERE dsc = 'mazData_File');
SET @infile_taz = (SELECT filename FROM csv_filenames WHERE dsc = 'tazData_File');
SET @infile_meta = (SELECT filename FROM csv_filenames WHERE dsc = 'metaData_File');
SET @geographicCWalk_File = (SELECT filename FROM csv_filenames WHERE dsc = 'geographicCWalk_File');

--MAZ Controls
CREATE TABLE [dbo].[control_totals_maz] ( [MZ_ID] BIGINT
	,[HH] INT
	,[POPGQ] INT
	,[POPNGQ] INT NULL
	,[POP] INT
	
	--CONSTRAINT [PK dbo.control_totals_maz MAZ] PRIMARY KEY CLUSTERED (MAZ)

)
SET @query = ('BULK INSERT control_totals_maz FROM ' + '''' + @infile_maz + '''' + ' WITH (FIELDTERMINATOR = ' + 
				''',''' + ', ROWTERMINATOR = ' + '''\n''' + ', FIRSTROW = 2, MAXERRORS = 0, TABLOCK);');
EXEC sp_executesql @query;

PRINT 'BULK INSERT control_totals_maz FROM ' + '''' + @infile_maz + '''' + ' WITH (FIELDTERMINATOR = ' + 
				''',''' + ', ROWTERMINATOR = ' + '''\n''' + ', FIRSTROW = 2, MAXERRORS = 0, TABLOCK);'
--WAITFOR DELAY '01:00';

--TAZ Controls
CREATE TABLE [dbo].[control_totals_taz] ( [GEOID10_tract] BIGINT
	,[HHSIZE1] INT
	,[HHSIZE2] INT
	,[HHSIZE3] INT
	,[HHSIZE4PLUS] INT
	,[INCOME_25K] INT
	,[INCOME_50K] INT
	,[INCOME_75K] INT
	,[INCOME_100K] INT
	,[INCOME_100KPLUS] INT
	,[WORKERS_0] INT
	,[WORKERS_1] INT
	,[WORKERS_2] INT
	,[WORKERS_3PLUS] INT
	,[HHWCHILD] INT
	,[HHWOCHILD] INT
	,[NGQ0TO17] INT
	,[NGQ18TO34] INT
	,[NGQ35TO64] INT
	,[NGQ65PLUS] INT
	,[FemaleNGQ] INT
	,[MaleNGQ] INT
	
		
	--CONSTRAINT [PK dbo.control_totals_taz TAZ] PRIMARY KEY CLUSTERED (TAZ)

)
SET @query = ('BULK INSERT control_totals_taz FROM ' + '''' + @infile_taz + '''' + ' WITH (FIELDTERMINATOR = ' + 
				''',''' + ', ROWTERMINATOR = ' + '''\n''' + ', FIRSTROW = 2, MAXERRORS = 0, TABLOCK);');
EXEC sp_executesql @query;

--META Controls
CREATE TABLE [dbo].[control_totals_meta] ( [REGION] INT
	,[POPGQ] INT
	,[POPNGQ] INT
	
	CONSTRAINT [PK dbo.control_totals_meta REGION] PRIMARY KEY CLUSTERED (REGION)

)
SET @query = ('BULK INSERT control_totals_meta FROM ' + '''' + @infile_meta + '''' + ' WITH (FIELDTERMINATOR = ' + 
				''',''' + ', ROWTERMINATOR = ' + '''\n''' + ', FIRSTROW = 2, MAXERRORS = 0, TABLOCK);');
EXEC sp_executesql @query;

--Loading the geographic correspondence
CREATE TABLE geographicCWalk( [MZ_ID] BIGINT
	,[TZ_ID] INT NULL
	,[STATE] VARCHAR(10) NULL
	,[STATEFP10] INT NULL
	,[COUNTY] VARCHAR(15) NULL
	,[COUNTYFP10] INT NULL
	,[GEOID10_tract] BIGINT NULL
	,[TRACTCE10] INT NULL
	,[GEOID10_block] BIGINT NULL
	,[BLOCKCE10] INT NULL
	,[PUMA2000] INT 
	,[PUMACE2010] INT NULL
	,[AFFGEOID10] VARCHAR(30) NULL
	,[GEOID10_PUMA10] INT NULL
	,[REGION] INT 
	--CONSTRAINT [PK tempdb.geographicCWalk MAZ, TAZ, PUMA, REGION] PRIMARY KEY CLUSTERED (MAZ, TAZ, PUMA, REGION)
)
SET @query = ('BULK INSERT geographicCWalk FROM ' + '''' + @geographicCWalk_File + '''' + ' WITH (FIELDTERMINATOR = ' + 
				''',''' + ', ROWTERMINATOR = ' + '''\n''' + ', FIRSTROW = 2, MAXERRORS = 0, TABLOCK);');
EXEC sp_executesql @query;

--UPDATE GEOGRAPHIC CROSSWALK FILE 

--Delete records with missing TAZ[tract ID]
DELETE FROM geographicCWalk WHERE GEOID10_tract IS NULL;



--create unique PUMA IDs (since they repeat for different states)
ALTER TABLE geographicCWalk
	ADD PUMA INT
GO
UPDATE geographicCWalk
	SET PUMA = PUMA2000*100 + STATEFP10
GO

--resolve the issue of one census tract belonging to two PUMAs (allocate to PUMA containing majority of population)
--Create distinct (Tract ID+PUMA) table and add proxy TAZ ID column (some tractID overlap between two PUMAs)
SELECT distinct(t2.GEOID10_tract), sum(t1.POP) as tazpop INTO TAZ_POP from control_totals_maz t1, geographicCWalk t2 where t1.MZ_ID=t2.MZ_ID group by t2.GEOID10_tract;
SELECT t2.GEOID10_tract, t2.PUMA, t2.STATE, sum(t1.POP) as tazpumapop INTO TAZ_PUMA_STATE_POP from control_totals_maz t1, geographicCWalk t2 where t1.MZ_ID=t2.MZ_ID group by t2.GEOID10_tract, t2.PUMA, t2.STATE;
select t1.GEOID10_tract, t1.PUMA, t1.STATE, t1.tazpumapop, t2.tazpop INTO TAZ_PUMA_STATE_POP_COMPARE from TAZ_PUMA_STATE_POP t1, TAZ_POP t2 where t1.geoid10_tract=t2.geoid10_tract order by t1.geoid10_tract;

--ALTER TABLE TAZ_PUMA_STATE_POP_COMPARE
--	ADD PopRatio FLOAT;
--
--UPDATE geographicCWalk
--	SET PopRatio = cast(tazpumapop as float)/cast(tazpop as float)
--GO
	
--Create the final TAZ to PUMA mapping
SELECT * INTO FINAL_TAZ_PUMA_MAPPING from TAZ_PUMA_STATE_POP_COMPARE where cast(tazpumapop as float)/cast(tazpop as float)>=0.5 AND tazpop>0;
GO
--CREATE TABLE with unique tractIDs and generate sequential TAZ numbers
SELECT DISTINCT GEOID10_tract INTO tractIDList FROM geographicCWalk ORDER BY GEOID10_tract;
ALTER TABLE tractIDList
	ADD TAZ INT IDENTITY(1,1) ;

--Add proxy MAZ and TAZ column
ALTER TABLE geographicCWalk
	ADD [MAZ] INT IDENTITY(1,1) ,
	[TAZ] INT ;
	
--Add sequential TAZ to geographic file
UPDATE t2
	SET t2.TAZ = t1.TAZ 
	FROM tractIDList t1 INNER JOIN 
		geographicCWalk t2
	ON t2.GEOID10_tract = t1.GEOID10_tract
	
--Update the TAZ-PUMA mapping in the geographic crosswalk file from the final mapping table
UPDATE t1
	SET t1.PUMA = t2.PUMA 
	FROM geographicCWalk t1 INNER JOIN 
		FINAL_TAZ_PUMA_MAPPING t2
	ON t1.GEOID10_tract = t2.GEOID10_tract
GO
--Add primary key to geographic walk table
ALTER TABLE geographicCWalk
	ALTER COLUMN MAZ INT NOT NULL;
ALTER TABLE geographicCWalk
	ALTER COLUMN TAZ INT NOT NULL;
ALTER TABLE geographicCWalk
	ALTER COLUMN PUMA INT NOT NULL;
ALTER TABLE geographicCWalk
	ALTER COLUMN REGION INT NOT NULL;
GO	
	
ALTER TABLE geographicCWalk
	ADD CONSTRAINT PK PRIMARY KEY CLUSTERED (MAZ, TAZ, PUMA, REGION);

PRINT 'added primary key geographic file'	
	
--Appending other geographic ids to maz control table 
ALTER TABLE [dbo].[control_totals_maz]
	ADD [MAZ] INT,
		[TAZ] INT,
		[PUMA] INT,
		[REGION] INT
GO
PRINT 'Appending other geographic ids to maz control table'
UPDATE [dbo].[control_totals_maz]
	SET MAZ = t1.MAZ,
		TAZ = t1.TAZ,
		PUMA = t1.PUMA,
		REGION = t1.REGION
	FROM (SELECT DISTINCT MAZ, MZ_ID, TAZ, PUMA, REGION FROM geographicCWalk) AS t1, 
		control_totals_maz t2
	WHERE t1.MZ_ID = t2.MZ_ID

ALTER TABLE control_totals_maz
	ALTER COLUMN MAZ INT NOT NULL
GO
	
ALTER TABLE control_totals_maz
	ADD CONSTRAINT PK1 PRIMARY KEY CLUSTERED (MAZ);
	
--Retrieve the unique list of Tract IDs [treated as TAZs] covering the region and convert to a comma separated text string
DECLARE @query NVARCHAR(MAX);
DECLARE @tractList NVARCHAR(MAX);
SELECT DISTINCT GEOID10_tract INTO #TRACTLIST
FROM geographicCWalk;

SELECT @tractList = COALESCE(@tractList + ',', '') +  CONVERT(varchar(12),GEOID10_tract)
FROM #TRACTLIST
ORDER BY GEOID10_tract;

--Loading matching TAZ records into a temporary table
SET @query = 'DELETE FROM dbo.control_totals_taz WHERE GEOID10_tract NOT IN (' + @tractList + ')';
EXEC sp_executesql @query;
PRINT @query
PRINT 'deleted missing TAZ records from TAZ file'
GO

	
--Appending other geographic ids to taz control table 
ALTER TABLE [dbo].[control_totals_taz]
	ADD [TAZ] INT,
		[PUMA] INT,
		[REGION] INT
GO

UPDATE [dbo].[control_totals_taz]
	SET TAZ = t1.TAZ,
		PUMA = t1.PUMA,
		REGION = t1.REGION
	FROM (SELECT DISTINCT TAZ, GEOID10_tract, PUMA, REGION FROM geographicCWalk) AS t1, 
		[dbo].[control_totals_taz] t2
	WHERE t1.GEOID10_tract = t2.GEOID10_tract
	
GO	

--Add index to TAZ control file
	
ALTER TABLE control_totals_taz
	ALTER COLUMN TAZ INT NOT NULL
GO
	
ALTER TABLE control_totals_taz
	ADD CONSTRAINT PK2 PRIMARY KEY CLUSTERED (TAZ);
	
PRINT 'FINISHED Appending other geographic ids to maz control table'	

--Fix issues in MAZ Controls FILE
--make negative value zero
UPDATE [dbo].[control_totals_maz]
	SET POPNGQ = 0 where POPNGQ<0
GO

--Delete Georgia records
--DELETE FROM dbo.control_totals_maz WHERE PUMA=10013;
--DELETE FROM dbo.control_totals_taz WHERE PUMA=10013;
GO
	


--select * from control_totals_maz
--select * from control_totals_taz
--select * from control_totals_meta