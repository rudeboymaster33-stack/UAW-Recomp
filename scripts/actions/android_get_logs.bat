@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
REM Copy the game log and Android system log from the Retroid for Claude.
call "%ROOT%scripts\android_paths.bat"
REM Screenshot of what is on the Retroid screen right now (for Claude).
"%ADB%" exec-out screencap -p > "%ROOT%logs\android_screen.png"
"%ADB%" pull %PKGDIR%/halo3.log "%ROOT%logs\android_halo3.log" > "%ROOT%logs\23_logs.log" 2>&1
"%ADB%" logcat -d -v threadtime > "%ROOT%logs\android_logcat.txt" 2>&1
"%ADB%" shell getprop ro.product.model >> "%ROOT%logs\23_logs.log" 2>&1
REM Close the game now that the logs are saved.
"%ADB%" shell am force-stop %PKG%
echo Logs saved. Tell Claude. You can close this window.
pause
