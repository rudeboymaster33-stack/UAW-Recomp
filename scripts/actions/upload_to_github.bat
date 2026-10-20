@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
REM Upload the saved project history to your GitHub repository.
REM Game files, generated code, builds and logs are never uploaded (.gitignore).
set PATH=C:\Program Files\Git\cmd;%PATH%
cd /d "%ROOT%"
git remote get-url origin >nul 2>&1
if errorlevel 1 (
  echo.
  echo Paste the address of your new GitHub repository, for example:
  echo   https://github.com/YourName/UAW-Recomp.git
  echo.
  set /p REPO_URL=Repository address: 
  call git remote add origin "%%REPO_URL%%"
)
echo.
echo Uploading... (the first time, a GitHub sign-in window opens in your browser)
git push -u origin main
if errorlevel 1 (
  echo.
  echo ==== UPLOAD FAILED - see the message above.
) else (
  echo.
  echo ==== UPLOAD DONE
)
pause
