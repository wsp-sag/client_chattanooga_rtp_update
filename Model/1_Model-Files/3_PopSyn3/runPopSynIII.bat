@echo off
TITLE Chattanooga MPO PopSynIII
cls

REM # Batch file to run Chattanooga MPO PopSynIII for future year 2045
REM # Binny M Paul, binny.paul@rsginc.com, July 2016
REM ###########################################################################

SET SCENARIO=FY2045
SET SQLSERVER=EVAMDLPPW01
SET DATABASE=Chattanooga
SET MY_PATH=%CD%

SET pumsHH_File1='E:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\ss11htn.csv'
SET pumsPersons_File1='E:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\ss11ptn.csv'
SET pumsHH_File2='E:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\ss11hga.csv'
SET pumsPersons_File2='E:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\ss11pga.csv'

SET mazData_File='E:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\mazData.csv'
SET tractData_File='E:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\tractData.csv'
SET metaData_File='E:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\metaData.csv'
SET geographicCWalk_File='E:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\MZ_geo_crosswalk.csv'

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
SET JAVA_64_PATH="C:\Program Files\Java\jre1.8.0_141"
SET CLASSPATH=runtime\config
SET CLASSPATH=%CLASSPATH%;runtime\*
SET CLASSPATH=%CLASSPATH%;runtime\lib\*
SET CLASSPATH=%CLASSPATH%;runtime\lib\JPFF-3.2.2\JPPF-3.2.2-admin-ui\lib\*
SET LIBPATH=runtime\lib

%JAVA_64_PATH%\bin\java -showversion -server -Xms25000m -Xmx25000m -cp "%CLASSPATH%" -Djppf.config=jppf-clientLocal.properties -Djava.library.path=%LIBPATH% popGenerator.PopGenerator runtime/config/%settingsFile% 
ECHO %startTime%%Time%: Population synthesis complete...

%JAVA_64_PATH%\bin\java -showversion -server -Xms15000m -Xmx15000m -cp "%CLASSPATH%" -Djppf.config=jppf-clientLocal.properties -Djava.library.path=%LIBPATH% popGenerator.PopGenerator runtime/config/%settingsFileGQ%
ECHO Population synthesis complete for group quarters population...

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
