@echo off
REM Step 4: launch the recompiled game (first boot test)
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
copy /y "%~dp0rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%~dp0project\out\build\win-amd64-release\" >nul
cd /d "%~dp0project\out\build\win-amd64-release"
if exist "%~dp0logs\04_run.log" move /y "%~dp0logs\04_run.log" "%~dp0logs\04_run_previous.log" >nul
echo Starting Universe at War (recompiled)... log: logs\04_run.log
uaw.exe --gpu_plugin=xenos --mnk_mode=true --game_data_root="%GAME%" --log_file="%~dp0logs\04_run.log" > "%~dp0logs\04_run_console.log" 2>&1
echo Game exited with code %ERRORLEVEL% >> "%~dp0logs\04_run_console.log"
echo Game exited (code %ERRORLEVEL%). Claude will read the log. You can close this window.
pause
