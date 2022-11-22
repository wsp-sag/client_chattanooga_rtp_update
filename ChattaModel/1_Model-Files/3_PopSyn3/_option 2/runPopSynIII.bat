@echo off
TITLE Chattanooga MPO PopSynIII
cls

REM # Batch file to run Chattanooga MPO PopSynIII
REM # Binny M Paul, binny.paul@rsginc.com, 2015-07-22
REM ###########################################################################

SET SCENARIO=BASEYEAR
SET SQLSERVER=L19US-D9295PD2\USYS671257
SET DATABASE=Chattanooga
SET MY_PATH=%CD%

SET pumsHH_File1='C:\Users\USYS671257\Desktop\PopSyn2019\data\ss19htn.csv'
SET pumsPersons_File1='C:\Users\USYS671257\Desktop\PopSyn2019\data\ss19ptn.csv'
SET pumsHH_File2='C:\Users\USYS671257\Desktop\PopSyn2019\data\ss19hga.csv'
SET pumsPersons_File2='C:\Users\USYS671257\Desktop\PopSyn2019\data\ss19pga.csv'

SET mazData_File='C:\Users\USYS671257\Desktop\PopSyn2019\data\mazData.csv'
SET tractData_File='C:\Users\USYS671257\Desktop\PopSyn2019\data\tractData.csv'
SET metaData_File='C:\Users\USYS671257\Desktop\PopSyn2019\data\metaData.csv'
SET geographicCWalk_File='C:\Users\USYS671257\Desktop\PopSyn2019\data\MZ_geo_crosswalk.csv'

SET settingsFile=settings.xml
SET settingsFileGQ=settingsGQ.xml
REM ###########################################################################

@ECHO OFF

ECHO %startTime%%Time%: Processing input tables...
IF NOT EXIST outputs MD outputs
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "IF OBJECT_ID('dbo.csv_filenames') IS NOT NULL DROP TABLE csv_filenames;" -o "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "CREATE TABLE csv_filenames(dsc varchar(100), filename varchar(256));" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "INSERT INTO csv_filenames(dsc, filename) VALUES ('pumsHH_File1', %pumsHH_File1%);" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "INSERT INTO csv_filenames(dsc, filename) VALUES ('pumsPersons_File1', %pumsPersons_File1%);" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "INSERT INTO csv_filenames(dsc, filename) VALUES ('pumsHH_File2', %pumsHH_File2%);" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "INSERT INTO csv_filenames(dsc, filename) VALUES ('pumsPersons_File2', %pumsPersons_File2%);" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "INSERT INTO csv_filenames(dsc, filename) VALUES ('mazData_File', %mazData_File%);" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "INSERT INTO csv_filenames(dsc, filename) VALUES ('tazData_File', %tractData_File%);" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "INSERT INTO csv_filenames(dsc, filename) VALUES ('metaData_File', %metaData_File%);" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "INSERT INTO csv_filenames(dsc, filename) VALUES ('geographicCWalk_File', %geographicCWalk_File%);" >> "%MY_PATH%\outputs\serverLog"

SQLCMD -S %SQLSERVER% -d %DATABASE% -E -i "%MY_PATH%\scripts\insert_control.sql" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -i "%MY_PATH%\scripts\insert_seed.sql" >> "%MY_PATH%\outputs\serverLog"

ECHO %startTime%%Time%: Completed processing input tables...

REM ###########################################################################

ECHO %startTime%%Time%: Running population synthesizer...
SET JAVA_HOME="C:\Program Files\Java\jdk-17.0.3.1"

PopsynIII_Standard.exe
ECHO %startTime%%Time%: Population synthesis complete...
COPY outputs\event.log outputs\event_std.log

PopsynIII_GQ.exe
ECHO Population synthesis complete for group quarters population...
COPY outputs\event.log outputs\event_gq.log

REM ###########################################################################

ECHO %startTime%%Time%: Create %SCENARIO% schema and output CSV files
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "IF OBJECT_ID('%SCENARIO%.control_totals_maz') IS NOT NULL DROP TABLE %SCENARIO%.control_totals_maz;" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "IF OBJECT_ID('%SCENARIO%.control_totals_taz') IS NOT NULL DROP TABLE %SCENARIO%.control_totals_taz;" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "IF OBJECT_ID('%SCENARIO%.control_totals_meta') IS NOT NULL DROP TABLE %SCENARIO%.control_totals_meta;" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "IF OBJECT_ID('%SCENARIO%.persons') IS NOT NULL DROP TABLE %SCENARIO%.persons;" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "IF OBJECT_ID('%SCENARIO%.households') IS NOT NULL DROP TABLE %SCENARIO%.households;" >> "%MY_PATH%\outputs\serverLog"

SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "IF EXISTS (SELECT * FROM sys.schemas WHERE name = '%SCENARIO%') DROP SCHEMA %SCENARIO%;" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "CREATE SCHEMA %SCENARIO%;" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -i "%MY_PATH%\scripts\generate_hh_persons.sql" >> "%MY_PATH%\outputs\serverLog"

SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "SELECT * INTO %SCENARIO%.control_totals_maz FROM dbo.control_totals_maz;" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "SELECT * INTO %SCENARIO%.control_totals_taz FROM dbo.control_totals_taz;" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "SELECT * INTO %SCENARIO%.control_totals_meta FROM dbo.control_totals_meta;" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "SELECT * INTO %SCENARIO%.households FROM dbo.households;" >> "%MY_PATH%\outputs\serverLog"
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -Q "SELECT * INTO %SCENARIO%.persons FROM dbo.persons;" >> "%MY_PATH%\outputs\serverLog"

REM # remove row with ----- in SQL tables
SQLCMD -S %SQLSERVER% -d %DATABASE% -E -s, -W -Q "SET NOCOUNT ON; SELECT * FROM dbo.persons ORDER BY HHID, SPORDER" >  "%MY_PATH%\outputs\persons.tmp"
TYPE %MY_PATH%\outputs\persons.tmp | findstr /r /v ^\-[,\-]*$ > %MY_PATH%\outputs\persons2.tmp
REM # Replace NULL with -9 and N.A. with -8
@ECHO OFF
SETLOCAL
SET PATH=%CD%\%LIBPATH%;%PATH%
type %MY_PATH%\outputs\persons2.tmp |repl "NULL" "-9" |repl "N\.A\." "-8" > %MY_PATH%\outputs\persons.csv
ENDLOCAL
DEL %MY_PATH%\outputs\persons.tmp
DEL %MY_PATH%\outputs\persons2.tmp

SQLCMD -S %SQLSERVER% -d %DATABASE% -E -s, -W -Q "SET NOCOUNT ON; SELECT * FROM dbo.households ORDER BY HHID" >  "%MY_PATH%\outputs\households.tmp"
TYPE %MY_PATH%\outputs\households.tmp | findstr /r /v ^\-[,\-]*$ > %MY_PATH%\outputs\households2.tmp
REM # Replace NULL with -9 and N.A. with -8
@ECHO OFF
SETLOCAL
SET PATH=%CD%\%LIBPATH%;%PATH%
type %MY_PATH%\outputs\households2.tmp |repl "NULL" "-9" |repl "N\.A\." "-8" > %MY_PATH%\outputs\households.csv
ENDLOCAL
DEL %MY_PATH%\outputs\households.tmp
DEL %MY_PATH%\outputs\households2.tmp

SQLCMD -S %SQLSERVER% -d %DATABASE% -E -s, -W -Q "SET NOCOUNT ON; SELECT * FROM dbo.geographicCWalk ORDER BY MZ_ID" >  "%MY_PATH%\outputs\geographicCWalk.csv"
