--Setting up seed tables for Chattanooga MPO PopSynIII
--Binny M Paul, binny.paul@rsginc.com, 072115
-----------------------------------------------------------------------------------

SET NOCOUNT ON;

IF OBJECT_ID('dbo.psam_h11') IS NOT NULL 
	DROP TABLE dbo.psam_h11;
IF OBJECT_ID('dbo.psam_p11') IS NOT NULL 
	DROP TABLE dbo.psam_p11;
IF OBJECT_ID('[dbo].[hhtable]') IS NOT NULL 
	DROP TABLE [dbo].[hhtable];
IF OBJECT_ID('[dbo].[perstable]') IS NOT NULL 
	DROP TABLE [dbo].[perstable];
--IF OBJECT_ID('tempdb..#geographicCWalk') IS NOT NULL 
--	DROP TABLE #geographicCWalk;
IF OBJECT_ID('tempdb..#PUMALIST') IS NOT NULL 
	DROP TABLE #PUMALIST;
IF OBJECT_ID('[dbo].[PUMALIST]') IS NOT NULL 
	DROP TABLE [dbo].[PUMALIST];
GO

/*###################################################################################################*/
--									INPUT FILE LOCATIONS
/*###################################################################################################*/

DECLARE @pumsHH_File1 NVARCHAR(MAX);
DECLARE @pumsPersons_File1 NVARCHAR(MAX);
DECLARE @pumsHH_File2 NVARCHAR(MAX);
DECLARE @pumsPersons_File2 NVARCHAR(MAX);
--DECLARE @geographicCWalk_File NVARCHAR(MAX);
DECLARE @query NVARCHAR(MAX);
DECLARE @pumaList NVARCHAR(MAX);

--Input files
SET @pumsHH_File1 = (SELECT filename FROM csv_filenames WHERE dsc = 'pumsHH_File1');
SET @pumsPersons_File1 = (SELECT filename FROM csv_filenames WHERE dsc = 'pumsPersons_File1');
SET @pumsHH_File2 = (SELECT filename FROM csv_filenames WHERE dsc = 'pumsHH_File2');
SET @pumsPersons_File2 = (SELECT filename FROM csv_filenames WHERE dsc = 'pumsPersons_File2');
--SET @geographicCWalk_File = (SELECT filename FROM csv_filenames WHERE dsc = 'geographicCWalk_File');

/*###################################################################################################*/
--									SETTING UP PUMS DATABASE
/*###################################################################################################*/


CREATE TABLE [dbo].[psam_h11](
	[RT] VARCHAR(5) NULL,
	[SERIALNO] VARCHAR(25) NOT NULL,
	[DIVISION] INT NULL,
	[PUMA] INT NULL,
	[REGION] INT NULL,
	[ST] INT NULL,
	[ADJHSG] INT NULL,
	[ADJINC] [int] NULL,
	[WGTP] INT NULL,
	[NP] INT NULL,
	[TYPE] INT NULL,
	[ACCESS] INT NULL,
	[ACR] INT NULL,
	[AGS] INT NULL,
	[BATH] INT NULL,
	[BDS] INT NULL,
	[BLD] INT NULL,
	[BUS] INT NULL,
	[BROADBND] INT NULL,
	[COMPOTHX] INT NULL,
	[CONP] INT NULL,
	[DIALUP] INT NULL,
	[ELEFP] INT NULL,
	[ELEP] INT NULL,
	[FS] INT NULL,
	[FULFP] INT NULL,
	[FULP] INT NULL,
	[GASFP] INT NULL,
	[GASP] INT NULL,
	[HFL] INT NULL,
	[HISPEED] INT NULL,
	[HOTWAT] INT NULL,
	[INSP] INT NULL,
	[LAPTOP] INT NULL,
	[MHP] INT NULL,
	[MRGI] INT NULL,
	[MRGP] INT NULL,
	[MRGT] INT NULL,
	[MRGX] INT NULL,
	[OTHSVCEX] INT NULL,
	[REFR] INT NULL,
	[RMS] INT NULL,
	[RNTM] INT NULL,
	[RNTP] INT NULL,
	[RWAT] INT NULL,
	[RWATPR] INT NULL,
	[SATELLITE] INT NULL,
	[SINK] INT NULL,
	[SMARTPHONE] INT NULL,
	[SMP] INT NULL,
	[STOV] INT NULL,
	[TABLET] INT NULL,
	[TEL] INT NULL,
	[TEN] INT NULL,
	[TOIL] INT NULL,
	[VACS] INT NULL,
	[VAL] INT NULL,
	[VEH] INT NULL,
	[WATFP] INT NULL,
	[WATP] INT NULL,
	[YBL] INT NULL,
	[CPLT] INT NULL,
	[FES] INT NULL,
	[FINCP] INT NULL,
	[FPARC] INT NULL,
	[GRNTP] INT NULL,
	[GRPIP] INT NULL,
	[HHL] INT NULL,
	[HHT] INT NULL,
	[HHT2] INT NULL,
	[HINCP] INT NULL,
	[HUGCL] INT NULL,
	[HUPAC] INT NULL,
	[HUPAOC] INT NULL,
	[HUPARC] INT NULL,
	[KIT] INT NULL,
	[LNGI] INT NULL,
	[MULTG] INT NULL,
	[MV] INT NULL,
	[NOC] INT NULL,
	[NPF] INT NULL,
	[NPP] INT NULL,
	[NR] INT NULL,
	[NRC] INT NULL,
	[OCPIP] INT NULL,
	[PARTNER] INT NULL,
	[PLM] INT NULL,
	[PLMPRP] INT NULL,
	[PSF] INT NULL,
	[R18] INT NULL,
	[R60] INT NULL,
	[R65] INT NULL,
	[RESMODE] INT NULL,
	[SMOCP] INT NULL,
	[SMX] INT NULL,
	[SRNT] INT NULL,
	[SVAL] INT NULL,
	[TAXP] INT NULL,
	[WIF] INT NULL,
	[WKEXREL] INT NULL,
	[WORKSTAT] INT NULL,
	[FACCESSP] INT NULL,
	[FACRP] INT NULL,
	[FAGSP] INT NULL,
	[FBATHP] INT NULL,
	[FBDSP] INT NULL,
	[FBLDP] INT NULL,
	[FBROADBNDP] INT NULL,
	[FCOMPOTHXP] INT NULL,
	[FBUSP] INT NULL,
	[FCONP] INT NULL,
	[FDIALUPP] INT NULL,
	[FELEP] INT NULL,
	[FFINCP] INT NULL,
	[FFSP] INT NULL,
	[FFULP] INT NULL,
	[FGASP] INT NULL,
	[FGRNTP] INT NULL,
	[FHFLP] INT NULL,
	[FHINCP] INT NULL,
	[FHISPEEDP] INT NULL,
	[FHOTWATP] INT NULL,
	[FINSP] INT NULL,
	[FKITP] INT NULL,
	[FLAPTOPP] INT NULL,
	[FMHP] INT NULL,
	[FMRGIP] INT NULL,
	[FMRGP] INT NULL,
	[FMRGTP] INT NULL,
	[FMRGXP] INT NULL,
	[FMVP] INT NULL,
	[FOTHSVCEXP] INT NULL,
	[FPLMP] INT NULL,
	[FPLMPRP] INT NULL,
	[FREFRP] INT NULL,
	[FRMSP] INT NULL,
	[FRNTMP] INT NULL,
	[FRNTP] INT NULL,
	[FRWATP] INT NULL,
	[FRWATPRP] INT NULL,
	[FSATELLITEP] INT NULL,
	[FSINKP] INT NULL,
	[FSMARTPHONP] INT NULL,
	[FSMOCP] INT NULL,
	[FSMP] INT NULL,
	[FSMXHP] INT NULL,
	[FSMXSP] INT NULL,
	[FSTOVP] INT NULL,
	[FTABLETP] INT NULL,
	[FTAXP] INT NULL,
	[FTELP] INT NULL,
	[FTENP] INT NULL,
	[FTOILP] INT NULL,
	[FVACSP] INT NULL,
	[FVALP] INT NULL,
	[FVEHP] INT NULL,
	[FWATP] INT NULL,
	[FYBLP] INT NULL,
	[WGTP1] INT NULL,
	[WGTP2] INT NULL,
	[WGTP3] INT NULL,
	[WGTP4] INT NULL,
	[WGTP5] INT NULL,
	[WGTP6] INT NULL,
	[WGTP7] INT NULL,
	[WGTP8] INT NULL,
	[WGTP9] INT NULL,
	[WGTP10] INT NULL,
	[WGTP11] INT NULL,
	[WGTP12] INT NULL,
	[WGTP13] INT NULL,
	[WGTP14] INT NULL,
	[WGTP15] INT NULL,
	[WGTP16] INT NULL,
	[WGTP17] INT NULL,
	[WGTP18] INT NULL,
	[WGTP19] INT NULL,
	[WGTP20] INT NULL,
	[WGTP21] INT NULL,
	[WGTP22] INT NULL,
	[WGTP23] INT NULL,
	[WGTP24] INT NULL,
	[WGTP25] INT NULL,
	[WGTP26] INT NULL,
	[WGTP27] INT NULL,
	[WGTP28] INT NULL,
	[WGTP29] INT NULL,
	[WGTP30] INT NULL,
	[WGTP31] INT NULL,
	[WGTP32] INT NULL,
	[WGTP33] INT NULL,
	[WGTP34] INT NULL,
	[WGTP35] INT NULL,
	[WGTP36] INT NULL,
	[WGTP37] INT NULL,
	[WGTP38] INT NULL,
	[WGTP39] INT NULL,
	[WGTP40] INT NULL,
	[WGTP41] INT NULL,
	[WGTP42] INT NULL,
	[WGTP43] INT NULL,
	[WGTP44] INT NULL,
	[WGTP45] INT NULL,
	[WGTP46] INT NULL,
	[WGTP47] INT NULL,
	[WGTP48] INT NULL,
	[WGTP49] INT NULL,
	[WGTP50] INT NULL,
	[WGTP51] INT NULL,
	[WGTP52] INT NULL,
	[WGTP53] INT NULL,
	[WGTP54] INT NULL,
	[WGTP55] INT NULL,
	[WGTP56] INT NULL,
	[WGTP57] INT NULL,
	[WGTP58] INT NULL,
	[WGTP59] INT NULL,
	[WGTP60] INT NULL,
	[WGTP61] INT NULL,
	[WGTP62] INT NULL,
	[WGTP63] INT NULL,
	[WGTP64] INT NULL,
	[WGTP65] INT NULL,
	[WGTP66] INT NULL,
	[WGTP67] INT NULL,
	[WGTP68] INT NULL,
	[WGTP69] INT NULL,
	[WGTP70] INT NULL,
	[WGTP71] INT NULL,
	[WGTP72] INT NULL,
	[WGTP73] INT NULL,
	[WGTP74] INT NULL,
	[WGTP75] INT NULL,
	[WGTP76] INT NULL,
	[WGTP77] INT NULL,
	[WGTP78] INT NULL,
	[WGTP79] INT NULL,
	[WGTP80] INT NULL,

	CONSTRAINT [PK dbo.psam_h11 SERIALNO]
      PRIMARY KEY (SERIALNO)

 );
SET @query = ('BULK INSERT psam_h11
				FROM ' + '''' + @pumsHH_File1 + '''' + '
				WITH (      FIELDTERMINATOR = '','',
							FIRSTROW =2, MAXERRORS = 0, TABLOCK,
							ROWTERMINATOR = '''+CHAR(10)+''')');
EXEC sp_executesql @query;

SET @query = ('BULK INSERT psam_h11
				FROM ' + '''' + @pumsHH_File2 + '''' + '
				WITH (      FIELDTERMINATOR = '','',
							FIRSTROW =2, MAXERRORS = 0, TABLOCK,
							ROWTERMINATOR = '''+CHAR(10)+''')');
EXEC sp_executesql @query;


CREATE TABLE [dbo].[psam_p11](
	[RT] VARCHAR(5) NULL,
	[SERIALNO] VARCHAR(25) NOT NULL,
	[DIVISION] INT NULL,
	[SPORDER] INT NOT NULL,
	[PUMA] INT NULL,
	[REGION] INT NULL,
	[ST] INT NULL,
	[ADJINC] [int] NULL,
	[PWGTP] INT NULL,
	[AGEP] INT NULL,
	[CIT] INT NULL,
	[CITWP] INT NULL,
	[COW] INT NULL,
	[DDRS] INT NULL,
	[DEAR] INT NULL,
	[DEYE] INT NULL,
	[DOUT] INT NULL,
	[DPHY] INT NULL,
	[DRAT] INT NULL,
	[DRATX] INT NULL,
	[DREM] INT NULL,
	[ENG] INT NULL,
	[FER] INT NULL,
	[GCL] INT NULL,
	[GCM] INT NULL,
	[GCR] INT NULL,
	[HINS1] INT NULL,
	[HINS2] INT NULL,
	[HINS3] INT NULL,
	[HINS4] INT NULL,
	[HINS5] INT NULL,
	[HINS6] INT NULL,
	[HINS7] INT NULL,
	[INTP] INT NULL,
	[JWMNP] INT NULL,
	[JWRIP] INT NULL,
	[JWTR] INT NULL,
	[LANX] INT NULL,
	[MAR] INT NULL,
	[MARHD] INT NULL,
	[MARHM] INT NULL,
	[MARHT] INT NULL,
	[MARHW] INT NULL,
	[MARHYP] INT NULL,
	[MIG] INT NULL,
	[MIL] INT NULL,
	[MLPA] INT NULL,
	[MLPB] INT NULL,
	[MLPCD] INT NULL,
	[MLPE] INT NULL,
	[MLPFG] INT NULL,
	[MLPH] INT NULL,
	[MLPI] INT NULL,
	[MLPJ] INT NULL,
	[MLPK] INT NULL,
	[NWAB] INT NULL,
	[NWAV] INT NULL,
	[NWLA] INT NULL,
	[NWLK] INT NULL,
	[NWRE] INT NULL,
	[OIP] INT NULL,
	[PAP] INT NULL,
	[RELP] INT NULL,
	[RETP] INT NULL,
	[SCH] INT NULL,
	[SCHG] INT NULL,
	[SCHL] INT NULL,
	[SEMP] INT NULL,
	[SEX] INT NULL,
	[SSIP] INT NULL,
	[SSP] INT NULL,
	[WAGP] INT NULL,
	[WKHP] INT NULL,
	[WKL] INT NULL,
	[WKW] INT NULL,
	[WKWN] INT NULL,
	[WRK] INT NULL,
	[YOEP] INT NULL,
	[ANC] INT NULL,
	[ANC1P] INT NULL,
	[ANC2P] INT NULL,
	[DECADE] INT NULL,
	[DIS] INT NULL,
	[DRIVESP] INT NULL,
	[ESP] INT NULL,
	[ESR] INT NULL,
	[FOD1P] INT NULL,
	[FOD2P] INT NULL,
	[HICOV] INT NULL,
	[HISP] INT NULL,
	[INDP18] VARCHAR(10) NULL,
	[JWAP] INT NULL,
	[JWDP] INT NULL,
	[LANP] INT NULL,
	[MIGPUMA] INT NULL,
	[MIGSP] INT NULL,
	[MSP] INT NULL,
	[NAICSP18] VARCHAR(10) NULL,
	[NATIVITY] INT NULL,
	[NOP] INT NULL,
	[OC] INT NULL,
	[OCCP18] VARCHAR(10) NULL,
	[PAOC] INT NULL,
	[PERNP] INT NULL,
	[PINCP] INT NULL,
	[POBP] INT NULL,
	[POVPIP] INT NULL,
	[POWPUMA] INT NULL,
	[POWSP] INT NULL,
	[PRIVCOV] INT NULL,
	[PUBCOV] INT NULL,
	[QTRBIR] INT NULL,
	[RAC1P] INT NULL,
	[RAC2P] INT NULL,
	[RAC3P] INT NULL,
	[RACAIAN] INT NULL,
	[RACASN] INT NULL,
	[RACBLK] INT NULL,
	[RACNHPI] INT NULL,
	[RACNUM] INT NULL,
	[RACPI] INT NULL,
	[RACSOR] INT NULL,
	[RACWHT] INT NULL,
	[RC] INT NULL,
	[SCIENGP] INT NULL,
	[SCIENGRLP] INT NULL,
	[SFN] INT NULL,
	[SFR] INT NULL,
	[SOCP18] VARCHAR(10) NULL,
	[VPS] INT NULL,
	[WAOB] INT NULL,
	[FAGEP] INT NULL,
	[FANCP] INT NULL,
	[FCITP] INT NULL,
	[FCITWP] INT NULL,
	[FCOWP] INT NULL,
	[FDDRSP] INT NULL,
	[FDEARP] INT NULL,
	[FDEYEP] INT NULL,
	[FDISP] INT NULL,
	[FDOUTP] INT NULL,
	[FDPHYP] INT NULL,
	[FDRATP] INT NULL,
	[FDRATXP] INT NULL,
	[FDREMP] INT NULL,
	[FENGP] INT NULL,
	[FESRP] INT NULL,
	[FFERP] INT NULL,
	[FFODP] INT NULL,
	[FGCLP] INT NULL,
	[FGCMP] INT NULL,
	[FGCRP] INT NULL,
	[FHICOVP] INT NULL,
	[FHINS1P] INT NULL,
	[FHINS2P] INT NULL,
	[FHINS3C] INT NULL,
	[FHINS3P] INT NULL,
	[FHINS4C] INT NULL,
	[FHINS4P] INT NULL,
	[FHINS5C] INT NULL,
	[FHINS5P] INT NULL,
	[FHINS6P] INT NULL,
	[FHINS7P] INT NULL,
	[FHISP] INT NULL,
	[FINDP] INT NULL,
	[FINTP] INT NULL,
	[FJWDP] INT NULL,
	[FJWMNP] INT NULL,
	[FJWRIP] INT NULL,
	[FJWTRP] INT NULL,
	[FLANP] INT NULL,
	[FLANXP] INT NULL,
	[FMARP] INT NULL,
	[FMARHDP] INT NULL,
	[FMARHMP] INT NULL,
	[FMARHTP] INT NULL,
	[FMARHWP] INT NULL,
	[FMARHYP] INT NULL,
	[FMIGP] INT NULL,
	[FMIGSP] INT NULL,
	[FMILPP] INT NULL,
	[FMILSP] INT NULL,
	[FOCCP] INT NULL,
	[FOIP] INT NULL,
	[FPAP] INT NULL,
	[FPERNP] INT NULL,
	[FPINCP] INT NULL,
	[FPOBP] INT NULL,
	[FPOWSP] INT NULL,
	[FPRIVCOVP] INT NULL,
	[FPUBCOVP] INT NULL,
	[FRACP] INT NULL,
	[FRELP] INT NULL,
	[FRETP] INT NULL,
	[FSCHGP] INT NULL,
	[FSCHLP] INT NULL,
	[FSCHP] INT NULL,
	[FSEMP] INT NULL,
	[FSEXP] INT NULL,
	[FSSIP] INT NULL,
	[FSSP] INT NULL,
	[FWAGP] INT NULL,
	[FWKHP] INT NULL,
	[FWKLP] INT NULL,
	[FWKWNP] INT NULL,
	[FWKWP] INT NULL,
	[FWRKP] INT NULL,
	[FYOEP] INT NULL,
	[PWGTP1] INT NULL,
	[PWGTP2] INT NULL,
	[PWGTP3] INT NULL,
	[PWGTP4] INT NULL,
	[PWGTP5] INT NULL,
	[PWGTP6] INT NULL,
	[PWGTP7] INT NULL,
	[PWGTP8] INT NULL,
	[PWGTP9] INT NULL,
	[PWGTP10] INT NULL,
	[PWGTP11] INT NULL,
	[PWGTP12] INT NULL,
	[PWGTP13] INT NULL,
	[PWGTP14] INT NULL,
	[PWGTP15] INT NULL,
	[PWGTP16] INT NULL,
	[PWGTP17] INT NULL,
	[PWGTP18] INT NULL,
	[PWGTP19] INT NULL,
	[PWGTP20] INT NULL,
	[PWGTP21] INT NULL,
	[PWGTP22] INT NULL,
	[PWGTP23] INT NULL,
	[PWGTP24] INT NULL,
	[PWGTP25] INT NULL,
	[PWGTP26] INT NULL,
	[PWGTP27] INT NULL,
	[PWGTP28] INT NULL,
	[PWGTP29] INT NULL,
	[PWGTP30] INT NULL,
	[PWGTP31] INT NULL,
	[PWGTP32] INT NULL,
	[PWGTP33] INT NULL,
	[PWGTP34] INT NULL,
	[PWGTP35] INT NULL,
	[PWGTP36] INT NULL,
	[PWGTP37] INT NULL,
	[PWGTP38] INT NULL,
	[PWGTP39] INT NULL,
	[PWGTP40] INT NULL,
	[PWGTP41] INT NULL,
	[PWGTP42] INT NULL,
	[PWGTP43] INT NULL,
	[PWGTP44] INT NULL,
	[PWGTP45] INT NULL,
	[PWGTP46] INT NULL,
	[PWGTP47] INT NULL,
	[PWGTP48] INT NULL,
	[PWGTP49] INT NULL,
	[PWGTP50] INT NULL,
	[PWGTP51] INT NULL,
	[PWGTP52] INT NULL,
	[PWGTP53] INT NULL,
	[PWGTP54] INT NULL,
	[PWGTP55] INT NULL,
	[PWGTP56] INT NULL,
	[PWGTP57] INT NULL,
	[PWGTP58] INT NULL,
	[PWGTP59] INT NULL,
	[PWGTP60] INT NULL,
	[PWGTP61] INT NULL,
	[PWGTP62] INT NULL,
	[PWGTP63] INT NULL,
	[PWGTP64] INT NULL,
	[PWGTP65] INT NULL,
	[PWGTP66] INT NULL,
	[PWGTP67] INT NULL,
	[PWGTP68] INT NULL,
	[PWGTP69] INT NULL,
	[PWGTP70] INT NULL,
	[PWGTP71] INT NULL,
	[PWGTP72] INT NULL,
	[PWGTP73] INT NULL,
	[PWGTP74] INT NULL,
	[PWGTP75] INT NULL,
	[PWGTP76] INT NULL,
	[PWGTP77] INT NULL,
	[PWGTP78] INT NULL,
	[PWGTP79] INT NULL,
	[PWGTP80] INT NULL,

	CONSTRAINT [PK dbo.psam_p11 SPORDER, SERIALNO]
      PRIMARY KEY (SPORDER, SERIALNO)
 );
SET @query = ('BULK INSERT psam_p11
				FROM ' + '''' + @pumsPersons_File1 + '''' + '
				WITH (      FIELDTERMINATOR = '','',
							FIRSTROW =2, MAXERRORS = 0, TABLOCK,
							ROWTERMINATOR = '''+CHAR(10)+''')');
EXEC sp_executesql @query;

SET @query = ('BULK INSERT psam_p11
				FROM ' + '''' + @pumsPersons_File2 + '''' + '
				WITH (      FIELDTERMINATOR = '','',
							FIRSTROW =2, MAXERRORS = 0, TABLOCK,
							ROWTERMINATOR = '''+CHAR(10)+''')');
EXEC sp_executesql @query;


ALTER TABLE [dbo].[psam_p11] 
  ADD indp02 VARCHAR(10),
	  naicsp02 VARCHAR(10),
	  occp02 VARCHAR(10),
	  socp00 VARCHAR(10),
	  occp10 VARCHAR(10),
	  socp10 VARCHAR(10),
	  indp07 VARCHAR(10),
	  naicsp07 VARCHAR(10); 

UPDATE [dbo].[psam_p11] 
  SET indp02 = INDP18,
      naicsp02 = INDP18,
	  occp02 = OCCP18,
	  socp00 = SOCP18,
	  occp10 = OCCP18,
	  socp10 = SOCP18,
	  indp07 = INDP18,
	  naicsp07 = NAICSP18;
	  
PRINT 'Loaded acs2019 5 year raw pums datasets...'


--Loading the geographic correspondence to get unique PUMA list
--CREATE TABLE #geographicCWalk( [MAZ] BIGINT 
--	,[TAZ_ID] INT NULL
--	,[STATE] VARCHAR(10) NULL
--	,[STATEFP10] INT NULL
--	,[COUNTY] VARCHAR(15) NULL
--	,[COUNTYFP10] INT NULL
--	,[GEOID10_tract] BIGINT NULL
--	,[TAZ] INT NULL
--	,[GEOID10_block] BIGINT NULL
--	,[BLOCKCE10] INT NULL
--	,[PUMA2000] INT 
--	,[PUMACE2010] INT NULL
--	,[AFFGEOID10] VARCHAR(30) NULL
--	,[GEOID10_PUMA10] INT NULL
--	,[REGION] INT 
--	CONSTRAINT [PK tempdb.geographicCWalk MAZ,PUMA2000, REGION] PRIMARY KEY CLUSTERED (MAZ,PUMA2000, REGION)
--)
--SET @query = ('BULK INSERT #geographicCWalk FROM ' + '''' + @geographicCWalk_File + '''' + ' WITH (FIELDTERMINATOR = ' + 
--				''',''' + ', ROWTERMINATOR = ' + '''\n''' + ', FIRSTROW = 2, MAXERRORS = 0, TABLOCK);');
--EXEC sp_executesql @query;

--/*###################################################################################################*/
----									PROCESSING GENERAL POPULATION
--/*###################################################################################################*/
--Retrieve the unique list of PUMAs covering the region and convert to a comma separated text string
--Update PUMA numbers of seed table


SELECT DISTINCT PUMA/100 AS PUMA INTO #PUMALIST
FROM geographicCWalk
SELECT @pumaList = COALESCE(@pumaList + ',', '') +  CONVERT(varchar(12),PUMA)
FROM #PUMALIST
ORDER BY PUMA
--PRINT @pumaList
--Loading matching PUMA records into a temporary table
--SELECT COUNT(*) FROM dbo.psam_h11;
SET @query = 'DELETE FROM dbo.psam_h11 WHERE PUMA NOT IN (' + @pumaList + ')';
EXEC sp_executesql @query;
--PRINT @query
SET @query = 'DELETE FROM dbo.psam_p11 WHERE PUMA NOT IN (' + @pumaList + ')';
EXEC sp_executesql @query;

--SELECT COUNT(*) FROM dbo.psam_h11;

UPDATE psam_h11
	SET PUMA = PUMA*100+ST;
UPDATE psam_p11
	SET PUMA = PUMA*100+ST;

--Delet records based on updated PUMAs
SELECT @pumaList = COALESCE(@pumaList + ',', '') +  CONVERT(varchar(12),t.PUMA)
FROM (SELECT DISTINCT PUMA FROM geographicCWalk) AS t
ORDER BY t.PUMA

SET @query = 'DELETE FROM dbo.psam_h11 WHERE PUMA NOT IN (' + @pumaList + ')';
EXEC sp_executesql @query;
--PRINT @query
SET @query = 'DELETE FROM dbo.psam_p11 WHERE PUMA NOT IN (' + @pumaList + ')';
EXEC sp_executesql @query;
GO


PRINT 'Starting pums seed data processing'

-- Populate households
SELECT [PUMA]
	,[WGTP]
	,0 AS [GQWGTP] -- group quarters household weight is zero for general population
	,[psam_h11].[SERIALNO]
    ,[DIVISION]
	,[NP]
	,CASE	WHEN [ADJINC]=1080470 THEN CAST((([HINCP]/1.0)*1.001264*1.07910576) AS decimal(9,2))
			WHEN [ADJINC]=1073449 THEN CAST((([HINCP]/1.0)*1.007588*1.06536503) AS decimal(9,2))
			WHEN [ADJINC]=1054606 THEN CAST((([HINCP]/1.0)*1.011189*1.04293629) AS decimal(9,2))
			WHEN [ADJINC]=1031452 THEN CAST((([HINCP]/1.0)*1.013097*1.01811790) AS decimal(9,2))
			WHEN [ADJINC]=1010145 THEN CAST((([HINCP]/1.0)*1.010145*1.00000000) AS decimal(9,2))
			ELSE 999
			END AS [hhincAdj] -- adjusted to 2019 dollars
	,[TEN]
	,[BLD]
	,CASE	WHEN [nwrkrs_esr] IS NULL THEN 0
			ELSE [nwrkrs_esr]
			END AS [nwrkrs_esr]
	,[ADJINC]
	,[HINCP]
	,[VEH]
	,[HHT]
	,[TYPE]
	,[NPF]
	,[HUPAC]
	,0 AS [gqflag]
	,0 AS [gqtype]
	,CASE	WHEN [BLD] IN (2) THEN '1'					-- Single-family
			WHEN [BLD] IN (4,5,6,7,8,9) THEN '2'		-- Multi-family
			WHEN [BLD] IN (1,10) THEN '3'				-- Mobile-home
			WHEN [BLD] IN (3) THEN '4'					-- Duplex
			ELSE '999'
			END AS [htype]
	,CASE	WHEN [HUPAC] IN (4) THEN '1'				-- No children
			WHEN [HUPAC] IN (1,2,3) THEN '2'			-- 1 or more children
			ELSE '999'
			END AS [hhchild]
INTO [hhtable]
FROM
	[psam_h11] -- 2011 ACS PUMS for Chattanooga MPO
--Setting number of workers in HH based on Employment Status Recode [ESR] attribute in PUMS Person File
LEFT OUTER JOIN ( 
	SELECT
		[SERIALNO]
		,COUNT(*) AS [nwrkrs_esr]
	FROM
		[psam_p11] -- 2011 ACS PUMS for Chattanooga MPO
	WHERE 
		[ESR] IN (1,2,4,5)
	GROUP BY 
		[SERIALNO]
	) AS hh_workers
ON
	[psam_h11].[SERIALNO] = hh_workers.[SERIALNO]
WHERE
	[psam_h11].[NP] > 0 -- Deleting vacant units
	AND [psam_h11].[TYPE] = 1 -- Deleting gq units

PRINT 'Census acs2019 5 year input household data inserted into [hhtable]'

-- Populate persons
SELECT tt.[PUMA]
	,[hhtable].[WGTP] -- household weight
	,[hhtable].[GQWGTP] -- gq household weight
	,tt.[SERIALNO]
    ,[SPORDER]
    ,[AGEP]
	,[SEX]
	,[WKHP]
	,[COW]
	,[ESR]
	,[SCHG]
	,[employed]
	,[WKW]
	,[MIL]
	,[SCHL]
	,[indp02]
	,[indp07]
	,[occp02]
	,[occp10]
	,[socp00]
	,[socp10]
	,[gqflag]
	,[gqtype]
	,[soc]
	,CASE	WHEN soc IN (11,13,15,17,19,27,39) THEN '1' --Management, Business, Science, and Arts
			WHEN soc IN (21,23,25,29,31) THEN '2' --White Collar Service Occupations
			WHEN soc IN (33,35,37) THEN '3' --Blue Collar Service Occupations
			WHEN soc IN (41,43) THEN '4' --Sales and Office Support
			WHEN soc IN (45,47,49) THEN '5' --Natural Resources, Construction, and Maintenance
			WHEN soc IN (51,53,55) THEN '6' --Production, Transportation, and Material Moving
			ELSE '999' --Not in labor force
			END AS [occp]
INTO [perstable]
FROM (
SELECT [PUMA]
	,[SERIALNO]
    ,[SPORDER]
    ,[AGEP]
	,[SEX]
	,[WKHP]
	,[COW]
	,[ESR]
	,[SCHG]
	,CASE	WHEN [ESR] IN (1,2,4,5) THEN 1
			ELSE 0
			END AS [employed]
	,[WKW]
	,[MIL]
	,[SCHL]
	,[indp02]
	,[indp07]
	,[occp02]
	,[occp10]
	,[socp00]
	,[socp10]
	,CASE	WHEN [ESR] NOT IN (1,2,4,5) OR [ESR] IS NULL THEN '999'
			WHEN LEFT(LTRIM(RTRIM(socp00)),2) = 'N' OR LEFT(LTRIM(RTRIM(socp00)),2) = 'N.' THEN LEFT(LTRIM(RTRIM(socp10)),2)
			ELSE LEFT(LTRIM(RTRIM(socp00)),2)
			END AS [soc]
FROM 
	[psam_p11] -- 2011 ACS PUMS for rogue valley
) AS tt
INNER JOIN -- deletes vacant units and non-gq
	[hhtable]
ON
	tt.[SERIALNO] = [hhtable].[SERIALNO]

PRINT 'Census acs2019 5 year input person data inserted into [perstable]'

-- Populate GQ households
INSERT INTO [hhtable]
SELECT [PUMA]
	,0 AS [WGTP] -- general population household weight is zero for gq records
	,[PWGTP] AS [GQWGTP] -- person weight as group quarters household weight
	,[psam_h11].[SERIALNO]
    ,[DIVISION]
	,[NP]
	,NULL AS [hhincAdj] -- No income for GQ households
	,[TEN]
	,[BLD]
	,CASE	WHEN [nwrkrs_esr] IS NULL THEN 0
			ELSE [nwrkrs_esr]
			END AS [nwrkrs_esr]
	,[ADJINC]
	,[HINCP]
	,[VEH]
	,[HHT]
	,[TYPE]
	,[NPF]
	,[HUPAC]
	,1 AS [gqflag]
	,CASE	WHEN [SCHG] IN (6,7) THEN 1 --university gq record (placeholder)
			WHEN [MIL] = 1 THEN 2 --military gq record (placeholder)
			ELSE 4 --other civilian gq record
			END AS [gqtype]
	,'999' AS [htype]
	,'999' AS [hhchild]
FROM
	[psam_h11] -- 2011 ACS PUMS for rogue valley
--Setting number of workers in HH based on Employment Status Recode [ESR] attribute in PUMS Person File
LEFT OUTER JOIN ( 
	SELECT
		[SERIALNO]
		,MAX([SCHG]) AS [SCHG] -- should just be a single record due to gq
		,MAX([MIL]) AS [MIL] -- should just be a single record due to gq
		,MAX([PWGTP]) AS [PWGTP] -- should just be a single record due to gq
		,SUM(CASE	WHEN [ESR] IN (1,2,4,5) THEN 1
					ELSE 0
					END) AS [nwrkrs_esr] -- should just be 1/0 due to gq
	FROM
		[psam_p11] -- 2011 ACS PUMS for rogue valley
	GROUP BY -- in theory not necessary due to GQ
		[SERIALNO]
	) AS hh_workers
ON
	[psam_h11].[SERIALNO] = hh_workers.[SERIALNO]
WHERE
	[NP] > 0
	AND [TYPE] = 3 -- Non-institutional group quarters only

PRINT 'Census acs2015 5 year input group quarter household data inserted into [hhtable]'

-- Populate GQ persons
INSERT INTO [perstable]
SELECT tt.[PUMA]
	,[hhtable].[WGTP] -- general population person weight zero for gq record
	,[PWGTP] AS [GQWGTP] -- person weight as household weight for GQ
	,tt.[SERIALNO]
    ,[SPORDER]
    ,[AGEP]
	,[SEX]
	,[WKHP]
	,[COW]
	,[ESR]
	,[SCHG]
	,[employed]
	,[WKW]
	,[MIL]
	,[SCHL]
	,[indp02]
	,[indp07]
	,[occp02]
	,[occp10]
	,[socp00]
	,[socp10]
	,[gqflag]
	,[gqtype]
	,[soc]
	,CASE	WHEN soc IN (11,13,15,17,19,27,39) THEN '1' --Management, Business, Science, and Arts
			WHEN soc IN (21,23,25,29,31) THEN '2' --White Collar Service Occupations
			WHEN soc IN (33,35,37) THEN '3' --Blue Collar Service Occupations
			WHEN soc IN (41,43) THEN '4' --Sales and Office Support
			WHEN soc IN (45,47,49) THEN '5' --Natural Resources, Construction, and Maintenance
			WHEN soc IN (51,53,55) THEN '6' --Production, Transportation, and Material Moving
			ELSE '999' --Not in labor force
			END AS [occp]
FROM (
SELECT [PUMA]
	,[PWGTP]
	,[SERIALNO]
    ,[SPORDER]
    ,[AGEP]
	,[SEX]
	,[WKHP]
	,[COW]
	,[ESR]
	,[SCHG]
	,CASE	WHEN [ESR] IN (1,2,4,5) THEN 1
			ELSE 0
			END AS [employed]
	,[WKW]
	,[MIL]
	,[SCHL]
	,[indp02]
	,[indp07]
	,[occp02]
	,[occp10]
	,[socp00]
	,[socp10]
	,CASE	WHEN [ESR] NOT IN (1,2,4,5) OR [ESR] IS NULL THEN '999'
			WHEN LEFT(LTRIM(RTRIM(socp00)),2) = 'N' OR LEFT(LTRIM(RTRIM(socp00)),2) = 'N.' THEN LEFT(LTRIM(RTRIM(socp10)),2)
			ELSE LEFT(LTRIM(RTRIM(socp00)),2)
			END AS [soc]
FROM 
	[psam_p11] -- 2011 ACS PUMS for rogue valley
) AS tt
INNER JOIN -- deletes vacant units, gq hh's now in there
	[hhtable]
ON
	tt.[SERIALNO] = [hhtable].[SERIALNO]
WHERE
	[NP] > 0
	AND [hhtable].[TYPE] = 3 -- Non-institutional group quarters only

PRINT 'Census acs2015 5 year input group quarter person data inserted into [perstable]'
GO


/*###################################################################################################*/
--									OPTIMIZING DATABASE
/*###################################################################################################*/
--Generating household and person ID for use in PopSynIII
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO
BEGIN TRANSACTION
ALTER TABLE [dbo].[hhtable]
   ADD hhnum INT IDENTITY 
   CONSTRAINT [UQ dbo.hhtable hhnum] UNIQUE
   GO
COMMIT TRANSACTION
SET TRANSACTION ISOLATION LEVEL READ COMMITTED

ALTER TABLE [dbo].[perstable]
   ADD hhnum INT
   GO

--Rebuilding index for optimizing database performance
ALTER INDEX ALL ON [dbo].[hhtable]
REBUILD WITH (FILLFACTOR = 80, SORT_IN_TEMPDB = ON,
              STATISTICS_NORECOMPUTE = ON);
GO

ALTER INDEX ALL ON [dbo].[perstable]
REBUILD WITH (FILLFACTOR = 80, SORT_IN_TEMPDB = ON,
              STATISTICS_NORECOMPUTE = ON);
GO

PRINT 'Finished rebuilding indexes...'

--Linking person to HH using the user-defined ID
UPDATE P
SET hhnum = H.hhnum
FROM [dbo].[hhtable] AS H
JOIN [dbo].[perstable] AS P
    ON P.SERIALNO = H.SERIALNO
OPTION (LOOP JOIN);

PRINT 'Seed table creation complete!'
GO
--SELECT * FROM [dbo].[hhtable]
--SELECT * FROM [dbo].[perstable]