@echo on
REM Bring rexglue-sdk\ to: upstream + every patch in the list below (each applied once).
REM Called with the SDK folder as current directory.
REM Finds the newest patch that is already applied (checking newest first, because
REM later patches change lines that earlier ones touched), then applies the rest in order.
set "PATCHES=%~dp0..\patches"
REM Undo the timer-queue experiment (made frame pacing worse on the Retroid).
git apply --reverse --check "%PATCHES%\old\0004-android-timer-queue-no-spin.patch" 2>nul
if not errorlevel 1 git apply --reverse "%PATCHES%\old\0004-android-timer-queue-no-spin.patch"
REM Replace the first version of the GPU stats patch if it is applied.
git apply --reverse --check "%PATCHES%\old\0007-vulkan-gpu-frame-stats-v1.patch" 2>nul
if not errorlevel 1 git apply --reverse "%PATCHES%\old\0007-vulkan-gpu-frame-stats-v1.patch"

set "LIST=0001-xam-report-type-of-unset-profile-settings 0002-android-port 0003-vulkan-storage-rewind 0005-arm64-memory-barriers 0006-posix-less-spinning 0007-vulkan-gpu-frame-stats 0008-vulkan-tight-render-area 0009-vulkan-gpu-timestamps 0010-vulkan-gpu-time-pass-detail 0011-thread-name-race 0012-skip-faked-query-draws 0013-gpu-pass-trace 0014-hoist-shm-uploads 0015-msaa-experiment 0016-force-msaa-1x 0017-force-msaa-1x-pitch 0018-quiet-resolve-warning 0019-swap-hints 0020-display-timing-pacing 0021-android-resume-surface"
set "REVLIST=0021-android-resume-surface 0020-display-timing-pacing 0019-swap-hints 0018-quiet-resolve-warning 0017-force-msaa-1x-pitch 0016-force-msaa-1x 0015-msaa-experiment 0014-hoist-shm-uploads 0013-gpu-pass-trace 0012-skip-faked-query-draws 0011-thread-name-race 0010-vulkan-gpu-time-pass-detail 0009-vulkan-gpu-timestamps 0008-vulkan-tight-render-area 0007-vulkan-gpu-frame-stats 0006-posix-less-spinning 0005-arm64-memory-barriers 0003-vulkan-storage-rewind 0002-android-port 0001-xam-report-type-of-unset-profile-settings"

set "NEWEST_APPLIED="
for %%P in (%REVLIST%) do (
  if not defined NEWEST_APPLIED (
    git apply --reverse --check "%PATCHES%\%%P.patch" 2>nul
    if not errorlevel 1 set "NEWEST_APPLIED=%%P"
  )
)
echo Newest SDK patch already applied: %NEWEST_APPLIED%

set "APPLY_NOW="
if not defined NEWEST_APPLIED set "APPLY_NOW=1"
for %%P in (%LIST%) do (
  if defined APPLY_NOW (
    git apply "%PATCHES%\%%P.patch"
    if errorlevel 1 (echo PATCH FAILED: %%P & exit /b 1)
  )
  if "%%P"=="%NEWEST_APPLIED%" set "APPLY_NOW=1"
)
exit /b 0
