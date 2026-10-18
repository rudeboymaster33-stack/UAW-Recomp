@echo on
set ROOT=%~dp0..\
set PATH=C:\Program Files\LLVM\bin;C:\Program Files\CMake\bin;C:\Program Files\Git\cmd;%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%
set "VSDIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat"
set "PATH=C:\Program Files\LLVM\bin;%PATH%"
set "SDK=%ROOT%rexglue-sdk\out\install\win-amd64"
cd /d "%ROOT%project"
cmake --preset win-amd64-relwithdebinfo -DREXSDK="%SDK%"
if errorlevel 1 goto :fail
cmake --build --preset win-amd64-relwithdebinfo --parallel 4
if errorlevel 1 goto :fail
echo ==== SUCCESS
exit /b 0
:fail
echo ==== FAILED
exit /b 1
