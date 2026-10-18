@echo off
REM Rebuild with the latest manifest, then launch the game (with GPU emulation)
echo Rebuilding... (log: logs\03_game.log)
cmd /c ""%~dp0..\..\scripts\game_inner.bat" > "%~dp0..\..\logs\03_game.log" 2>&1"
if errorlevel 1 (echo BUILD FAILED - Claude will read the log. & pause & exit /b 1)
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0..\..\project\out\build\win-amd64-release"
copy /y "%~dp0..\..\rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
copy /y "%~dp0..\..\rexglue-sdk\out\install\win-amd64\bin\rexruntime.dll" "%BIN%\" >nul
cd /d "%BIN%"
if exist "%~dp0..\..\logs\04_run.log" move /y "%~dp0..\..\logs\04_run.log" "%~dp0..\..\logs\04_run_previous.log" >nul
echo Starting the game... (log: logs\04_run.log)
uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rtv --occlusion_query_enable=false --user_data_root="%~dp0..\..\userdata" --game_data_root="%GAME%" --log_file="%~dp0..\..\logs\04_run.log" > "%~dp0..\..\logs\04_run_console.log" 2>&1
echo Game exited with code %ERRORLEVEL% >> "%~dp0..\..\logs\04_run_console.log"
echo Game exited (code %ERRORLEVEL%). Claude will read the log. You can close this window.
pause
