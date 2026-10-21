@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
REM Create the git repo (first run) and commit everything that isn't ignored.
set PATH=C:\Program Files\Git\cmd;%PATH%
cd /d "%ROOT%"
set LOG=%ROOT%logs\11_git.log
if not exist .git (
  git init -b main > "%LOG%" 2>&1
  git config user.name "Kylie" >> "%LOG%" 2>&1
  git config user.email "rudeboymaster33@gmail.com" >> "%LOG%" 2>&1
  git config core.autocrlf false >> "%LOG%" 2>&1
) else (
  echo existing repo > "%LOG%"
)
git add -A >> "%LOG%" 2>&1
git status --short >> "%LOG%" 2>&1
if exist "%ROOT%scripts\commit_msg.txt" (
  git commit -F "%ROOT%scripts\commit_msg.txt" >> "%LOG%" 2>&1
  del "%ROOT%scripts\commit_msg.txt"
) else (
  git commit -m "Update %DATE% %TIME%" >> "%LOG%" 2>&1
)
git log --oneline -5 >> "%LOG%" 2>&1
echo ==== DONE >> "%LOG%"
