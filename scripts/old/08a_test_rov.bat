@echo off
REM Speed test with render path rov: runs the game ~130 s then closes it. Press F3 in game for the FPS overlay.
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0project\out\build\win-amd64-release"
copy /y "%~dp0rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
cd /d "%BIN%"
start "" uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rov --game_data_root="%GAME%" --log_file="%~dp0logs\test_rov.log"
timeout /t 130 /nobreak >nul
taskkill /im uaw.exe /f >nul 2>&1
