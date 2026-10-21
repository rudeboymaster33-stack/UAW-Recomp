@echo off
REM adb (from this project's Android tools, or the Universe at War project's) and the app's folder on the Retroid.
set "ADB=%ROOT%android-tools\sdk\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=%ROOT%..\UAW-Recomp\android-tools\sdk\platform-tools\adb.exe"
set "PKG=com.halo3.recomp"
set "PKGDIR=/sdcard/Android/data/com.halo3.recomp/files"
