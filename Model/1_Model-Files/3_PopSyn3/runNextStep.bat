REM ###########################################################################

SET SCENARIO=FY2022
SET SQLSERVER=TRF012298\SQLEXPRESS
SET DATABASE=Chattanooga
SET MY_PATH=%CD%

SET pumsHH_File1='C:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\ss11htn.csv'
SET pumsPersons_File1='C:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\ss11ptn.csv'
SET pumsHH_File2='C:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\ss11hga.csv'
SET pumsPersons_File2='C:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\ss11pga.csv'

SET mazData_File='C:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\2022\mazData.csv'
SET tractData_File='C:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\2022\tractData.csv'
SET metaData_File='C:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\2022\metaData.csv'
SET geographicCWalk_File='C:\Model\1_Model-Files\3_PopSyn3\PopSyn\data\MZ_geo_crosswalk.csv'

SET settingsFile=settings.xml
SET settingsFileGQ=settingsGQ.xml
REM ###########################################################################
@ECHO OFF

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