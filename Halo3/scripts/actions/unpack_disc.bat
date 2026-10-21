@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
call "%ROOT%scripts\paths.bat"
set "PY=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not exist "%PY%" set "PY=python"
echo Unpacking the Halo 3 disc image (about 6 GB, takes several minutes)...
echo   from: %GAME_ISO%
echo   to:   %GAME%
echo.
"%PY%" "%ROOT%scripts\unpack_disc.py" "%GAME_ISO%" "%GAME%"
if errorlevel 1 (echo UNPACK FAILED - tell Claude. & pause & exit /b 1)
echo.
echo Game files unpacked.
pause
