@echo off
REM EXPERIMENT: rebuild, then run with the game's TargetFPS raised from 30 to 60.
REM Play the same skirmish as before, then close the game. Log -> logs\17_60fps.log
echo Rebuilding... (log: logs\03_game.log)
cmd /c ""%~dp0scripts\game_inner.bat" > "%~dp0logs\03_game.log" 2>&1"
if errorlevel 1 (echo BUILD FAILED - Claude will read the log. & pause & exit /b 1)
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0project\out\build\win-amd64-release"
copy /y "%~dp0rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
copy /y "%~dp0rexglue-sdk\out\install\win-amd64\bin\rexruntime.dll" "%BIN%\" >nul
cd /d "%BIN%"
set UAW_TARGET_FPS=60
echo Starting the game with the 60 FPS experiment... (log: logs\17_60fps.log)
uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rtv --occlusion_query_enable=false --vsync=false --user_data_root="%~dp0userdata" --game_data_root="%GAME%" --log_file="%~dp0logs\17_60fps.log"
echo Game exited. Claude will read the log. You can close this window.
pause
