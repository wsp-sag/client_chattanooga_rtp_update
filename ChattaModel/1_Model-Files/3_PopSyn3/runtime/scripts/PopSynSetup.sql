-- Chattanooga MPO PopSynIII - SQLite Setup Script
-- Converted from SQL Server insert_control.sql and insert_seed.sql
-- Sets up control tables, loads PUMS data, and creates household/person tables

.mode csv
.separator ","

-- ====== PHASE 1: DROP EXISTING TABLES ======
DROP TABLE IF EXISTS psam_h11;
DROP TABLE IF EXISTS psam_p11;
DROP TABLE IF EXISTS hhtable;
DROP TABLE IF EXISTS perstable;
DROP TABLE IF EXISTS control_totals_maz;
DROP TABLE IF EXISTS control_totals_taz;
DROP TABLE IF EXISTS control_totals_meta;
DROP TABLE IF EXISTS geographicCWalk;
DROP TABLE IF EXISTS TAZ_POP;
DROP TABLE IF EXISTS TAZ_PUMA_STATE_POP;
DROP TABLE IF EXISTS TAZ_PUMA_STATE_POP_COMPARE;
DROP TABLE IF EXISTS FINAL_TAZ_PUMA_MAPPING;
DROP TABLE IF EXISTS tractIDList;
DROP TABLE IF EXISTS temp_tract_list;
DROP TABLE IF EXISTS temp_puma_list;

-- ====== PHASE 2: CREATE CONTROL TABLES ======

-- MAZ Controls
CREATE TABLE control_totals_maz (
    MZ_ID BIGINT,
    HH INT,
    POPGQ INT,
    POPNGQ INT,
    POP INT,
    MAZ INT,
    TAZ INT,
    PUMA INT,
    REGION INT
);

-- TAZ Controls
CREATE TABLE control_totals_taz (
    GEOID10_tract BIGINT PRIMARY KEY,
    HHSIZE1 INT,
    HHSIZE2 INT,
    HHSIZE3 INT,
    HHSIZE4PLUS INT,
    INCOME_25K INT,
    INCOME_50K INT,
    INCOME_75K INT,
    INCOME_100K INT,
    INCOME_100KPLUS INT,
    WORKERS_0 INT,
    WORKERS_1 INT,
    WORKERS_2 INT,
    WORKERS_3PLUS INT,
    HHWCHILD INT,
    HHWOCHILD INT,
    NGQ0TO17 INT,
    NGQ18TO34 INT,
    NGQ35TO64 INT,
    NGQ65PLUS INT,
    FemaleNGQ INT,
    MaleNGQ INT,
    TAZ INT,
    PUMA INT,
    REGION INT
);

-- META Controls
CREATE TABLE control_totals_meta (
    REGION INT PRIMARY KEY,
    POPGQ INT,
    POPNGQ INT
);

-- Geographic Crosswalk
CREATE TABLE geographicCWalk (
    MZ_ID BIGINT,
    TZ_ID INT,
    STATE VARCHAR(10),
    STATEFP10 INT,
    COUNTY VARCHAR(15),
    COUNTYFP10 INT,
    GEOID10_tract BIGINT,
    TRACTCE10 INT,
    GEOID10_block BIGINT,
    BLOCKCE10 INT,
    PUMA2000 INT,
    PUMACE2010 INT,
    AFFGEOID10 VARCHAR(30),
    GEOID10_PUMA10 INT,
    REGION INT,
    PUMA INT,
    MAZ INT,
    TAZ INT
);

-- Temporary tables for PUMA/TAZ mapping
CREATE TABLE TAZ_POP (
    GEOID10_tract BIGINT,
    tazpop INT
);

CREATE TABLE TAZ_PUMA_STATE_POP (
    GEOID10_tract BIGINT,
    PUMA INT,
    STATE VARCHAR(10),
    tazpumapop INT
);

CREATE TABLE TAZ_PUMA_STATE_POP_COMPARE (
    GEOID10_tract BIGINT,
    PUMA INT,
    STATE VARCHAR(10),
    tazpumapop INT,
    tazpop INT
);

CREATE TABLE FINAL_TAZ_PUMA_MAPPING (
    GEOID10_tract BIGINT,
    PUMA INT,
    STATE VARCHAR(10),
    tazpumapop INT,
    tazpop INT
);

DROP TABLE IF EXISTS tractIDList;
CREATE TABLE tractIDList (
    TAZ INTEGER PRIMARY KEY AUTOINCREMENT,
    GEOID10_tract BIGINT UNIQUE
);

-- PUMS Household table
CREATE TABLE psam_h11(
    RT VARCHAR(5),
    SERIALNO VARCHAR(25) PRIMARY KEY,
    DIVISION INT,
    PUMA INT,
    REGION INT,
    ST INT,
    ADJHSG INT,
    ADJINC INT,
    WGTP INT,
    NP INT,
    TYPE INT,
    ACCESS INT,
    ACR INT,
    AGS INT,
    BATH INT,
    BDSP INT,
    BLD INT,
    BUS INT,
    BROADBND INT,
    COMPOTHX INT,
    CONP INT,
    DIALUP INT,
    ELEFP INT,
    ELEP INT,
    FS INT,
    FULFP INT,
    FULP INT,
    GASFP INT,
    GASP INT,
    HFL INT,
    HISPEED INT,
    HOTWAT INT,
    INSP INT,
    LAPTOP INT,
    MHP INT,
    MRGI INT,
    MRGP INT,
    MRGT INT,
    MRGX INT,
    OTHSVCEX INT,
    REFR INT,
    RMS INT,
    RNTM INT,
    RNTP INT,
    RWAT INT,
    RWATPR INT,
    SATELLITE INT,
    SINK INT,
    SMARTPHONE INT,
    SMP INT,
    STOV INT,
    TABLET INT,
    TEL INT,
    TEN INT,
    TOIL INT,
    VACS INT,
    VAL INT,
    VEH INT,
    WATFP INT,
    WATP INT,
    YBL INT,
    CPLT INT,
    FES INT,
    FINCP INT,
    FPARC INT,
    GRNTP INT,
    GRPIP INT,
    HHL INT,
    HHT INT,
    HHT2 INT,
    HINCP INT,
    HUGCL INT,
    HUPAC INT,
    HUPAOC INT,
    HUPARC INT,
    KIT INT,
    LNGI INT,
    MULTG INT,
    MV INT,
    NOC INT,
    NPF INT,
    NPP INT,
    NR INT,
    NRC INT,
    OCPIP INT,
    PARTNER INT,
    PLM INT,
    PLMPRP INT,
    PSF INT,
    R18 INT,
    R60 INT,
    R65 INT,
    RESMODE INT,
    SMOCP INT,
    SMX INT,
    SRNT INT,
    SVAL INT,
    TAXP INT,
    WIF INT,
    WKEXREL INT,
    WORKSTAT INT,
    FACCESSP INT,
    FACRP INT,
    FAGSP INT,
    FBATHP INT,
    FBDSP INT,
    FBLDP INT,
    FBROADBNDP INT,
    FCOMPOTHXP INT,
    FBUSP INT,
    FCONP INT,
    FDIALUPP INT,
    FELEP INT,
    FFINCP INT,
    FFSP INT,
    FFULP INT,
    FGASP INT,
    FGRNTP INT,
    FHFLP INT,
    FHINCP INT,
    FHISPEEDP INT,
    FHOTWATP INT,
    FINSP INT,
    FKITP INT,
    FLAPTOPP INT,
    FMHP INT,
    FMRGIP INT,
    FMRGP INT,
    FMRGTP INT,
    FMRGXP INT,
    FMVP INT,
    FOTHSVCEXP INT,
    FPLMP INT,
    FPLMPRP INT,
    FREFRP INT,
    FRMSP INT,
    FRNTMP INT,
    FRNTP INT,
    FRWATP INT,
    FRWATPRP INT,
    FSATELLITEP INT,
    FSINKP INT,
    FSMARTPHONP INT,
    FSMOCP INT,
    FSMP INT,
    FSMXHP INT,
    FSMXSP INT,
    FSTOVP INT,
    FTABLETP INT,
    FTAXP INT,
    FTELP INT,
    FTENP INT,
    FTOILP INT,
    FVACSP INT,
    FVALP INT,
    FVEHP INT,
    FWATP INT,
    FYBLP INT,
    WGTP1 INT,
    WGTP2 INT,
    WGTP3 INT,
    WGTP4 INT,
    WGTP5 INT,
    WGTP6 INT,
    WGTP7 INT,
    WGTP8 INT,
    WGTP9 INT,
    WGTP10 INT,
    WGTP11 INT,
    WGTP12 INT,
    WGTP13 INT,
    WGTP14 INT,
    WGTP15 INT,
    WGTP16 INT,
    WGTP17 INT,
    WGTP18 INT,
    WGTP19 INT,
    WGTP20 INT,
    WGTP21 INT,
    WGTP22 INT,
    WGTP23 INT,
    WGTP24 INT,
    WGTP25 INT,
    WGTP26 INT,
    WGTP27 INT,
    WGTP28 INT,
    WGTP29 INT,
    WGTP30 INT,
    WGTP31 INT,
    WGTP32 INT,
    WGTP33 INT,
    WGTP34 INT,
    WGTP35 INT,
    WGTP36 INT,
    WGTP37 INT,
    WGTP38 INT,
    WGTP39 INT,
    WGTP40 INT,
    WGTP41 INT,
    WGTP42 INT,
    WGTP43 INT,
    WGTP44 INT,
    WGTP45 INT,
    WGTP46 INT,
    WGTP47 INT,
    WGTP48 INT,
    WGTP49 INT,
    WGTP50 INT,
    WGTP51 INT,
    WGTP52 INT,
    WGTP53 INT,
    WGTP54 INT,
    WGTP55 INT,
    WGTP56 INT,
    WGTP57 INT,
    WGTP58 INT,
    WGTP59 INT,
    WGTP60 INT,
    WGTP61 INT,
    WGTP62 INT,
    WGTP63 INT,
    WGTP64 INT,
    WGTP65 INT,
    WGTP66 INT,
    WGTP67 INT,
    WGTP68 INT,
    WGTP69 INT,
    WGTP70 INT,
    WGTP71 INT,
    WGTP72 INT,
    WGTP73 INT,
    WGTP74 INT,
    WGTP75 INT,
    WGTP76 INT,
    WGTP77 INT,
    WGTP78 INT,
    WGTP79 INT,
    WGTP80 INT
);

-- PUMS Person table
CREATE TABLE psam_p11(
    RT VARCHAR(5),
    SERIALNO VARCHAR(25),
    DIVISION INT,
    SPORDER INT,
    PUMA INT,
    REGION INT,
    ST INT,
    ADJINC INT,
    PWGTP INT,
    AGEP INT,
    CIT INT,
    CITWP INT,
    COW INT,
    DDRS INT,
    DEAR INT,
    DEYE INT,
    DOUT INT,
    DPHY INT,
    DRAT INT,
    DRATX INT,
    DREM INT,
    ENG INT,
    FER INT,
    GCL INT,
    GCM INT,
    GCR INT,
    HINS1 INT,
    HINS2 INT,
    HINS3 INT,
    HINS4 INT,
    HINS5 INT,
    HINS6 INT,
    HINS7 INT,
    INTP INT,
    JWMNP INT,
    JWRIP INT,
    JWTRNS INT,
    LANX INT,
    MAR INT,
    MARHD INT,
    MARHM INT,
    MARHT INT,
    MARHW INT,
    MARHYP INT,
    MIG INT,
    MIL INT,
    MLPA INT,
    MLPB INT,
    MLPCD INT,
    MLPE INT,
    MLPFG INT,
    MLPH INT,
    MLPI INT,
    MLPJ INT,
    MLPK INT,
    NWAB INT,
    NWAV INT,
    NWLA INT,
    NWLK INT,
    NWRE INT,
    OIP INT,
    PAP INT,
    RELP INT,
    RETP INT,
    SCH INT,
    SCHG INT,
    SCHL INT,
    SEMP INT,
    SEX INT,
    SSIP INT,
    SSP INT,
    WAGP INT,
    WKHP INT,
    WKL INT,
    WKW INT,
    WKWN INT,
    WRK INT,
    YOEP INT,
    ANC INT,
    ANC1P INT,
    ANC2P INT,
    DECADE INT,
    DIS INT,
    DRIVESP INT,
    ESP INT,
    ESR INT,
    FOD1P INT,
    FOD2P INT,
    HICOV INT,
    HISP INT,
    INDP VARCHAR(10),
    JWAP INT,
    JWDP INT,
    LANP INT,
    MIGPUMA INT,
    MIGSP INT,
    MSP INT,
    NAICSP VARCHAR(10),
    NATIVITY INT,
    NOP INT,
    OC INT,
    OCCP VARCHAR(10),
    PAOC INT,
    PERNP INT,
    PINCP INT,
    POBP INT,
    POVPIP INT,
    POWPUMA INT,
    POWSP INT,
    PRIVCOV INT,
    PUBCOV INT,
    QTRBIR INT,
    RAC1P INT,
    RAC2P INT,
    RAC3P INT,
    RACAIAN INT,
    RACASN INT,
    RACBLK INT,
    RACNHPI INT,
    RACNUM INT,
    RACPI INT,
    RACSOR INT,
    RACWHT INT,
    RC INT,
    SCIENGP INT,
    SCIENGRLP INT,
    SFN INT,
    SFR INT,
    SOCP VARCHAR(10),
    VPS INT,
    WAOB INT,
    FAGEP INT,
    FANCP INT,
    FCITP INT,
    FCITWP INT,
    FCOWP INT,
    FDDRSP INT,
    FDEARP INT,
    FDEYEP INT,
    FDISP INT,
    FDOUTP INT,
    FDPHYP INT,
    FDRATP INT,
    FDRATXP INT,
    FDREMP INT,
    FENGP INT,
    FESRP INT,
    FFERP INT,
    FFODP INT,
    FGCLP INT,
    FGCMP INT,
    FGCRP INT,
    FHICOVP INT,
    FHINS1P INT,
    FHINS2P INT,
    FHINS3C INT,
    FHINS3P INT,
    FHINS4C INT,
    FHINS4P INT,
    FHINS5C INT,
    FHINS5P INT,
    FHINS6P INT,
    FHINS7P INT,
    FHISP INT,
    FINDP INT,
    FINTP INT,
    FJWDP INT,
    FJWMNP INT,
    FJWRIP INT,
    FJWTRP INT,
    FLANP INT,
    FLANXP INT,
    FMARP INT,
    FMARHDP INT,
    FMARHMP INT,
    FMARHTP INT,
    FMARHWP INT,
    FMARHYP INT,
    FMIGP INT,
    FMIGSP INT,
    FMILPP INT,
    FMILSP INT,
    FOCCP INT,
    FOIP INT,
    FPAP INT,
    FPERNP INT,
    FPINCP INT,
    FPOBP INT,
    FPOWSP INT,
    FPRIVCOVP INT,
    FPUBCOVP INT,
    FRACP INT,
    FRELP INT,
    FRETP INT,
    FSCHGP INT,
    FSCHLP INT,
    FSCHP INT,
    FSEMP INT,
    FSEXP INT,
    FSSIP INT,
    FSSP INT,
    FWAGP INT,
    FWKHP INT,
    FWKLP INT,
    FWKWNP INT,
    FWKWP INT,
    FWRKP INT,
    FYOEP INT,
    PWGTP1 INT,
    PWGTP2 INT,
    PWGTP3 INT,
    PWGTP4 INT,
    PWGTP5 INT,
    PWGTP6 INT,
    PWGTP7 INT,
    PWGTP8 INT,
    PWGTP9 INT,
    PWGTP10 INT,
    PWGTP11 INT,
    PWGTP12 INT,
    PWGTP13 INT,
    PWGTP14 INT,
    PWGTP15 INT,
    PWGTP16 INT,
    PWGTP17 INT,
    PWGTP18 INT,
    PWGTP19 INT,
    PWGTP20 INT,
    PWGTP21 INT,
    PWGTP22 INT,
    PWGTP23 INT,
    PWGTP24 INT,
    PWGTP25 INT,
    PWGTP26 INT,
    PWGTP27 INT,
    PWGTP28 INT,
    PWGTP29 INT,
    PWGTP30 INT,
    PWGTP31 INT,
    PWGTP32 INT,
    PWGTP33 INT,
    PWGTP34 INT,
    PWGTP35 INT,
    PWGTP36 INT,
    PWGTP37 INT,
    PWGTP38 INT,
    PWGTP39 INT,
    PWGTP40 INT,
    PWGTP41 INT,
    PWGTP42 INT,
    PWGTP43 INT,
    PWGTP44 INT,
    PWGTP45 INT,
    PWGTP46 INT,
    PWGTP47 INT,
    PWGTP48 INT,
    PWGTP49 INT,
    PWGTP50 INT,
    PWGTP51 INT,
    PWGTP52 INT,
    PWGTP53 INT,
    PWGTP54 INT,
    PWGTP55 INT,
    PWGTP56 INT,
    PWGTP57 INT,
    PWGTP58 INT,
    PWGTP59 INT,
    PWGTP60 INT,
    PWGTP61 INT,
    PWGTP62 INT,
    PWGTP63 INT,
    PWGTP64 INT,
    PWGTP65 INT,
    PWGTP66 INT,
    PWGTP67 INT,
    PWGTP68 INT,
    PWGTP69 INT,
    PWGTP70 INT,
    PWGTP71 INT,
    PWGTP72 INT,
    PWGTP73 INT,
    PWGTP74 INT,
    PWGTP75 INT,
    PWGTP76 INT,
    PWGTP77 INT,
    PWGTP78 INT,
    PWGTP79 INT,
    PWGTP80 INT,
    indp02 VARCHAR(10),
    naicsp02 VARCHAR(10),
    occp02 VARCHAR(10),
    socp00 VARCHAR(10),
    occp10 VARCHAR(10),
    socp10 VARCHAR(10),
    indp07 VARCHAR(10),
    naicsp07 VARCHAR(10),
    PRIMARY KEY (SPORDER, SERIALNO)
);

-- ====== PHASE 3: LOAD CSV DATA ======
-- Use staging tables to handle CSV column name differences

-- mazData: TotHH2019->HH, TotGQPop20->POPGQ, TotHHPop20->POPNGQ, TotPop2019->POP
DROP TABLE IF EXISTS _stage_maz;
.import --csv data/mazData.csv _stage_maz
INSERT INTO control_totals_maz (MZ_ID, HH, POPGQ, POPNGQ, POP)
SELECT MZ_ID, TotHH2019, TotGQPop20, TotHHPop20, TotPop2019 FROM _stage_maz;
DROP TABLE IF EXISTS _stage_maz;

-- tractData: GEOID10->GEOID10_tract; HH_* -> HHSIZE/INCOME/WORKERS columns
DROP TABLE IF EXISTS _stage_taz;
.import --csv data/tractData.csv _stage_taz
INSERT INTO control_totals_taz (GEOID10_tract, HHSIZE1, HHSIZE2, HHSIZE3, HHSIZE4PLUS, INCOME_25K, INCOME_50K, INCOME_75K, INCOME_100K, INCOME_100KPLUS, WORKERS_0, WORKERS_1, WORKERS_2, WORKERS_3PLUS, HHWCHILD, HHWOCHILD, NGQ0TO17, NGQ18TO34, NGQ35TO64, NGQ65PLUS, FemaleNGQ, MaleNGQ)
SELECT GEOID10, HH_1, HH_2, HH_3, HH_4PLUS, HH_INCOM_LT25K, HH_INCOM_25K_50K, HH_INCOM_50K_75K, HH_INCOM_75K_100K, HH_INCOM_GT100K, HH_NO_WORK, HH_1_WORK, HH_2_WORK, HH_3PLUS_WORK, HH_CHILD_NEW, HH_NO_CHILD_NEW, POP_AGE_0TO17, POP_AGE_18TO34, POP_AGE_35TO64, POP_AGE_65PLUS, FEMALE, MALE FROM _stage_taz;
DROP TABLE IF EXISTS _stage_taz;

-- metaData: Region->REGION, pop_gq->POPGQ, pop_ngq->POPNGQ
DROP TABLE IF EXISTS _stage_meta;
.import --csv data/metaData.csv _stage_meta
INSERT INTO control_totals_meta (REGION, POPGQ, POPNGQ)
SELECT Region, pop_gq, pop_ngq FROM _stage_meta;
DROP TABLE IF EXISTS _stage_meta;

-- geographicCWalk: TAZ_ID->TZ_ID; GEOID10_block may be scientific notation -> cast via REAL
DROP TABLE IF EXISTS _stage_cwalk;
.import --csv data/MZ_geo_crosswalk.csv _stage_cwalk
INSERT INTO geographicCWalk (MZ_ID, TZ_ID, STATE, STATEFP10, COUNTY, COUNTYFP10, GEOID10_tract, TRACTCE10, GEOID10_block, BLOCKCE10, PUMA2000, PUMACE2010, AFFGEOID10, GEOID10_PUMA10, REGION)
SELECT NULLIF(MZ_ID, ''), NULLIF(TAZ_ID, ''), NULLIF(STATE, ''),
       NULLIF(STATEFP10, ''), NULLIF(COUNTY, ''), NULLIF(COUNTYFP10, ''),
       CAST(NULLIF(GEOID10_tract, '') AS INTEGER),
       NULLIF(TRACTCE10, ''),
       CAST(CAST(NULLIF(GEOID10_block, '') AS REAL) AS INTEGER),
       NULLIF(BLOCKCE10, ''), NULLIF(PUMA2000, ''), NULLIF(PUMACE2010, ''),
       NULLIF(AFFGEOID10, ''), NULLIF(GEOID10_PUMA10, ''), NULLIF(Region, '')
FROM _stage_cwalk;
DROP TABLE IF EXISTS _stage_cwalk;

-- PUMS schemas change between ACS releases. Import into header-defined staging
-- tables, then map the fields used by hhtable/perstable by name.
DROP TABLE IF EXISTS _stage_h47;
.import --csv data/psam_h47.csv _stage_h47
INSERT INTO psam_h11
    (RT, SERIALNO, DIVISION, PUMA, REGION, ST, ADJHSG, ADJINC, WGTP, NP,
         TYPE, ACCESS, ACR, AGS, BATH, BDSP, BLD, TEN, HHT, HINCP, HUPAC, NPF, VEH)
SELECT RT, SERIALNO, DIVISION, PUMA, REGION, STATE, ADJHSG, ADJINC, WGTP, NP,
             TYPEHUGQ, ACCESSINET, NULLIF(ACR, ''), NULLIF(AGS, ''),
             NULLIF(BATH, ''), NULLIF(BDSP, ''), NULLIF(BLD, ''), NULLIF(TEN, ''),
             NULLIF(HHT, ''), NULLIF(HINCP, ''), NULLIF(HUPAC, ''), NULLIF(NPF, ''),
             NULLIF(VEH, '')
FROM _stage_h47;
DROP TABLE _stage_h47;

DROP TABLE IF EXISTS _stage_h13;
.import --csv data/psam_h13.csv _stage_h13
INSERT INTO psam_h11
    (RT, SERIALNO, DIVISION, PUMA, REGION, ST, ADJHSG, ADJINC, WGTP, NP,
    TYPE, ACCESS, ACR, AGS, BATH, BDSP, BLD, TEN, HHT, HINCP, HUPAC, NPF, VEH)
SELECT RT, SERIALNO, DIVISION, PUMA, REGION, STATE, ADJHSG, ADJINC, WGTP, NP,
    TYPEHUGQ, ACCESSINET, NULLIF(ACR, ''), NULLIF(AGS, ''),
    NULLIF(BATH, ''), NULLIF(BDSP, ''), NULLIF(BLD, ''), NULLIF(TEN, ''),
    NULLIF(HHT, ''), NULLIF(HINCP, ''), NULLIF(HUPAC, ''), NULLIF(NPF, ''),
    NULLIF(VEH, '')
FROM _stage_h13;
DROP TABLE _stage_h13;

DROP TABLE IF EXISTS _stage_p47;
.import --csv data/psam_p47.csv _stage_p47
INSERT INTO psam_p11
    (RT, SERIALNO, DIVISION, SPORDER, PUMA, REGION, ST, ADJINC, PWGTP,
         AGEP, COW, MIL, SCHG, SCHL, SEX, WKHP, WKW, WKWN, WRK, ESR,
    INDP, NAICSP, OCCP, SOCP)
SELECT RT, SERIALNO, DIVISION, SPORDER, PUMA, REGION, STATE, ADJINC, PWGTP,
             AGEP, NULLIF(COW, ''), NULLIF(MIL, ''), NULLIF(SCHG, ''),
             NULLIF(SCHL, ''), SEX, NULLIF(WKHP, ''),
      CASE WHEN WKWN BETWEEN 50 AND 52 THEN 1
          WHEN WKWN BETWEEN 48 AND 49 THEN 2
          WHEN WKWN BETWEEN 40 AND 47 THEN 3
          WHEN WKWN BETWEEN 27 AND 39 THEN 4
          WHEN WKWN BETWEEN 14 AND 26 THEN 5
          WHEN WKWN BETWEEN 1 AND 13 THEN 6 END,
    WKWN, NULLIF(WRK, ''), NULLIF(ESR, ''), INDP, NAICSP, OCCP, SOCP
FROM _stage_p47;
DROP TABLE _stage_p47;

DROP TABLE IF EXISTS _stage_p13;
.import --csv data/psam_p13.csv _stage_p13
INSERT INTO psam_p11
    (RT, SERIALNO, DIVISION, SPORDER, PUMA, REGION, ST, ADJINC, PWGTP,
         AGEP, COW, MIL, SCHG, SCHL, SEX, WKHP, WKW, WKWN, WRK, ESR,
    INDP, NAICSP, OCCP, SOCP)
SELECT RT, SERIALNO, DIVISION, SPORDER, PUMA, REGION, STATE, ADJINC, PWGTP,
             AGEP, NULLIF(COW, ''), NULLIF(MIL, ''), NULLIF(SCHG, ''),
             NULLIF(SCHL, ''), SEX, NULLIF(WKHP, ''),
      CASE WHEN WKWN BETWEEN 50 AND 52 THEN 1
          WHEN WKWN BETWEEN 48 AND 49 THEN 2
          WHEN WKWN BETWEEN 40 AND 47 THEN 3
          WHEN WKWN BETWEEN 27 AND 39 THEN 4
          WHEN WKWN BETWEEN 14 AND 26 THEN 5
          WHEN WKWN BETWEEN 1 AND 13 THEN 6 END,
    WKWN, NULLIF(WRK, ''), NULLIF(ESR, ''), INDP, NAICSP, OCCP, SOCP
FROM _stage_p13;
DROP TABLE _stage_p13;

-- Legacy 2019 files already follow the fixed positional schema.
-- .import --csv --skip 1 data/old_seed_data/ss19htn.csv psam_h11
-- .import --csv --skip 1 data/old_seed_data/ss19ptn.csv psam_p11
-- .import --csv --skip 1 data/old_seed_data/ss19hga.csv psam_h11
-- .import --csv --skip 1 data/old_seed_data/ss19pga.csv psam_p11

-- original data 
-- .import --csv --skip 1 data/ss19htn.csv psam_h11
-- .import --csv --skip 1 data/ss19ptn.csv psam_p11
-- .import --csv --skip 1 data/ss19hga.csv psam_h11
-- .import --csv --skip 1 data/ss19pga.csv psam_p11

-- ====== PHASE 4: GEOGRAPHIC PROCESSING ======

-- Delete records with missing TAZ[tract ID]
DELETE FROM geographicCWalk WHERE GEOID10_tract IS NULL;

-- Create unique PUMA IDs (since they repeat for different states)
UPDATE geographicCWalk
    SET PUMA = PUMA2000*100 + STATEFP10;

-- Create distinct (Tract ID+PUMA) table and add proxy TAZ ID column
INSERT INTO TAZ_POP (GEOID10_tract, tazpop)
SELECT DISTINCT t2.GEOID10_tract, sum(t1.POP)
FROM control_totals_maz t1
JOIN geographicCWalk t2 ON t1.MZ_ID=t2.MZ_ID
GROUP BY t2.GEOID10_tract;

INSERT INTO TAZ_PUMA_STATE_POP (GEOID10_tract, PUMA, STATE, tazpumapop)
SELECT t2.GEOID10_tract, t2.PUMA, t2.STATE, sum(t1.POP)
FROM control_totals_maz t1
JOIN geographicCWalk t2 ON t1.MZ_ID=t2.MZ_ID
GROUP BY t2.GEOID10_tract, t2.PUMA, t2.STATE;

INSERT INTO TAZ_PUMA_STATE_POP_COMPARE (GEOID10_tract, PUMA, STATE, tazpumapop, tazpop)
SELECT t1.GEOID10_tract, t1.PUMA, t1.STATE, t1.tazpumapop, t2.tazpop
FROM TAZ_PUMA_STATE_POP t1
JOIN TAZ_POP t2 ON t1.geoid10_tract=t2.geoid10_tract
ORDER BY t1.geoid10_tract;

-- Create the final TAZ to PUMA mapping
INSERT INTO FINAL_TAZ_PUMA_MAPPING
SELECT * FROM TAZ_PUMA_STATE_POP_COMPARE
WHERE CAST(tazpumapop AS REAL)/CAST(tazpop AS REAL)>=0.5 AND tazpop>0;

-- Populate tractIDList with distinct GEOID10_tract values; TAZ will auto-increment
INSERT INTO tractIDList (GEOID10_tract)
SELECT DISTINCT GEOID10_tract FROM geographicCWalk ORDER BY GEOID10_tract;

-- SQL Server adds MAZ as IDENTITY after the import, retaining the import order.
-- Assign sequential MAZ values from SQLite's insertion rowid for the same result.
WITH geographic_rows AS (
    SELECT rowid, ROW_NUMBER() OVER (ORDER BY rowid) AS MAZ
    FROM geographicCWalk
)
UPDATE geographicCWalk
SET MAZ = (
    SELECT geographic_rows.MAZ
    FROM geographic_rows
    WHERE geographic_rows.rowid = geographicCWalk.rowid
);

-- Fill TAZ values by joining to tractIDList.
UPDATE geographicCWalk
SET TAZ = (SELECT TAZ FROM tractIDList t WHERE t.GEOID10_tract = geographicCWalk.GEOID10_tract LIMIT 1);

-- Update the TAZ-PUMA mapping in the geographic crosswalk file from the final mapping table
UPDATE geographicCWalk
SET PUMA = (SELECT PUMA FROM FINAL_TAZ_PUMA_MAPPING ftpm
            WHERE ftpm.GEOID10_tract = geographicCWalk.GEOID10_tract LIMIT 1)
WHERE GEOID10_tract IN (SELECT GEOID10_tract FROM FINAL_TAZ_PUMA_MAPPING);

-- Append geographic ids to MAZ control table. This matches SQL Server's update
-- from the distinct MAZ/MZ_ID crosswalk records.
UPDATE control_totals_maz
SET MAZ = (
    SELECT g.MAZ FROM geographicCWalk g
    WHERE g.MZ_ID = control_totals_maz.MZ_ID
    ORDER BY g.MAZ
    LIMIT 1
    ),
    TAZ    = (SELECT TAZ    FROM geographicCWalk g WHERE g.MZ_ID = control_totals_maz.MZ_ID LIMIT 1),
    PUMA   = (SELECT PUMA   FROM geographicCWalk g WHERE g.MZ_ID = control_totals_maz.MZ_ID LIMIT 1),
    REGION = (SELECT REGION FROM geographicCWalk g WHERE g.MZ_ID = control_totals_maz.MZ_ID LIMIT 1);

-- Create temp list of tract IDs for filtering
CREATE TABLE temp_tract_list AS
SELECT DISTINCT GEOID10_tract FROM geographicCWalk;

-- Delete TAZ records not in the region
DELETE FROM control_totals_taz
WHERE GEOID10_tract NOT IN (SELECT GEOID10_tract FROM temp_tract_list);

-- Append geographic ids to taz control table
UPDATE control_totals_taz
SET TAZ = (SELECT TAZ FROM geographicCWalk g WHERE g.GEOID10_tract = control_totals_taz.GEOID10_tract LIMIT 1),
    PUMA = (SELECT PUMA FROM geographicCWalk g WHERE g.GEOID10_tract = control_totals_taz.GEOID10_tract LIMIT 1),
    REGION = (SELECT REGION FROM geographicCWalk g WHERE g.GEOID10_tract = control_totals_taz.GEOID10_tract LIMIT 1);

-- Fix issues in MAZ Controls FILE
UPDATE control_totals_maz
    SET POPNGQ = 0 WHERE POPNGQ<0;

-- ====== PHASE 5: PUMS SEED DATA PROCESSING ======

-- Build PUMA list from geographic crosswalk
CREATE TABLE temp_puma_list AS
SELECT DISTINCT PUMA FROM geographicCWalk;

-- Filter psam_h11 by PUMA (first pass with PUMA/100)
DELETE FROM psam_h11
WHERE PUMA NOT IN (SELECT PUMA/100 FROM temp_puma_list);

-- Filter psam_p11 by PUMA (first pass with PUMA/100)
DELETE FROM psam_p11
WHERE PUMA NOT IN (SELECT PUMA/100 FROM temp_puma_list);

-- Update PUMA numbers to match geographicCWalk format
UPDATE psam_h11
    SET PUMA = PUMA*100+ST;

UPDATE psam_p11
    SET PUMA = PUMA*100+ST;

-- Filter again with updated PUMA values
DELETE FROM psam_h11
WHERE PUMA NOT IN (SELECT PUMA FROM temp_puma_list);

DELETE FROM psam_p11
WHERE PUMA NOT IN (SELECT PUMA FROM temp_puma_list);

-- Update PUMS tables with legacy field mappings (for compatibility with downstream code)
UPDATE psam_p11
SET indp02 = INDP,
    naicsp02 = NAICSP,
    occp02 = OCCP,
    socp00 = SOCP,
    occp10 = OCCP,
    socp10 = SOCP,
    indp07 = INDP,
    naicsp07 = NAICSP
WHERE INDP IS NOT NULL;

-- ====== PHASE 6: CREATE HOUSEHOLD TABLE ======

CREATE TABLE hhtable (
    hhnum INTEGER,
    PUMA INT,
    WGTP INT,
    GQWGTP INT,
    SERIALNO TEXT,
    DIVISION INT,
    NP INT,
    hhincAdj INT,
    TEN INT,
    BLD INT,
    nwrkrs_esr INT,
    ADJINC INT,
    HINCP INT,
    VEH INT,
    HHT INT,
    TYPE INT,
    NPF INT,
    HUPAC INT,
    gqflag INT,
    gqtype INT,
    htype TEXT,
    hhchild TEXT
);

INSERT INTO hhtable (PUMA, WGTP, GQWGTP, SERIALNO, DIVISION, NP, hhincAdj, TEN, BLD, nwrkrs_esr, ADJINC, HINCP, VEH, HHT, TYPE, NPF, HUPAC, gqflag, gqtype, htype, hhchild)
SELECT 
    h.PUMA,
    h.WGTP,
    0 AS GQWGTP,
    h.SERIALNO,
    h.DIVISION,
    h.NP,
    CASE WHEN h.HINCP IS NOT NULL AND h.ADJINC IS NOT NULL
         THEN ROUND(CAST(h.HINCP AS REAL)*h.ADJINC/1000000.0 + 0.0000001, 2)
         ELSE NULL END AS hhincAdj,
    h.TEN,
    h.BLD,
    CASE WHEN hh_workers.nwrkrs_esr IS NULL THEN 0
         ELSE hh_workers.nwrkrs_esr END AS nwrkrs_esr,
    h.ADJINC,
    h.HINCP,
    h.VEH,
    h.HHT,
    h.TYPE,
    h.NPF,
    h.HUPAC,
    0 AS gqflag,
    0 AS gqtype,
    CASE WHEN h.BLD IN (2) THEN '1'
         WHEN h.BLD IN (4,5,6,7,8,9) THEN '2'
         WHEN h.BLD IN (1,10) THEN '3'
         WHEN h.BLD IN (3) THEN '4'
         ELSE '999' END AS htype,
    CASE WHEN h.HUPAC IN (4) THEN '1'
         WHEN h.HUPAC IN (1,2,3) THEN '2'
         ELSE '999' END AS hhchild
FROM psam_h11 h
LEFT JOIN (
    SELECT SERIALNO, COUNT(*) AS nwrkrs_esr
    FROM psam_p11
    WHERE ESR IN (1,2,4,5)
    GROUP BY SERIALNO
) AS hh_workers ON h.SERIALNO = hh_workers.SERIALNO
WHERE h.NP > 0 AND h.TYPE = 1;

-- ====== PHASE 7: CREATE PERSON TABLE ======

CREATE TABLE perstable_temp AS
SELECT 
    tt.PUMA,
    ht.WGTP,
    ht.GQWGTP,
    tt.SERIALNO,
    tt.SPORDER,
    tt.AGEP,
    tt.SEX,
    tt.WKHP,
    tt.COW,
    tt.ESR,
    tt.SCHG,
    tt.employed,
    tt.WKW,
    tt.MIL,
    tt.SCHL,
    tt.indp02,
    tt.indp07,
    tt.occp02,
    tt.occp10,
    tt.socp00,
    tt.socp10,
    tt.gqflag,
    tt.gqtype,
    tt.soc,
    CASE WHEN CAST(tt.soc AS INTEGER) IN (11,13,15,17,19,27,39) THEN '1'
         WHEN CAST(tt.soc AS INTEGER) IN (21,23,25,29,31) THEN '2'
         WHEN CAST(tt.soc AS INTEGER) IN (33,35,37) THEN '3'
         WHEN CAST(tt.soc AS INTEGER) IN (41,43) THEN '4'
         WHEN CAST(tt.soc AS INTEGER) IN (45,47,49) THEN '5'
         WHEN CAST(tt.soc AS INTEGER) IN (51,53,55) THEN '6'
         ELSE '999' END AS occp
FROM (
    SELECT 
        PUMA, SERIALNO, SPORDER, AGEP, SEX, WKHP, COW, ESR, SCHG,
        CASE WHEN ESR IN (1,2,4,5) THEN 1 ELSE 0 END AS employed,
        WKW, MIL, SCHL, indp02, indp07, occp02, occp10, socp00, socp10,
        CASE WHEN ESR NOT IN (1,2,4,5) OR ESR IS NULL THEN 999
             WHEN SUBSTR(TRIM(socp00), 1, 2) = 'N' OR SUBSTR(TRIM(socp00), 1, 2) = 'N.' THEN SUBSTR(TRIM(socp10), 1, 2)
             ELSE SUBSTR(TRIM(socp00), 1, 2) END AS soc,
        0 AS gqflag,
        0 AS gqtype
    FROM psam_p11
) AS tt
INNER JOIN hhtable ht ON tt.SERIALNO = ht.SERIALNO
WHERE ht.gqflag = 0;

DROP TABLE IF EXISTS perstable;
ALTER TABLE perstable_temp RENAME TO perstable;
ALTER TABLE perstable ADD COLUMN hhnum INTEGER;

-- ====== PHASE 8: ADD GROUP QUARTERS DATA ======

-- Populate GQ households (specify columns to avoid hhnum conflicts)
INSERT INTO hhtable (PUMA, WGTP, GQWGTP, SERIALNO, DIVISION, NP, hhincAdj, TEN, BLD, nwrkrs_esr, ADJINC, HINCP, VEH, HHT, TYPE, NPF, HUPAC, gqflag, gqtype, htype, hhchild)
SELECT 
    h.PUMA,
    0 AS WGTP,
    gq_workers.PWGTP AS GQWGTP,
    h.SERIALNO,
    h.DIVISION,
    h.NP,
    NULL AS hhincAdj,
    h.TEN,
    h.BLD,
    CASE WHEN gq_workers.nwrkrs_esr IS NULL THEN 0
         ELSE gq_workers.nwrkrs_esr END AS nwrkrs_esr,
    h.ADJINC,
    h.HINCP,
    h.VEH,
    h.HHT,
    h.TYPE,
    h.NPF,
    h.HUPAC,
    1 AS gqflag,
    CASE WHEN gq_workers.SCHG IN (6,7) THEN 1
         WHEN gq_workers.MIL = 1 THEN 2
         ELSE 4 END AS gqtype,
    '999' AS htype,
    '999' AS hhchild
FROM psam_h11 h
LEFT JOIN (
    SELECT SERIALNO, MAX(SCHG) AS SCHG, MAX(MIL) AS MIL, MAX(PWGTP) AS PWGTP,
            SUM(CASE WHEN ESR IN (1,2,4,5) THEN 1 ELSE 0 END) AS nwrkrs_esr
    FROM psam_p11
    GROUP BY SERIALNO
) AS gq_workers ON h.SERIALNO = gq_workers.SERIALNO
WHERE h.NP > 0 AND h.TYPE = 3;

-- Assign stable household identifiers from the current seed data.
WITH numbered_households AS (
    SELECT h.rowid,
           ROW_NUMBER() OVER (ORDER BY h.SERIALNO, h.rowid) AS assigned_hhnum
    FROM hhtable h
)
UPDATE hhtable
SET hhnum = (SELECT assigned_hhnum
             FROM numbered_households
             WHERE numbered_households.rowid = hhtable.rowid);
CREATE UNIQUE INDEX _ix_hhtable_hhnum ON hhtable (hhnum);

-- Populate GQ persons
INSERT INTO perstable
SELECT 
    tt.PUMA,
    ht.WGTP,
    tt.PWGTP AS GQWGTP,
    tt.SERIALNO,
    tt.SPORDER,
    tt.AGEP,
    tt.SEX,
    tt.WKHP,
    tt.COW,
    tt.ESR,
    tt.SCHG,
    tt.employed,
    tt.WKW,
    tt.MIL,
    tt.SCHL,
    tt.indp02,
    tt.indp07,
    tt.occp02,
    tt.occp10,
    tt.socp00,
    tt.socp10,
    tt.gqflag,
    tt.gqtype,
    tt.soc,
        CASE WHEN CAST(tt.soc AS INTEGER) IN (11,13,15,17,19,27,39) THEN '1'
            WHEN CAST(tt.soc AS INTEGER) IN (21,23,25,29,31) THEN '2'
            WHEN CAST(tt.soc AS INTEGER) IN (33,35,37) THEN '3'
            WHEN CAST(tt.soc AS INTEGER) IN (41,43) THEN '4'
            WHEN CAST(tt.soc AS INTEGER) IN (45,47,49) THEN '5'
            WHEN CAST(tt.soc AS INTEGER) IN (51,53,55) THEN '6'
         ELSE '999' END AS occp,
    ht.hhnum
FROM (
    SELECT 
        PUMA, PWGTP, SERIALNO, SPORDER, AGEP, SEX, WKHP, COW, ESR, SCHG,
        CASE WHEN ESR IN (1,2,4,5) THEN 1 ELSE 0 END AS employed,
        WKW, MIL, SCHL, indp02, indp07, occp02, occp10, socp00, socp10,
        CASE WHEN ESR NOT IN (1,2,4,5) OR ESR IS NULL THEN 999
             WHEN SUBSTR(TRIM(socp00), 1, 2) = 'N' OR SUBSTR(TRIM(socp00), 1, 2) = 'N.' THEN SUBSTR(TRIM(socp10), 1, 2)
             ELSE SUBSTR(TRIM(socp00), 1, 2) END AS soc,
        1 AS gqflag,
        CASE WHEN SCHG IN (6,7) THEN 1
             WHEN MIL = 1 THEN 2
             ELSE 4 END AS gqtype
    FROM psam_p11
) AS tt
INNER JOIN hhtable ht ON tt.SERIALNO = ht.SERIALNO
WHERE ht.gqflag = 1;

-- Link persons to household hhnum (non-GQ)
UPDATE perstable
SET hhnum = (SELECT hhnum FROM hhtable h WHERE h.SERIALNO = perstable.SERIALNO LIMIT 1)
WHERE hhnum IS NULL;

-- ====== PHASE 9: CLEANUP ======

DROP TABLE IF EXISTS TAZ_POP;
DROP TABLE IF EXISTS TAZ_PUMA_STATE_POP;
DROP TABLE IF EXISTS TAZ_PUMA_STATE_POP_COMPARE;
DROP TABLE IF EXISTS tractIDList;
DROP TABLE IF EXISTS temp_tract_list;
DROP TABLE IF EXISTS temp_puma_list;
DROP TABLE IF EXISTS hhtable_temp;
DROP TABLE IF EXISTS perstable_temp;

-- ====== VALIDATION QUERIES ======

.print "=== VALIDATION RESULTS ==="

SELECT 'control_totals_maz' AS table_name, COUNT(*) AS row_count FROM control_totals_maz
UNION ALL
SELECT 'control_totals_taz', COUNT(*) FROM control_totals_taz
UNION ALL
SELECT 'control_totals_meta', COUNT(*) FROM control_totals_meta
UNION ALL
SELECT 'geographicCWalk', COUNT(*) FROM geographicCWalk
UNION ALL
SELECT 'psam_h11', COUNT(*) FROM psam_h11
UNION ALL
SELECT 'psam_p11', COUNT(*) FROM psam_p11
UNION ALL
SELECT 'hhtable', COUNT(*) FROM hhtable
UNION ALL
SELECT 'perstable', COUNT(*) FROM perstable;

.print ""
.print "=== SETUP COMPLETE ==="
