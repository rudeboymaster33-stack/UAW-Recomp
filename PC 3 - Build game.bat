@echo off
echo Recompiling and building Universe at War... progress goes to logs\03_game.log
echo This can take a few hours. Leave this window open.
cmd /c ""%~dp0scripts\game_inner.bat" > "%~dp0logs\03_game.log" 2>&1"
echo Finished. Claude will read the log. You can close this window.
pause
