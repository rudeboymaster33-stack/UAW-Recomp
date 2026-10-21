@echo on
set ROOT=%~dp0..\
set PATH=C:\Program Files\LLVM\bin;C:\Program Files\CMake\bin;C:\Program Files\Git\cmd;%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%
set "VSDIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat"
set "PATH=C:\Program Files\LLVM\bin;%PATH%"
where clang
where cmake
where ninja
where git
clang --version
cmake --version
git config --global core.longpaths true
cd /d "%ROOT%"
if exist "rexglue-sdk\CMakeLists.txt" goto :configure
git clone --recursive --depth 1 --shallow-submodules https://github.com/rexglue/rexglue-sdk.git rexglue-sdk
if errorlevel 1 goto :fail
:configure
cd /d "%ROOT%rexglue-sdk"
call "%ROOT%scripts\apply_sdk_patches.bat"
if errorlevel 1 goto :fail
cmake --preset win-amd64 -DREXGLUE_ENABLE_TRACY=OFF
if errorlevel 1 goto :fail
cmake --build out/build/win-amd64 --config Release --target install -j 6
if errorlevel 1 goto :fail
echo ==== SUCCESS
exit /b 0
:fail
echo ==== FAILED
exit /b 1
