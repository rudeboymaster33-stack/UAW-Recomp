@echo off
echo Building the ReXGlue SDK... this window shows nothing; progress goes to logs\02_build_sdk.log
cmd /c ""%~dp0scripts\build_sdk_inner.bat" > "%~dp0logs\02_build_sdk.log" 2>&1"
echo Finished. Claude will read the log. You can close this window.
pause
