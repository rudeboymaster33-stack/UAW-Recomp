@echo off
REM Diagnostic: run 150 s with detailed (debug) logging, then close. Log -> logs\debug_run.log
set "ROOT=%~dp0..\"
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%ROOT%project\out\build\win-amd64-release"
copy /y "%ROOT%rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
if exist "%ROOT%logs\debug_run.log" move /y "%ROOT%logs\debug_run.log" "%ROOT%logs\debug_run_previous.log" >nul
cd /d "%BIN%"
start "" uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rtv --occlusion_query_enable=false --log_level=debug --game_data_root="%GAME%" --log_file="%ROOT%logs\debug_run.log"
timeout /t 150 /nobreak >nul
taskkill /im uaw.exe /f >nul 2>&1
