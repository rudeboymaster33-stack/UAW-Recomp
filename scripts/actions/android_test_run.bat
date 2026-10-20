@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
REM ONE-CLICK TEST: rebuild the Android app, install it on the Retroid, start the game with the
REM profiler, wait while you play, then copy the logs back for Claude.

set "ADB=%ROOT%android-tools\sdk\platform-tools\adb.exe"
set "PKGDIR=/sdcard/Android/data/com.uaw.recomp/files"
echo [1/4] Building the Android app... (log: logs\21_android_build.log)
cmd /c ""%ROOT%scripts\android_build_inner.bat" > "%ROOT%logs\21_android_build.log" 2>&1"
if errorlevel 1 (echo BUILD FAILED - tell Claude. & pause & exit /b 1)
echo [2/4] Installing on the Retroid...
"%ADB%" shell am force-stop com.uaw.recomp
"%ADB%" install -r "%ROOT%UniverseAtWar.apk" > "%ROOT%logs\22_install.log" 2>&1
if errorlevel 1 (echo INSTALL FAILED - is the Retroid plugged in? Tell Claude. & pause & exit /b 1)
echo on> "%ROOT%logs\profile_on.txt"
"%ADB%" push "%ROOT%logs\profile_on.txt" %PKGDIR%/profile_on >nul 2>&1
"%ADB%" shell rm -f %PKGDIR%/uaw.log %PKGDIR%/args.txt
REM Extra test settings for this run (scripts\android_test_args.txt), if present.
if exist "%ROOT%scripts\android_test_args.txt" "%ADB%" push "%ROOT%scripts\android_test_args.txt" %PKGDIR%/args.txt >nul 2>&1
"%ADB%" shell rm -f %PKGDIR%/env.txt
if exist "%ROOT%scripts\android_test_env.txt" "%ADB%" push "%ROOT%scripts\android_test_env.txt" %PKGDIR%/env.txt >nul 2>&1
"%ADB%" logcat -c
echo [3/4] Starting the game on the Retroid. Play a skirmish for 3-4 minutes.
REM Record GPU load, GPU clock, CPU clocks and GPU temperature once per second (6 minutes).
"%ADB%" push "%ROOT%scripts\android_monitor.sh" /data/local/tmp/uaw_mon.sh >nul 2>&1
start "Retroid monitor (closes by itself)" /min cmd /c ""%ADB%" shell sh /data/local/tmp/uaw_mon.sh > "%ROOT%logs\android_gpu_cpu.txt" 2>&1 < nul"
"%ADB%" shell am start -n com.uaw.recomp/.UawActivity >nul
echo.
echo     When you're done playing, come back here and press any key.
pause >nul
echo [4/4] Copying logs...
"%ADB%" shell pkill -f uaw_mon.sh >nul 2>&1
"%ADB%" pull %PKGDIR%/uaw.log "%ROOT%logs\android_uaw.log" > "%ROOT%logs\23_logs.log" 2>&1
"%ADB%" logcat -d -v threadtime > "%ROOT%logs\android_logcat.txt" 2>&1
"%ADB%" shell rm -f %PKGDIR%/profile_on %PKGDIR%/args.txt %PKGDIR%/env.txt
echo Done. Tell Claude. You can close this window.
pause
