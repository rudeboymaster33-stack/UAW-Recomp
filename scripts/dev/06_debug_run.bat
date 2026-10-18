@echo off
REM Debug run: build with symbols, run the game, then identify where it crashed
echo Building debug-symbol version... (log: logs\06_debug_build.log)
cmd /c ""%~dp0..\..\scripts\debug_build_inner.bat" > "%~dp0..\..\logs\06_debug_build.log" 2>&1"
if errorlevel 1 (echo BUILD FAILED - Claude will read the log. & pause & exit /b 1)
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0..\..\project\out\build\win-amd64-relwithdebinfo"
copy /y "%~dp0..\..\rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
copy /y "%~dp0..\..\rexglue-sdk\out\install\win-amd64\bin\rexruntime.dll" "%BIN%\" >nul
if exist "%~dp0..\..\logs\06_run.log" move /y "%~dp0..\..\logs\06_run.log" "%~dp0..\..\logs\06_run_previous.log" >nul
cd /d "%BIN%"
echo Starting the game... (log: logs\06_run.log)
uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rtv --occlusion_query_enable=false --user_data_root="%~dp0..\..\userdata" --game_data_root="%GAME%" --log_file="%~dp0..\..\logs\06_run.log" > "%~dp0..\..\logs\06_run_console.log" 2>&1
echo Game exited with code %ERRORLEVEL% >> "%~dp0..\..\logs\06_run_console.log"
timeout /t 5 /nobreak >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\scripts\symbolize_crash.ps1"
echo Done. Claude will read logs\06_crash.txt. You can close this window.
pause
