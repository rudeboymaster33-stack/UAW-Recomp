@echo off
REM Play normally (rov render mode). FPS is logged every second to logs\play_rov.log. Close the game when done.
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0project\out\build\win-amd64-release"
copy /y "%~dp0rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
if exist "%~dp0logs\play_rov.log" move /y "%~dp0logs\play_rov.log" "%~dp0logs\play_rov_previous.log" >nul
cd /d "%BIN%"
uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rov --game_data_root="%GAME%" --log_file="%~dp0logs\play_rov.log"
