@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
REM AUTOMATIC TESTING: waits for Claude to put a request in the "auto" folder, then
REM builds, installs, starts the game on the Retroid, waits, takes screenshots,
REM collects the logs and closes the game - with no input needed. Only this fixed
REM test sequence can run. Close this window to stop.
call "%ROOT%scripts\android_paths.bat"
set "AUTO=%ROOT%auto"
if not exist "%AUTO%" mkdir "%AUTO%"
if not exist "%ROOT%logs" mkdir "%ROOT%logs"
echo ready> "%AUTO%\status.txt"
title Halo 3 - automatic testing (close this window to stop)
echo.
echo   Automatic testing is ON. Claude can now run tests on the Retroid by itself.
echo   Keep the Retroid plugged in with the screen on. Close this window to stop.
echo.
:wait
if exist "%AUTO%\request.txt" goto :run
timeout /t 3 /nobreak >nul
goto :wait

:run
REM request.txt: one line "<id> <seconds to wait after start> <build 1/0>"
set "RID=" & set "RWAIT=60" & set "RBUILD=1"
for /f "usebackq tokens=1,2,3" %%a in ("%AUTO%\request.txt") do (set "RID=%%a" & set "RWAIT=%%b" & set "RBUILD=%%c")
del /q "%AUTO%\request.txt" 2>nul
echo running %RID%> "%AUTO%\status.txt"
echo [%TIME%] Test %RID%: build=%RBUILD%, wait=%RWAIT%s
del /q "%ROOT%logs\android_screen*.png" 2>nul
if "%RBUILD%"=="1" (
  echo   building...
  cmd /c ""%ROOT%scripts\android_build_inner.bat" > "%ROOT%logs\21_android_build.log" 2>&1"
  if errorlevel 1 (echo build_failed %RID%> "%AUTO%\done.txt" & echo ready> "%AUTO%\status.txt" & echo   BUILD FAILED & goto :wait)
  "%ADB%" shell am force-stop %PKG%
  "%ADB%" install -r "%ROOT%Halo3.apk" > "%ROOT%logs\22_install.log" 2>&1
  if errorlevel 1 (echo install_failed %RID%> "%AUTO%\done.txt" & echo ready> "%AUTO%\status.txt" & echo   INSTALL FAILED & goto :wait)
)
echo   starting the game...
"%ADB%" shell am force-stop %PKG%
"%ADB%" shell rm -f %PKGDIR%/halo3.log %PKGDIR%/args.txt %PKGDIR%/env.txt
set "ARGSF=%ROOT%scripts\android_test_args.txt"
if exist "%AUTO%\args.txt" set "ARGSF=%AUTO%\args.txt"
if exist "%ARGSF%" "%ADB%" push "%ARGSF%" %PKGDIR%/args.txt >nul 2>&1
if exist "%AUTO%\env.txt" "%ADB%" push "%AUTO%\env.txt" %PKGDIR%/env.txt >nul 2>&1
"%ADB%" logcat -c
"%ADB%" shell input keyevent KEYCODE_WAKEUP
"%ADB%" shell am start -n %PKG%/.Halo3Activity >nul
REM Screenshots at 1/2 and at the end of the wait.
set /a HALF=%RWAIT%/2
set /a REST=%RWAIT%-%HALF%
timeout /t %HALF% /nobreak >nul
"%ADB%" exec-out screencap -p > "%ROOT%logs\android_screen_1.png"
timeout /t %REST% /nobreak >nul
"%ADB%" exec-out screencap -p > "%ROOT%logs\android_screen.png"
echo   collecting logs...
"%ADB%" pull %PKGDIR%/halo3.log "%ROOT%logs\android_halo3.log" > "%ROOT%logs\23_logs.log" 2>&1
"%ADB%" logcat -d -v threadtime > "%ROOT%logs\android_logcat.txt" 2>&1
"%ADB%" shell pidof %PKG% > "%ROOT%logs\android_alive.txt" 2>&1
REM Diagnostic files the game wrote to its "dump" folder (e.g. shader dumps).
"%ADB%" pull %PKGDIR%/dump "%ROOT%logs" > "%ROOT%logs\24_dump_pull.log" 2>&1
"%ADB%" shell rm -rf %PKGDIR%/dump
"%ADB%" shell am force-stop %PKG%
echo ok %RID%> "%AUTO%\done.txt"
echo ready> "%AUTO%\status.txt"
echo   done.
goto :wait
