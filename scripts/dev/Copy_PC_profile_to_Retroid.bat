@echo off
REM TEMPORARY TEST: copy the PC's game profile/save settings to the Retroid (the Retroid's own
REM profile is kept as a backup), then start the game. Try the Skirmish setup again.
set "ROOT=%~dp0..\..\"
set "ADB=%ROOT%android-tools\sdk\platform-tools\adb.exe"
set "PKGDIR=/sdcard/Android/data/com.uaw.recomp/files"
set "LOG=%ROOT%logs\test_profile_copy.log"
"%ADB%" shell am force-stop com.uaw.recomp > "%LOG%" 2>&1
"%ADB%" shell ls -laR %PKGDIR%/userdata/534507F0 >> "%LOG%" 2>&1
"%ADB%" shell "rm -rf %PKGDIR%/userdata/534507F0_retroid_backup; mv %PKGDIR%/userdata/534507F0 %PKGDIR%/userdata/534507F0_retroid_backup" >> "%LOG%" 2>&1
pushd "%ROOT%userdata"
tar -cf - 534507F0 | "%ADB%" exec-in tar -xf - -C %PKGDIR%/userdata >> "%LOG%" 2>&1
popd
"%ADB%" shell ls -laR %PKGDIR%/userdata/534507F0 >> "%LOG%" 2>&1
"%ADB%" shell rm -f %PKGDIR%/args.txt %PKGDIR%/uaw.log >> "%LOG%" 2>&1
"%ADB%" shell am start -n com.uaw.recomp/.UawActivity >> "%LOG%" 2>&1
echo.
echo PC profile copied and the game is starting on the Retroid.
echo Try Skirmish again (pick a faction, go to the next screen), then tell Claude whether it worked.
pause
