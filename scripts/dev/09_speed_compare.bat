@echo off
REM Rebuild, then speed test: 210 s ROV mode, 210 s RTV mode. FPS is logged once per second.
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0..\..\project\out\build\win-amd64-release"
copy /y "%~dp0..\..\rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
cd /d "%BIN%"
for %%M in (rov rtv) do (
  echo Speed test: %%M mode for 210 seconds - please don't touch the game
  if exist "%~dp0..\..\logs\speed_%%M.log" move /y "%~dp0..\..\logs\speed_%%M.log" "%~dp0..\..\logs\speed_%%M_previous.log" >nul
  start "" uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=%%M --game_data_root="%GAME%" --log_file="%~dp0..\..\logs\speed_%%M.log"
  timeout /t 210 /nobreak >nul
  taskkill /im uaw.exe /f >nul 2>&1
  timeout /t 5 /nobreak >nul
)
echo Done. Claude will read logs\speed_rov.log and logs\speed_rtv.log. You can close this window.
pause
