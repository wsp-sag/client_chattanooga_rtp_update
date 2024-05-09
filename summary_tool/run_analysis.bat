@echo off
REM Call main script to run summary tool
SET "ORIGINAL_DIR=%CD%"
SET "ORIGINAL_DIR=%ORIGINAL_DIR:\=/%"
SET "SUMMARY_PYTHON_PATH=%ORIGINAL_DIR%\scripts\environment\"

"%SUMMARY_PYTHON_PATH%python.exe" "%ORIGINAL_DIR%\scripts\run_analysis.py"