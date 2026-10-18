@echo off
REM Android step 2: build the Android app (UniverseAtWar.apk). Takes a while the first time.
if not exist "%~dp0logs" mkdir "%~dp0logs"
echo Building the Android version... (log: logs\21_android_build.log)
cmd /c ""%~dp0scripts\android_build_inner.bat" > "%~dp0logs\21_android_build.log" 2>&1"
if errorlevel 1 (echo BUILD FAILED - Claude will read the log. & pause & exit /b 1)
echo.
echo Done: UniverseAtWar.apk is in the UAW-Recomp folder.
pause
