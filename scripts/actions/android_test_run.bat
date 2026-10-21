@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
REM ONE-CLICK TEST: rebuild, install on the Retroid, start with the profiler, wait, then copy the logs back for Claude.
call "%ROOT%scripts\android_paths.bat"
echo [1/4] Building the Android app... (log: logs\21_android_build.log)
cmd /c ""%ROOT%scripts\android_build_inner.bat" > "%ROOT%logs\21_android_build.log" 2>&1"
if errorlevel 1 (echo BUILD FAILED - tell Claude. & pause & exit /b 1)
echo [2/4] Installing on the Retroid...
"%ADB%" shell am force-stop %PKG%
"%ADB%" install -r "%ROOT%Halo3.apk" > "%ROOT%logs\22_install.log" 2>&1
if errorlevel 1 (echo INSTALL FAILED - is the Retroid plugged in? Tell Claude. & pause & exit /b 1)
> "%ROOT%logs\profile_on.txt" echo profile
"%ADB%" push "%ROOT%logs\profile_on.txt" %PKGDIR%/profile_on >nul 2>&1
"%ADB%" shell rm -f %PKGDIR%/halo3.log %PKGDIR%/args.txt %PKGDIR%/env.txt
if exist "%ROOT%scripts\android_test_args.txt" "%ADB%" push "%ROOT%scripts\android_test_args.txt" %PKGDIR%/args.txt >nul 2>&1
if exist "%ROOT%scripts\android_test_env.txt" "%ADB%" push "%ROOT%scripts\android_test_env.txt" %PKGDIR%/env.txt >nul 2>&1
"%ADB%" logcat -c
echo [3/4] Starting the game on the Retroid.
"%ADB%" push "%ROOT%scripts\android_monitor.sh" /data/local/tmp/halo3_mon.sh >nul 2>&1
start "Retroid monitor (closes by itself)" /min cmd /c ""%ADB%" shell sh /data/local/tmp/halo3_mon.sh > "%ROOT%logs\android_gpu_cpu.txt" 2>&1 < nul"
"%ADB%" shell am start -n %PKG%/.Halo3Activity >nul
echo.
echo     When you're done (or if it closes), come back here and press any key.
pause >nul
echo [4/4] Copying logs...
"%ADB%" exec-out screencap -p > "%ROOT%logs\android_screen.png"
"%ADB%" shell pkill -f halo3_mon.sh >nul 2>&1
"%ADB%" pull %PKGDIR%/halo3.log "%ROOT%logs\android_halo3.log" > "%ROOT%logs\23_logs.log" 2>&1
"%ADB%" logcat -d -v threadtime > "%ROOT%logs\android_logcat.txt" 2>&1
"%ADB%" pull %PKGDIR%/dump "%ROOT%logs" > "%ROOT%logs\24_dump_pull.log" 2>&1
"%ADB%" shell rm -rf %PKGDIR%/dump
"%ADB%" shell rm -f %PKGDIR%/profile_on %PKGDIR%/args.txt %PKGDIR%/env.txt
echo Done. Tell Claude. You can close this window.
pause
