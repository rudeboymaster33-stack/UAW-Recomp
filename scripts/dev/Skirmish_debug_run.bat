@echo off
REM TEMPORARY TEST: PC game with a detailed log, to check the skirmish setup screen.
REM Close the game when done. Log -> logs\profile.log
echo Rebuilding... (log: logs\03_game.log)
cmd /c ""%~dp0..\..\scripts\game_inner.bat" > "%~dp0..\..\logs\03_game.log" 2>&1"
if errorlevel 1 (echo BUILD FAILED - Claude will read the log. & pause & exit /b 1)
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0..\..\project\out\build\win-amd64-release"
copy /y "%~dp0..\..\rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
copy /y "%~dp0..\..\rexglue-sdk\out\install\win-amd64\bin\rexruntime.dll" "%BIN%\" >nul
cd /d "%BIN%"
set UAW_PROFILE=
echo Starting the game with detailed logging... open Skirmish, try to pick a faction and start, then close the game.
uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rtv --occlusion_query_enable=false --user_data_root="%~dp0..\..\userdata" --game_data_root="%GAME%" --log_level=debug --log_file="%~dp0..\..\logs\debug_skirmish.log"
echo Game closed. Tell Claude. You can close this window.
pause
