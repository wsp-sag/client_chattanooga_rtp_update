--Post-processing PopSynIII output to generate a fully expanded synthetic population
--general and gq tables are joined into a unified population file at this stage
--Binny M Paul, binny.paul@rsginc.com
------------------------------------------------------------------------------------
USE Chattanooga;
SET NOCOUNT ON;

--Cleaning up objects created during previous SQL transactions
IF OBJECT_ID('dbo.persons') IS NOT NULL 
	DROP TABLE dbo.persons;
IF OBJECT_ID('dbo.households') IS NOT NULL 
	DROP TABLE dbo.households;
IF OBJECT_ID('tempdb..#Numbers') IS NOT NULL 
	DROP TABLE #Numbers;

--Add the original geography fields to the output tables
ALTER TABLE [dbo].[synpop_hh]
	ADD [MZ_ID] BIGINT,
		[TZ_ID] INT,
		[GEOID10_tract] BIGINT,
		[PUMACE2010] INT,
		[PUMA2000] INT,
		[ST] INT

ALTER TABLE [dbo].[synpop_person]
	ADD [MZ_ID] BIGINT,
		[TZ_ID] INT,
		[GEOID10_tract] BIGINT,
		[PUMACE2010] INT,
		[PUMA2000] INT,
		[ST] INT
		
ALTER TABLE [dbo].[synpop_hh_gq]
	ADD [MZ_ID] BIGINT,
		[TZ_ID] INT,
		[GEOID10_tract] BIGINT,
		[PUMACE2010] INT,
		[PUMA2000] INT,
		[ST] INT
		
ALTER TABLE [dbo].[synpop_person_gq]
	ADD [MZ_ID] BIGINT,
		[TZ_ID] INT,
		[GEOID10_tract] BIGINT,
		[PUMACE2010] INT,
		[PUMA2000] INT,
		[ST] INT
GO

--Populate the original geographic fields from crosswalk table
UPDATE [dbo].[synpop_hh]
	SET MZ_ID = t1.MZ_ID,
		TZ_ID = t1.TZ_ID,
		GEOID10_tract = t1.GEOID10_tract,
		PUMACE2010 = t1.PUMACE2010,
		PUMA2000 = t1.PUMA2000,
		ST = t1.STATEFP10
	FROM (SELECT DISTINCT MAZ, MZ_ID, TZ_ID, GEOID10_tract, PUMA2000, PUMACE2010, STATEFP10 FROM geographicCWalk) AS t1, 
		[dbo].[synpop_hh] t2
	WHERE t1.MAZ = t2.MAZ

UPDATE [dbo].[synpop_hh_gq]
	SET MZ_ID = t1.MZ_ID,
		TZ_ID = t1.TZ_ID,
		GEOID10_tract = t1.GEOID10_tract,
		PUMACE2010 = t1.PUMACE2010,
		PUMA2000 = t1.PUMA2000,
		ST = t1.STATEFP10
	FROM (SELECT DISTINCT MAZ, MZ_ID, TZ_ID, GEOID10_tract, PUMA2000, PUMACE2010, STATEFP10 FROM geographicCWalk) AS t1, 
		[dbo].[synpop_hh_gq] t2
	WHERE t1.MAZ = t2.MAZ	


UPDATE [dbo].[synpop_person]
	SET MZ_ID = t1.MZ_ID,
		TZ_ID = t1.TZ_ID,
		GEOID10_tract = t1.GEOID10_tract,
		PUMACE2010 = t1.PUMACE2010,
		PUMA2000 = t1.PUMA2000,
		ST = t1.STATEFP10
	FROM (SELECT DISTINCT MAZ, MZ_ID, TZ_ID, GEOID10_tract, PUMA2000, PUMACE2010, STATEFP10 FROM geographicCWalk) AS t1, 
		[dbo].[synpop_person] t2
	WHERE t1.MAZ = t2.MAZ
	
UPDATE [dbo].[synpop_person_gq]
	SET MZ_ID = t1.MZ_ID,
		TZ_ID = t1.TZ_ID,
		GEOID10_tract = t1.GEOID10_tract,
		PUMACE2010 = t1.PUMACE2010,
		PUMA2000 = t1.PUMA2000,
		ST = t1.STATEFP10
	FROM (SELECT DISTINCT MAZ, MZ_ID, TZ_ID, GEOID10_tract, PUMA2000, PUMACE2010, STATEFP10 FROM geographicCWalk) AS t1, 
		[dbo].[synpop_person_gq] t2
	WHERE t1.MAZ = t2.MAZ
GO	


------------------------------------------------------------------------------------
--Creating an auxiliary table of numbers for inner join
--Auxiliary table of numbers credit [http://sqlblog.com/blogs/paul_white/default.aspx]
CREATE TABLE #Numbers
(
    n INTEGER NOT NULL,

    CONSTRAINT [PK tempdb.#Numbers n]
        PRIMARY KEY CLUSTERED (n)
);

WITH
    N1 AS (SELECT N1.n FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) AS N1 (n)),
    N2 AS (SELECT L.n FROM N1 AS L CROSS JOIN N1 AS R),
    N3 AS (SELECT L.n FROM N2 AS L CROSS JOIN N2 AS R),
    N4 AS (SELECT L.n FROM N3 AS L CROSS JOIN N3 AS R),
    N AS (SELECT ROW_NUMBER() OVER (ORDER BY @@SPID) AS n FROM N4)
INSERT #Numbers
    (n)
SELECT TOP (1000000)
    n
FROM N
ORDER BY N.n
OPTION (MAXDOP 1);


------------------------------------------------------------------------------------
--joining the general household and the gq household tables
SELECT * INTO [dbo].[households] FROM
	(
	select * from synpop_hh
		union all
	select * from synpop_hh_gq
	) AS tmp
INNER JOIN ( -- expand households based on weight
	SELECT
		[n]
	FROM 
		#Numbers
	) AS numbers
ON
	numbers.[n] BETWEEN 1 AND [tmp].[finalweight];

------------------------------------------------------------------------------------
--joining the general person and the gq person tables
SELECT * INTO [dbo].[persons] FROM
	(
	select * from synpop_person
		union all
	select * from synpop_person_gq
	) AS tmp
INNER JOIN ( -- expand households based on weight
	SELECT
		[n]
	FROM 
		#Numbers
	) AS numbers
ON
	numbers.[n] BETWEEN 1 AND [tmp].[finalweight];

------------------------------------------------------------------------------------
--generating household and person ID for use in ABM
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO
BEGIN TRANSACTION
	ALTER TABLE [dbo].[households]
	   ADD hhid INT IDENTITY 
	   CONSTRAINT [PK dbo.households hhid]
	   PRIMARY KEY CLUSTERED (hhid)
	GO
   
	ALTER TABLE [dbo].[persons]
	   ADD PERID INT IDENTITY
	   CONSTRAINT [UQ dbo.persons perid]
	   PRIMARY KEY CLUSTERED (perid)
	GO
COMMIT TRANSACTION
SET TRANSACTION ISOLATION LEVEL READ COMMITTED

ALTER TABLE [dbo].[persons]
   ADD hhid INT FOREIGN KEY REFERENCES households(hhid)
GO

-- create unique household index
CREATE UNIQUE INDEX idx_hh
  ON [dbo].[households](gqflag,tempId DESC,n DESC)
  INCLUDE(hhid);

--set household id in person file
UPDATE P
SET hhid = H.hhid
FROM [dbo].[households] AS H
JOIN [dbo].[persons] AS P
    ON P.tempId = H.tempId
    AND P.n = H.n
	AND P.gqflag = H.gqflag
OPTION (LOOP JOIN);

-- cleanup
DROP INDEX idx_hh ON [dbo].[households];
