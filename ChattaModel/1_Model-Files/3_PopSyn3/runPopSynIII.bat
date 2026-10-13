
@echo off
cd /d "%~dp0"

pushd "%~dp0"

@REM TITLE Chattanooga MPO PopSynIII - SQLite
@REM cls

REM Batch file to run Chattanooga MPO PopSynIII with SQLite
REM Converted from SQL Server SQLCMD approach to SQLite CLI
REM Original: Binny M Paul, binny.paul@rsginc.com, 2015-07-22

SET "SCENARIO=BASEYEAR"
SET "MY_PATH=%CD%"
SET "DATABASE_PATH=%MY_PATH%\intermediate\chattanooga.db"
SET "SQLITE_EXE=%MY_PATH%\runtime\sqlite\sqlite3.exe"
SET "SETUP_SCRIPT=%MY_PATH%\runtime\scripts\PopSynSetup.sql"

@REM  REM ###########################################################################

@REM  REM Create output directory if needed
@REM  IF NOT EXIST outputs MD outputs
@REM  IF NOT EXIST intermediate MD intermediate

@REM  REM Remove existing database if present (start fresh)
@REM  IF EXIST "%DATABASE_PATH%" DEL "%DATABASE_PATH%"

ECHO %DATE% %TIME%: Starting Chattanooga MPO PopSynIII setup with SQLite...
ECHO Database location: %DATABASE_PATH%

REM Run setup script
ECHO %DATE% %TIME%: Executing PopSynSetup.sql...
"%SQLITE_EXE%" "%DATABASE_PATH%" < "%SETUP_SCRIPT%" > "%MY_PATH%\intermediate\serverLog.txt" 2>&1

IF %ERRORLEVEL% EQU 0 (
    ECHO %DATE% %TIME%: Completed processing successfully
    ECHO.
    ECHO Setup script executed successfully. >> "%MY_PATH%\intermediate\serverLog.txt"
    
    REM Run validation query to confirm database state
    ECHO. >> "%MY_PATH%\intermediate\serverLog.txt"
    ECHO. >> "%MY_PATH%\intermediate\serverLog.txt"
    ECHO Validation Results - Final Table Row Counts: >> "%MY_PATH%\intermediate\serverLog.txt"
    "%SQLITE_EXE%" "%DATABASE_PATH%" "SELECT 'hhtable: ' || COUNT(*) FROM hhtable; SELECT 'perstable: ' || COUNT(*) FROM perstable; SELECT 'control_totals_maz: ' || COUNT(*) FROM control_totals_maz; SELECT 'control_totals_taz: ' || COUNT(*) FROM control_totals_taz; SELECT 'geographicCWalk: ' || COUNT(*) FROM geographicCWalk;" >> "%MY_PATH%\intermediate\serverLog.txt" 2>&1
    
) ELSE (
    ECHO %DATE% %TIME%: ERROR - Setup script failed with code %ERRORLEVEL%
    ECHO ERROR: Setup script failed >> "%MY_PATH%\intermediate\serverLog.txt"
    EXIT /B 1
)

ECHO.
ECHO Check "%MY_PATH%\intermediate\serverLog.txt" for detailed output
ECHO Database file: %DATABASE_PATH%

"%SQLITE_EXE%" "%DATABASE_PATH%" < "%MY_PATH%\runtime\scripts\sqlite_to_csv.sql" > "%MY_PATH%\intermediate\serverLog.txt" 2>&1
IF NOT %ERRORLEVEL% EQU 0 (
    ECHO %DATE% %TIME%: ERROR - CSV export failed with code %ERRORLEVEL%
    EXIT /B 1
)


REM ###########################################################################

SET "MOD_PATH=%MY_PATH:\=/%/runtime/CT-RAMP"
SET "LOG_PATH=%MOD_PATH%/runScripts/popsyn"
SET "JAVA_64_PATH=%MOD_PATH%/lib/Java/jre1.8.0_31"
SET "GNUWIN32_PATH=/Progra~2/GnuWin32/bin"
SET "CUBE_PATH1=%MOD_PATH%/lib/VoyagerFileAPI/"
SET "CONFIG_PATH=%MOD_PATH%/config"

set JPPF_RELEASE=5.0.4 
set JPPF_PATH=%MOD_PATH%/lib/JPPF-%JPPF_RELEASE% 
set JPPF_CLIENT_PATH=%JPPF_PATH%/JPPF-%JPPF_RELEASE%-admin-ui/lib/* 
set JPPF_DRIVER_PATH=%JPPF_PATH%/JPPF-%JPPF_RELEASE%-driver 
set JPPF_NODE_PATH=%JPPF_PATH%/JPPF-%JPPF_RELEASE%-node 

set LIB_PATH=%MOD_PATH%/lib/logging-log4j-1.2.9/*;%MOD_PATH%/lib/jexcelapi/*;%MOD_PATH%/lib/* 
set JAR_PATH=%MOD_PATH%/jarFiles/*;%MOD_PATH%/jarfiles/MajorUniversity/*;%MOD_PATH%/jarfiles/coreABM/*
SET CLASSPATH=%MOD_PATH%;%CUBE_PATH1%;%LIB_PATH%;%JAR_PATH%;%JPPF_CLIENT_PATH%;%CONFIG_PATH%

REM ###########################################################################
:: environment variables for JPPF version
SET JPPF_RELEASE=5.0.4
SET JPPF_PATH=%MOD_PATH%/lib/JPPF-%JPPF_RELEASE%
SET JPPF_CLIENT_PATH=%JPPF_PATH%\JPPF-%JPPF_RELEASE%-admin-ui
SET JPPF_DRIVER_PATH=%JPPF_PATH%\JPPF-%JPPF_RELEASE%-driver
SET JPPF_NODE_PATH=%JPPF_PATH%\JPPF-%JPPF_RELEASE%-node

SET CLASSPATH=%JPPF_NODE_PATH%\config;%JPPF_NODE_PATH%\lib\*

CD %JPPF_NODE_PATH%

start "PopSyn JPPF Node" /B %JAVA_64_PATH%/bin/java.exe -Dname=javaPopNde -showversion -Xmx32m ^
 -Dlog4j.configuration=log4j-node.properties ^
 -Djppf.config=jppf-node.properties ^
 -Djava.util.logging.config.file=logging-node.properties ^ org.jppf.node.NodeLauncher

SET CLASSPATH=%JPPF_DRIVER_PATH%\config;%JPPF_DRIVER_PATH%\lib\*

CD %JPPF_DRIVER_PATH%

start "PopSyn JPPF Driver" /B %JAVA_64_PATH%/bin/java.exe -Dname=javaPopDrv -showversion -Xmx16m ^
 -Djppf.config=%CONFIG_PATH%/driverConfig/jppf-driver.properties ^
 -Dlog4j.configuration=log4j-driver.properties ^
 org.jppf.server.DriverLauncher

SET CLASSPATH=%CONFIG_PATH%;%MOD_PATH%/jarFiles/PopSyn/javaPop_ohio.jar;%JAR_PATH%/common-base-0.1.jar;%LIB_PATH%\commons-lang3-3.4\commons-lang3-3.4.jar;%MOD_PATH%\lib\ortools\com.google.ortools.jar;%JPPF_CLIENT_PATH%\lib\*

CD %MOD_PATH%/runScripts/
@REM ^ -Xdebug -Xrunjdwp:transport=dt_socket,address=1050,server=y,suspend=y 

%JAVA_64_PATH%/bin/java.exe -Dname=javaPop -showversion -Xmx64g ^ -Djppf.config=%CONFIG_PATH%/jppfPopSyn.properties ^ -Dlog4j.configuration=log4j.xml ^ -Djava.library.path=%MOD_PATH%\lib\ortools ^ com.wsp.popsyn.PopGenerator popsyn false 8 6 1.0e-15
SET "POPSYN_EXIT=%ERRORLEVEL%"

@REM %JAVA_64_PATH%/bin/java.exe -Dname=javaPop -showversion -Xmx64g ^
@REM -Xdebug -Xrunjdwp:transport=dt_socket,address=1050,server=y,suspend=y ^
@REM -Djppf.config=jppf2.properties ^
@REM -Dlog4j.configuration=log4j.xml ^
@REM -Djava.library.path=%MOD_PATH%\lib\ortools ^
@REM com.wsp.popsyn.PopGenerator popsynGQ false 8 6 1.0e-15

taskkill /F /T /FI "WINDOWTITLE eq PopSyn JPPF Node*" >NUL 2>&1
taskkill /F /T /FI "WINDOWTITLE eq PopSyn JPPF Driver*" >NUL 2>&1

cd ..
cd ..
cd ..

EXIT /B %POPSYN_EXIT%