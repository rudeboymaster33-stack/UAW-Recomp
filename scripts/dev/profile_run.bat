@echo off
REM TEMPORARY TEST: rebuild the PC game with the sampling profiler, then play a skirmish.
REM Close the game when done. Log -> logs\profile.log
echo Rebuilding... (log: logs\03_game.log)
cmd /c ""%~dp0..\..\scripts\game_inner.bat" > "%~dp0..\..\logs\03_game.log" 2>&1"
if errorlevel 1 (echo BUILD FAILED - Claude will read the log. & pause & exit /b 1)
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0..\..\project\out\build\win-amd64-release"
copy /y "%~dp0..\..\rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
copy /y "%~dp0..\..\rexglue-sdk\out\install\win-amd64\bin\rexruntime.dll" "%BIN%\" >nul
cd /d "%BIN%"
set UAW_PROFILE=1
echo Starting the game with the profiler... play a skirmish for 3-4 minutes, then close the game.
uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rtv --occlusion_query_enable=false --user_data_root="%~dp0..\..\userdata" --game_data_root="%GAME%" --log_file="%~dp0..\..\logs\profile.log"
echo Game closed. Tell Claude. You can close this window.
pause
