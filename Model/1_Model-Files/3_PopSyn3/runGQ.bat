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

ECHO %startTime%%Time%: Running population synthesizer...
SET JAVA_64_PATH="C:\Program Files\Java\jre1.8.0_181"
SET CLASSPATH=runtime\config
SET CLASSPATH=%CLASSPATH%;runtime\*
SET CLASSPATH=%CLASSPATH%;runtime\lib\*
SET CLASSPATH=%CLASSPATH%;runtime\lib\JPFF-3.2.2\JPPF-3.2.2-admin-ui\lib\*
SET LIBPATH=runtime\lib

%JAVA_64_PATH%\bin\java -showversion -server -Xms15000m -Xmx15000m -cp "%CLASSPATH%" -Djppf.config=jppf-clientLocal.properties -Djava.library.path=%LIBPATH% popGenerator.PopGenerator runtime/config/%settingsFileGQ%
ECHO Population synthesis complete for group quarters population...

REM ###########################################################################