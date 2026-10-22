@echo off
REM Takes a Retroid screenshot every 5 seconds (up to 40) into logs\shots\ while a test runs.
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
call "%ROOT%scripts\android_paths.bat"
if not exist "%ROOT%logs\shots" mkdir "%ROOT%logs\shots"
del /q "%ROOT%logs\shots\*.png" >nul 2>&1
set N=10
:loop
if exist "%ROOT%logs\shots_stop.txt" goto end
timeout /t 5 /nobreak >nul
"%ADB%" exec-out screencap -p > "%ROOT%logs\shots\shot_%N%.png"
set /a N+=1
if %N% LSS 50 goto loop
:end
