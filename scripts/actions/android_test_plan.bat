@echo off
REM TEST PLAN: runs the game once for every file in scripts\test_plan\*.txt, with no input needed.
REM Each file holds the extra settings for that run (one per line, like android_test_args.txt).
REM An optional line "#wait=NN" sets how many seconds that run lasts (default 90).
REM Results per run: logs\plan\<name>_mid.png, <name>.png (end), <name>.log, <name>_logcat.txt
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
call "%ROOT%scripts\android_paths.bat"
set "PLAN=%ROOT%scripts\test_plan"
set "OUT=%ROOT%logs\plan"
if not exist "%OUT%" mkdir "%OUT%"
del /q "%OUT%\*" >nul 2>&1
set COUNT=0
for %%F in ("%PLAN%\*.txt") do set /a COUNT+=1
set N=0
for %%F in ("%PLAN%\*.txt") do call :one "%%~fF" "%%~nF"
echo all %COUNT% runs finished> "%OUT%\done.txt"
echo.
echo ==== ALL %COUNT% TEST RUNS DONE. Tell Claude.
exit /b 0

:one
set /a N+=1
set "WAITS=90"
for /f "usebackq tokens=2 delims==" %%W in (`findstr /b /c:"#wait=" "%~1"`) do set "WAITS=%%W"
set /a HALF=WAITS/2
echo [%TIME%] Run %N% of %COUNT%: %~2 (%WAITS% s)
"%ADB%" shell am force-stop %PKG%
"%ADB%" shell rm -rf %PKGDIR%/halo3.log %PKGDIR%/args.txt %PKGDIR%/env.txt %PKGDIR%/dump
"%ADB%" push "%~1" %PKGDIR%/args.txt >nul 2>&1
if exist "%ROOT%scripts\android_test_env.txt" "%ADB%" push "%ROOT%scripts\android_test_env.txt" %PKGDIR%/env.txt >nul 2>&1
"%ADB%" logcat -c
"%ADB%" shell am start -n %PKG%/.Halo3Activity >nul
timeout /t %HALF% /nobreak >nul
"%ADB%" exec-out screencap -p > "%OUT%\%~2_mid.png"
timeout /t %HALF% /nobreak >nul
"%ADB%" exec-out screencap -p > "%OUT%\%~2.png"
"%ADB%" shell pidof %PKG% > "%OUT%\%~2_alive.txt" 2>&1
"%ADB%" shell am force-stop %PKG%
"%ADB%" pull %PKGDIR%/halo3.log "%OUT%\%~2.log" >nul 2>&1
"%ADB%" logcat -d -v threadtime > "%OUT%\%~2_logcat.txt" 2>&1
"%ADB%" shell ls %PKGDIR%/dump >nul 2>&1 && (
  mkdir "%OUT%\%~2_dump" >nul 2>&1
  "%ADB%" pull %PKGDIR%/dump "%OUT%\%~2_dump" >nul 2>&1
)
exit /b 0
