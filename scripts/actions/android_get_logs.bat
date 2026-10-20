@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
REM Android step 4: copy the game log and Android system log from the phone for Claude.

set "ADB=%ROOT%android-tools\sdk\platform-tools\adb.exe"
set "PKGDIR=/sdcard/Android/data/com.uaw.recomp/files"
"%ADB%" pull %PKGDIR%/uaw.log "%ROOT%logs\android_uaw.log" > "%ROOT%logs\23_logs.log" 2>&1
"%ADB%" logcat -d -v threadtime > "%ROOT%logs\android_logcat.txt" 2>&1
"%ADB%" shell getprop ro.product.model >> "%ROOT%logs\23_logs.log" 2>&1
"%ADB%" shell getprop ro.build.version.release >> "%ROOT%logs\23_logs.log" 2>&1
echo Logs saved. Tell Claude. You can close this window.
pause
