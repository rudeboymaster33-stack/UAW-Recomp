@echo off
REM TEST: RTV + occlusion off + GPU readback of memexport/resolve data (for blinking models). FPS -> logs\play_test13.log
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0..\..\project\out\build\win-amd64-release"
copy /y "%~dp0..\..\rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
if exist "%~dp0..\..\logs\play_test13.log" move /y "%~dp0..\..\logs\play_test13.log" "%~dp0..\..\logs\play_test13_previous.log" >nul
cd /d "%BIN%"
uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rtv --occlusion_query_enable=false --d3d12_readback_memexport=true --d3d12_readback_resolve=true --game_data_root="%GAME%" --log_file="%~dp0..\..\logs\play_test13.log"
