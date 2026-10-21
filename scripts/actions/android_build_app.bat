@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
if not exist "%ROOT%logs" mkdir "%ROOT%logs"
echo Building Halo 3 for the Retroid... (log: logs\21_android_build.log)
echo The first build recompiles the whole game and can take a few hours. Leave this window open.
cmd /c ""%ROOT%scripts\android_build_inner.bat" > "%ROOT%logs\21_android_build.log" 2>&1"
if errorlevel 1 (echo BUILD FAILED - tell Claude. & pause & exit /b 1)
echo.
echo Done: Halo3.apk is in the Halo3-Recomp folder.
exit /b 0
