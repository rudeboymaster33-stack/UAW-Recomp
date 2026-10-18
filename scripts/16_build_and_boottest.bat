@echo off
REM Build test: rebuild with current manifest/flags, run the game 75 s, close it. Log -> logs\boottest.log
set "ROOT=%~dp0..\"
echo Rebuilding... (log: logs\03_game.log)
cmd /c ""%ROOT%scripts\game_inner.bat" > "%ROOT%logs\03_game.log" 2>&1"
if errorlevel 1 (echo BUILD FAILED & exit /b 1)
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%ROOT%project\out\build\win-amd64-release"
copy /y "%ROOT%rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
copy /y "%ROOT%rexglue-sdk\out\install\win-amd64\bin\rexruntime.dll" "%BIN%\" >nul
if exist "%ROOT%logs\boottest.log" move /y "%ROOT%logs\boottest.log" "%ROOT%logs\boottest_previous.log" >nul
cd /d "%BIN%"
start "" uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rtv --occlusion_query_enable=false --user_data_root="%ROOT%userdata" --game_data_root="%GAME%" --log_file="%ROOT%logs\boottest.log"
timeout /t 75 /nobreak >nul
taskkill /im uaw.exe /f >nul 2>&1
echo ==== BOOTTEST DONE > "%ROOT%logs\boottest_done.txt"
