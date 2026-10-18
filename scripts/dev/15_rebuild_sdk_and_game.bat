@echo off
REM Rebuild the SDK (after applying patches in patches\) and then rebuild + run the game.
echo Rebuilding the ReXGlue SDK... (log: logs\02_build_sdk.log)
cmd /c ""%~dp0..\..\scripts\build_sdk_inner.bat" > "%~dp0..\..\logs\02_build_sdk.log" 2>&1"
if errorlevel 1 (echo SDK BUILD FAILED - Claude will read the log. & pause & exit /b 1)
call "%~dp0..\..\05_rebuild_and_run.bat"
