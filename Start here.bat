@echo off
title Halo 3 recomp
:menu
@echo off
cls
echo.
echo   =============================================
echo    Halo 3 recomp (Retroid Pocket)  -  Start here
echo   =============================================
echo.
echo    FIRST TIME
echo     1  Unpack the game disc
echo.
echo    PLAY
echo     2  Retroid: build, install and start the game
echo.
echo    TESTING (for Claude)
echo     3  Retroid: test run - build, play, collect logs
echo     4  Retroid: get logs only
echo.
echo    AUTOMATIC
echo     6  Let Claude run tests automatically (leave the window open)
echo.
echo    SAVE
echo     5  Save progress and upload to GitHub
echo.
echo     0  Exit
echo.
set "CHOICE="
set /p CHOICE=  Type a number and press Enter: 
set "A=%~dp0scripts\actions"
if "%CHOICE%"=="1" call "%A%\unpack_disc.bat"
if "%CHOICE%"=="2" call :retroid_play
if "%CHOICE%"=="3" call "%A%\android_test_run.bat"
if "%CHOICE%"=="4" call "%A%\android_get_logs.bat"
if "%CHOICE%"=="5" call :save_upload
if "%CHOICE%"=="6" call "%A%\auto_test_loop.bat"
if "%CHOICE%"=="0" exit /b 0
goto menu

:retroid_play
call "%A%\android_build_app.bat"
if errorlevel 1 exit /b 1
call "%A%\android_install_and_start.bat"
exit /b 0

:save_upload
echo Saving progress...
call "%A%\save_progress.bat"
call "%A%\upload_to_github.bat"
exit /b 0
