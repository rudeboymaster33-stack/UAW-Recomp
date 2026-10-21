@echo off
REM Upload this port into the shared GitHub collection (Xbox360-Recomp-Ports).
REM The collection folder sits next to this project folder in Documents.
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
for %%I in ("%ROOT%..\Xbox360-Recomp-Ports") do set "COLL=%%~fI"
set "SUB=Halo3"
set PATH=C:\Program Files\Git\cmd;%PATH%
if not exist "%COLL%\.git" (
  echo.
  echo ==== The collection folder %COLL% is missing - ask Claude.
  pause
  exit /b 1
)
cd /d "%COLL%"
git fetch -q "%ROOT%." main
if errorlevel 1 goto failed
if not exist "%COLL%\%SUB%\" (
  git merge -q -s ours --no-commit --allow-unrelated-histories FETCH_HEAD
  git read-tree --prefix=%SUB%/ -u FETCH_HEAD
  git commit -q -m "Add the %SUB% port"
) else (
  git merge -q -X subtree=%SUB% --no-edit -m "%SUB%: latest progress" FETCH_HEAD
)
if errorlevel 1 goto failed
echo.
echo Uploading... (if asked, sign in to GitHub in the browser window)
git push -u origin main
if errorlevel 1 goto failed
echo.
echo ==== UPLOAD DONE
pause
exit /b 0
:failed
echo.
echo ==== UPLOAD FAILED - see the message above.
pause
exit /b 1
