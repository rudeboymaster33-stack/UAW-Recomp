@echo on
set ROOT=%~dp0..\
set PATH=C:\Program Files\LLVM\bin;C:\Program Files\CMake\bin;C:\Program Files\Git\cmd;%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%
set "VSDIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat"
set "PATH=C:\Program Files\LLVM\bin;%PATH%"
set "SDK=%ROOT%rexglue-sdk\out\install\win-amd64"
set "REX=%SDK%\bin\rexglue.exe"
set "PROJ=%ROOT%project"
if not exist "%PROJ%\assets" mkdir "%PROJ%\assets"
copy /y "%ROOT%files\default.xex" "%PROJ%\assets\default.xex"
cd /d "%PROJ%"
if exist "%PROJ%\CMakeLists.txt" goto :manifest
"%REX%" init --project-name uaw --xex-path assets/default.xex --project-root "%PROJ%"
if errorlevel 1 goto :fail
:manifest
copy /y "%ROOT%files\uaw_manifest.toml" "%PROJ%\uaw_manifest.toml"
echo ==== CODEGEN
"%REX%" codegen uaw_manifest.toml
if errorlevel 1 goto :fail
echo ==== CODEGEN OK
echo ==== CONFIGURE
cmake --preset win-amd64-release -DREXSDK="%SDK%"
if errorlevel 1 goto :fail
echo ==== BUILD
cmake --build --preset win-amd64-release --parallel 4
if errorlevel 1 goto :fail
echo ==== SUCCESS
exit /b 0
:fail
echo ==== FAILED
exit /b 1
