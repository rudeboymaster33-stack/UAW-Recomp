@echo off
title Universe at War recomp
:menu
cls
echo.
echo   =============================================
echo    Universe at War recomp  -  Start here
echo   =============================================
echo.
echo    PLAY
echo     1  Play on PC
echo     2  Retroid: build, install and start the game
echo.
echo    TESTING (for Claude)
echo     3  Retroid: test run - build, play, collect logs
echo     4  Retroid: get logs only
echo.
echo    SAVE
echo     5  Save progress and upload to GitHub
echo.
echo    FIRST-TIME SETUP
echo     6  Install Android build tools
echo.
echo     0  Exit
echo.
set "CHOICE="
set /p CHOICE=  Type a number and press Enter: 
set "A=%~dp0scripts\actions"
if "%CHOICE%"=="1" call "%A%\pc_play.bat"
if "%CHOICE%"=="2" call :retroid_play
if "%CHOICE%"=="3" call "%A%\android_test_run.bat"
if "%CHOICE%"=="4" call "%A%\android_get_logs.bat"
if "%CHOICE%"=="5" call :save_upload
if "%CHOICE%"=="6" call "%A%\android_install_tools.bat"
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
