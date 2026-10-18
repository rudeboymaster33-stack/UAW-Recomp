@echo off
REM Step 1: install build tools (Git, CMake, Ninja, LLVM/Clang, VS 2022 Build Tools)
set LOG=%~dp0logs\01_install.log
echo ==== start %DATE% %TIME% > "%LOG%"
where winget >> "%LOG%" 2>&1 || (echo NO_WINGET >> "%LOG%" & goto :done)
set WG=winget install -e --accept-package-agreements --accept-source-agreements --disable-interactivity
echo ---- Git >> "%LOG%"
%WG% --id Git.Git >> "%LOG%" 2>&1
echo ---- CMake >> "%LOG%"
%WG% --id Kitware.CMake >> "%LOG%" 2>&1
echo ---- Ninja >> "%LOG%"
%WG% --id Ninja-build.Ninja >> "%LOG%" 2>&1
echo ---- LLVM >> "%LOG%"
%WG% --id LLVM.LLVM >> "%LOG%" 2>&1
echo ---- VS Build Tools >> "%LOG%"
%WG% --id Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621" >> "%LOG%" 2>&1
:done
echo ==== DONE %DATE% %TIME% >> "%LOG%"
echo.
echo Step 1 finished. You can close this window.
pause
