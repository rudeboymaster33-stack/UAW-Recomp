@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
REM Install the app on the Retroid over USB, copy the game files (first time only), start it.
call "%ROOT%scripts\paths.bat"
call "%ROOT%scripts\android_paths.bat"
set "LOG=%ROOT%logs\22_install.log"
echo ==== %DATE% %TIME% > "%LOG%"
"%ADB%" start-server >> "%LOG%" 2>&1
"%ADB%" devices -l >> "%LOG%" 2>&1
"%ADB%" get-state 2>nul | findstr device >nul
if errorlevel 1 (
  echo.
  echo Retroid not found. Check: USB cable plugged in, USB debugging on,
  echo and tap "Allow" on the "Allow USB debugging?" prompt. Then try again.
  echo NO DEVICE >> "%LOG%"
  pause & exit /b 1
)
if not exist "%GAME%\default.xex" (echo Game files not unpacked yet - run menu option 1 first. & pause & exit /b 1)
echo Installing the app...
"%ADB%" install -r "%ROOT%Halo3.apk" >> "%LOG%" 2>&1
if errorlevel 1 (echo Install failed - tell Claude. & pause & exit /b 1)
REM Android only lets the app itself create its folder, so start it once and close it.
"%ADB%" shell am start -n %PKG%/.Halo3Activity >> "%LOG%" 2>&1
timeout /t 6 /nobreak >nul
"%ADB%" shell am force-stop %PKG% >> "%LOG%" 2>&1
"%ADB%" shell ls %PKGDIR%/game/default.xex >nul 2>&1
if errorlevel 1 (
  echo Copying the game files to the Retroid - about 6 GB, this takes several minutes...
  REM Stream through tar: adb push cannot create folders inside Android/data on newer Android.
  pushd "%GAME%"
  tar -cf - --exclude "$SystemUpdate" . | "%ADB%" exec-in tar -xf - -C %PKGDIR%/game >> "%LOG%" 2>&1
  popd
  "%ADB%" shell ls %PKGDIR%/game/default.xex >nul 2>&1
  if errorlevel 1 (echo Copy failed - tell Claude. & pause & exit /b 1)
  "%ADB%" shell du -sh %PKGDIR%/game >> "%LOG%" 2>&1
) else (
  echo Game files already on the Retroid.
)
"%ADB%" shell rm -f %PKGDIR%/halo3.log %PKGDIR%/args.txt %PKGDIR%/env.txt %PKGDIR%/profile_on >> "%LOG%" 2>&1
"%ADB%" logcat -c >> "%LOG%" 2>&1
echo Starting the game on the Retroid...
"%ADB%" shell am start -n %PKG%/.Halo3Activity >> "%LOG%" 2>&1
echo ==== DONE >> "%LOG%"
echo.
echo The game should now be opening on your Retroid.
echo When you're done (or if it closes or crashes), choose "Get Retroid logs" in the menu.
pause
