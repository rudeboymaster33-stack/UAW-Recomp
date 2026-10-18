@echo off
REM TEMPORARY TEST: start the game on the Retroid with a detailed log.
REM Open Skirmish, try to pick a faction / go to the next screen, then run "Android 4 - Get Retroid logs".
set "ROOT=%~dp0..\..\"
set "ADB=%ROOT%android-tools\sdk\platform-tools\adb.exe"
set "PKGDIR=/sdcard/Android/data/com.uaw.recomp/files"
echo --log_level=debug> "%ROOT%logs\args_debug.txt"
"%ADB%" shell am force-stop com.uaw.recomp
"%ADB%" push "%ROOT%logs\args_debug.txt" %PKGDIR%/args.txt
"%ADB%" shell rm -f %PKGDIR%/uaw.log
"%ADB%" shell am start -n com.uaw.recomp/.UawActivity
echo.
echo The game is starting on the Retroid with detailed logging.
echo Open Skirmish, try to pick a faction and go to the next screen,
echo then run "Android 4 - Get Retroid logs".
pause
