@echo off
REM TEST PLAN: runs the game once for every file in scripts\test_plan\*.txt, with no input needed.
REM Each file holds the extra settings for that run (one per line, like android_test_args.txt).
REM An optional line "#wait=NN" sets how many seconds that run lasts (default 90).
REM Results per run: logs\plan\<name>_mid.png, <name>.png (end), <name>.log, <name>_logcat.txt
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
call "%ROOT%scripts\android_paths.bat"
set "PLAN=%ROOT%scripts\test_plan"
set "OUT=%ROOT%logs\plan"
if not exist "%OUT%" mkdir "%OUT%"
del /q "%OUT%\*" >nul 2>&1
set COUNT=0
for %%F in ("%PLAN%\*.txt") do set /a COUNT+=1
set N=0
for %%F in ("%PLAN%\*.txt") do call :one "%%~fF" "%%~nF"
echo all %COUNT% runs finished> "%OUT%\done.txt"
echo.
echo ==== ALL %COUNT% TEST RUNS DONE. Tell Claude.
exit /b 0

:one
set /a N+=1
set "WAITS=90"
for /f "usebackq tokens=2 delims==" %%W in (`findstr /b /c:"#wait=" "%~1"`) do set "WAITS=%%W"
set /a HALF=WAITS/2
set "PROF=0"
set "PFT=0"
for /f "usebackq tokens=2 delims==" %%W in (`findstr /b /c:"#perfetto=" "%~1"`) do set "PFT=%%W"
for /f "usebackq tokens=2 delims==" %%W in (`findstr /b /c:"#profile=" "%~1"`) do set "PROF=%%W"
echo [%TIME%] Run %N% of %COUNT%: %~2 (%WAITS% s)
"%ADB%" shell am force-stop %PKG%
"%ADB%" shell rm -rf %PKGDIR%/halo3.log %PKGDIR%/args.txt %PKGDIR%/env.txt %PKGDIR%/dump
"%ADB%" push "%~1" %PKGDIR%/args.txt >nul 2>&1
if exist "%ROOT%scripts\android_test_env.txt" "%ADB%" push "%ROOT%scripts\android_test_env.txt" %PKGDIR%/env.txt >nul 2>&1
"%ADB%" logcat -c
"%ADB%" push "%ROOT%scripts\android_monitor.sh" /data/local/tmp/halo3_mon.sh >nul 2>&1
start "Retroid monitor" /min cmd /c ""%ADB%" shell sh /data/local/tmp/halo3_mon.sh > "%OUT%\%~2_gpu.txt" 2>&1 < nul"
"%ADB%" shell am start -n %PKG%/.Halo3Activity >nul
timeout /t %HALF% /nobreak >nul
"%ADB%" exec-out screencap -p > "%OUT%\%~2_mid.png"
"%ADB%" shell "top -H -b -n 2 -d 3 -m 25 -p $(pidof %PKG%)" > "%OUT%\%~2_threads.txt" 2>&1
timeout /t %HALF% /nobreak >nul
"%ADB%" exec-out screencap -p > "%OUT%\%~2.png"
"%ADB%" shell pidof %PKG% > "%OUT%\%~2_alive.txt" 2>&1
if not "%PROF%"=="0" call :profile "%~2"
if not "%PFT%"=="0" call :perfetto "%~2"
"%ADB%" shell pkill -f halo3_mon.sh >nul 2>&1
"%ADB%" shell am force-stop %PKG%
"%ADB%" pull %PKGDIR%/halo3.log "%OUT%\%~2.log" >nul 2>&1
"%ADB%" logcat -d -v threadtime > "%OUT%\%~2_logcat.txt" 2>&1
"%ADB%" shell ls %PKGDIR%/dump >nul 2>&1 && (
  mkdir "%OUT%\%~2_dump" >nul 2>&1
  "%ADB%" pull %PKGDIR%/dump "%OUT%\%~2_dump" >nul 2>&1
)
exit /b 0

:profile
REM "#profile=NN" in a run file: sample the running game's CPU use for NN seconds with simpleperf.
set "SPERF=%ROOT%..\UAW-Recomp\android-tools\sdk\ndk\27.2.12479018\simpleperf\bin\android\arm64\simpleperf"
if not exist "%SPERF%" (echo simpleperf not found> "%OUT%\%~1_perf_report.txt" & exit /b 0)
echo   profiling the CPU for %PROF% s...
"%ADB%" push "%SPERF%" /data/local/tmp/simpleperf >nul 2>&1
"%ADB%" shell chmod 755 /data/local/tmp/simpleperf
"%ADB%" shell rm -f /data/local/tmp/h3perf.data
"%ADB%" shell "/data/local/tmp/simpleperf list" > "%OUT%\%~1_perf_events.txt" 2>&1
"%ADB%" shell "/data/local/tmp/simpleperf record --app %PKG% -f 2000 --duration %PROF% -o /data/local/tmp/h3perf.data" > "%OUT%\%~1_perf_record.txt" 2>&1
"%ADB%" shell "ls /data/local/tmp/h3perf.data" >nul 2>&1 || "%ADB%" shell "/data/local/tmp/simpleperf record --app %PKG% -e task-clock -f 2000 --duration %PROF% -o /data/local/tmp/h3perf.data" >> "%OUT%\%~1_perf_record.txt" 2>&1
"%ADB%" shell "/data/local/tmp/simpleperf report -i /data/local/tmp/h3perf.data --sort comm,dso -n" > "%OUT%\%~1_perf_threads.txt" 2>&1
"%ADB%" shell "/data/local/tmp/simpleperf report -i /data/local/tmp/h3perf.data --sort comm,dso,symbol -n --percent-limit 0.2" > "%OUT%\%~1_perf_report.txt" 2>&1
exit /b 0

:perfetto
REM "#perfetto=1" in a run file: record a few seconds of GPU hardware counters and render stages.
echo   recording GPU counters...
"%ADB%" shell perfetto --query > "%OUT%\%~1_perfetto_sources.txt" 2>&1
"%ADB%" shell rm -f /data/misc/perfetto-traces/h3.pftrace >nul 2>&1
"%ADB%" shell perfetto -c - --txt -o /data/misc/perfetto-traces/h3.pftrace < "%ROOT%scripts\h3_perfetto.cfg" > "%OUT%\%~1_perfetto_log.txt" 2>&1
"%ADB%" pull /data/misc/perfetto-traces/h3.pftrace "%OUT%\%~1.pftrace" >> "%OUT%\%~1_perfetto_log.txt" 2>&1
exit /b 0
