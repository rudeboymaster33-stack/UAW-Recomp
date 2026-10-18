@echo off
REM Android step 3: install the app on the phone over USB, copy the game files (first time only), start it.
REM Needs: phone plugged in with USB debugging on (accept the "Allow USB debugging?" prompt on the phone).
set "ROOT=%~dp0"
set "ADB=%ROOT%android-tools\sdk\platform-tools\adb.exe"
set "GAME=C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)"
set "PKGDIR=/sdcard/Android/data/com.uaw.recomp/files"
set "LOG=%ROOT%logs\22_install.log"
echo ==== %DATE% %TIME% > "%LOG%"
"%ADB%" start-server >> "%LOG%" 2>&1
"%ADB%" devices -l >> "%LOG%" 2>&1
"%ADB%" get-state 2>nul | findstr device >nul
if errorlevel 1 (
  echo.
  echo Phone not found. Check: USB cable plugged in, USB debugging on,
  echo and tap "Allow" on the phone's "Allow USB debugging?" prompt. Then run this again.
  echo NO DEVICE >> "%LOG%"
  pause & exit /b 1
)
echo Installing the app...
"%ADB%" install -r "%ROOT%UniverseAtWar.apk" >> "%LOG%" 2>&1
if errorlevel 1 (echo Install failed - Claude will read the log. & pause & exit /b 1)
REM Android only lets the app itself create its folder, so start it once and close it.
"%ADB%" shell am start -n com.uaw.recomp/.UawActivity >> "%LOG%" 2>&1
timeout /t 6 /nobreak >nul
"%ADB%" shell am force-stop com.uaw.recomp >> "%LOG%" 2>&1
"%ADB%" shell ls -la %PKGDIR% >> "%LOG%" 2>&1
"%ADB%" shell ls %PKGDIR%/game/default.xex >nul 2>&1
if errorlevel 1 (
  echo Copying the game files to the phone - about 6 GB, this takes several minutes...
  REM Stream the files through tar: adb push cannot create folders inside Android/data on newer Android.
  pushd "%GAME%"
  tar -cf - Data default.xex | "%ADB%" exec-in tar -xf - -C %PKGDIR%/game >> "%LOG%" 2>&1
  popd
  "%ADB%" shell ls %PKGDIR%/game/default.xex >nul 2>&1
  if errorlevel 1 (echo Copy failed - Claude will read the log. & pause & exit /b 1)
  "%ADB%" shell du -sh %PKGDIR%/game >> "%LOG%" 2>&1
) else (
  echo Game files already on the phone.
)
"%ADB%" pull %PKGDIR%/uaw.log "%ROOT%logs\android_uaw_firstrun.log" >> "%LOG%" 2>&1
"%ADB%" shell rm -f %PKGDIR%/uaw.log >> "%LOG%" 2>&1
"%ADB%" logcat -c >> "%LOG%" 2>&1
echo Starting the game on the phone...
"%ADB%" shell am start -n com.uaw.recomp/.UawActivity >> "%LOG%" 2>&1
echo ==== DONE >> "%LOG%"
echo.
echo The game should now be opening on your phone.
echo When you're done (or if it closes/crashes), run 23_get_phone_logs so Claude can read what happened.
pause
