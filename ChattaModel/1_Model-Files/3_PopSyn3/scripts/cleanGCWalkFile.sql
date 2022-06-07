--Clean up and process the Geographic CrossWalk File Chattanooga MPO PopSynIII
--Binny M paul, binny.paul@rsginc.com, 042015
-----------------------------------------------------------------------------------

SET NOCOUNT ON;

IF OBJECT_ID('[dbo].[geographicCWalk]') IS NOT NULL 
	DROP TABLE [dbo].[geographicCWalk];
IF OBJECT_ID('tempdb..#tractIDList') IS NOT NULL 
	DROP TABLE #tractIDList;
IF OBJECT_ID('tempdb..#TAZ_POP') IS NOT NULL 
	DROP TABLE #TAZ_POP;
IF OBJECT_ID('tempdb..#TAZ_PUMA_STATE_POP') IS NOT NULL 
	DROP TABLE #TAZ_PUMA_STATE_POP;
IF OBJECT_ID('tempdb..#TAZ_PUMA_STATE_POP_COMPARE') IS NOT NULL 
	DROP TABLE #TAZ_PUMA_STATE_POP_COMPARE;
IF OBJECT_ID('tempdb..#FINAL_TAZ_PUMA_MAPPING') IS NOT NULL 
	DROP TABLE #FINAL_TAZ_PUMA_MAPPING;	
GO

/*###################################################################################################*/
--									INPUT FILE LOCATIONS
/*###################################################################################################*/

DECLARE @geographicCWalk_File NVARCHAR(MAX);
DECLARE @query NVARCHAR(MAX);
DECLARE @tractList NVARCHAR(MAX);

--Input files
SET @geographicCWalk_File = (SELECT filename FROM csv_filenames WHERE dsc = 'geographicCWalk_File');

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

--Delete microzones belonging to external county
DELETE FROM geographicCWalk WHERE RTRIM(LTRIM(County))='External';

--create unique PUMA IDs (since they repeat for different states)
ALTER TABLE geographicCWalk
	ADD PUMA INT
GO
UPDATE geographicCWalk
	SET PUMA = PUMA2000*100 + STATEFP10
GO

--resolve the issue of one census tract belonging to two PUMAs (allocate to PUMA containing majority of population)
--Create distinct (Tract ID+PUMA) table and add proxy TAZ ID column (some tractID overlap between two PUMAs)
SELECT distinct(t2.GEOID10_tract), sum(t1.POP) as tazpop INTO #TAZ_POP from control_totals_maz t1, geographicCWalk t2 where t1.MZ_ID=t2.MZ_ID group by t2.GEOID10_tract;
SELECT t2.GEOID10_tract, t2.PUMA, t2.STATE, sum(t1.POP) as tazpumapop INTO #TAZ_PUMA_STATE_POP from control_totals_maz t1, geographicCWalk t2 where t1.MZ_ID=t2.MZ_ID group by t2.GEOID10_tract, t2.PUMA, t2.STATE;
select t1.GEOID10_tract, t1.PUMA, t1.STATE, t1.tazpumapop, t2.tazpop INTO #TAZ_PUMA_STATE_POP_COMPARE from #TAZ_PUMA_STATE_POP t1, #TAZ_POP t2 where t1.geoid10_tract=t2.geoid10_tract order by t1.geoid10_tract;

	
--Create the final TAZ to PUMA mapping
SELECT * INTO #FINAL_TAZ_PUMA_MAPPING from #TAZ_PUMA_STATE_POP_COMPARE where cast(tazpumapop as float)/cast(tazpop as float)>=0.5;
GO
--CREATE TABLE with unique tractIDs and generate sequential TAZ numbers
SELECT DISTINCT GEOID10_tract INTO #tractIDList FROM geographicCWalk ORDER BY GEOID10_tract;
ALTER TABLE #tractIDList
	ADD TAZ INT IDENTITY(1,1) ;

--Add proxy MAZ and TAZ column
ALTER TABLE geographicCWalk
	ADD [MAZ] INT IDENTITY(1,1) ,
	[TAZ] INT ;
	
--Add sequential TAZ to geographic file
UPDATE t2
	SET t2.TAZ = t1.TAZ 
	FROM #tractIDList t1 INNER JOIN 
		geographicCWalk t2
	ON t2.GEOID10_tract = t1.GEOID10_tract
	
--Update the TAZ-PUMA mapping in the geographic crosswalk file from the final mapping table
UPDATE t1
	SET t1.PUMA = t2.PUMA 
	FROM geographicCWalk t1 INNER JOIN 
		#FINAL_TAZ_PUMA_MAPPING t2
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

PRINT 'Finished processing Geographic Croaawalk File'	
	
