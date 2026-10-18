@echo off
REM TEST: RTV + vsync off + occlusion queries off. Play the same skirmish ~1 min, then close. FPS -> logs\play_test12.log
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0project\out\build\win-amd64-release"
copy /y "%~dp0rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
if exist "%~dp0logs\play_test12.log" move /y "%~dp0logs\play_test12.log" "%~dp0logs\play_test12_previous.log" >nul
cd /d "%BIN%"
uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rtv --vsync=false --occlusion_query_enable=false --game_data_root="%GAME%" --log_file="%~dp0logs\play_test12.log"
