@echo off
REM Benchmark: run the game 100 s with ROV (current default on Intel), then 100 s with RTV. Logs frame times.
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "BIN=%~dp0project\out\build\win-amd64-release"
set "L=%~dp0logs"
copy /y "%~dp0rexglue-sdk\out\install\win-amd64\bin\rexgpu-xenos.dll" "%BIN%\" >nul
cd /d "%BIN%"
for %%M in (rov rtv) do (
  echo Benchmark run: render path %%M ... 100 seconds, please don't touch the game window
  start "" uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=%%M --perf_log_csv="%L%\bench_%%M.csv" --game_data_root="%GAME%" --log_file="%L%\bench_%%M.log"
  timeout /t 100 /nobreak >nul
  taskkill /im uaw.exe /f >nul 2>&1
  timeout /t 5 /nobreak >nul
)
echo Benchmark finished. Claude will read logs\bench_rov.csv and logs\bench_rtv.csv. You can close this window.
pause
