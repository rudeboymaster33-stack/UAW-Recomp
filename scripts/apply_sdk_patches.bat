@echo on
REM Bring rexglue-sdk\ to: upstream + every patch in the list below (each applied once).
REM Called with the SDK folder as current directory.
set "PATCHES=%~dp0..\patches"
REM Undo the timer-queue experiment (made frame pacing worse on the Retroid).
git apply --reverse --check "%PATCHES%\old\0004-android-timer-queue-no-spin.patch" 2>nul
if not errorlevel 1 git apply --reverse "%PATCHES%\old\0004-android-timer-queue-no-spin.patch"
for %%P in (0001-xam-report-type-of-unset-profile-settings 0002-android-port 0003-vulkan-storage-rewind 0005-arm64-memory-barriers 0006-posix-less-spinning) do (
  git apply --reverse --check "%PATCHES%\%%P.patch" 2>nul
  if errorlevel 1 (
    git apply "%PATCHES%\%%P.patch"
    if errorlevel 1 (echo PATCH FAILED: %%P & exit /b 1)
  )
)
exit /b 0
