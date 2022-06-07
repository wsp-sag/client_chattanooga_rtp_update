@echo off
REM Creates a TransCAD desktop shortcut with Arguments
REM Written by Steven Trevino 09Jan2015

set SCRIPT="%TEMP%\makeshortcut.vbs"

echo Set oWS = WScript.CreateObject("WScript.Shell") >> %SCRIPT%
echo sLinkFile = "%USERPROFILE%\Desktop\CHCRPA_Model.lnk" >> %SCRIPT%
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> %SCRIPT%
echo oLink.TargetPath = "%SystemDrive%\Program Files\TransCAD 7.0\Tcw.exe" >> %SCRIPT%
echo oLink.Arguments = "-a '%SystemDrive%\ChattaModel\chcrpa' -ai CHCRPA" >> %SCRIPT%
echo oLink.Description = "CHCRPA" >> %SCRIPT%
echo oLink.IconLocation = "%SystemDrive%\Program Files\TransCAD 7.0\tcw.exe,0" >> %SCRIPT%
echo oLink.WorkingDirectory = "%SystemDrive%\Program Files\TransCAD 7.0\" >> %SCRIPT%
echo oLink.WindowStyle = "3" >> %SCRIPT%
echo oLink.Save >> %SCRIPT%

cscript /nologo %SCRIPT%
del %SCRIPT%