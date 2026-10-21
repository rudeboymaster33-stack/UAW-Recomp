@echo off
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI\"
REM Android step 1: install Java 17, Android SDK command-line tools, platform, build-tools and NDK.
REM You will be asked to accept the Android SDK licenses - read them and type y to accept.

set "AT=%ROOT%android-tools"
set "LOG=%ROOT%logs\20_android_tools.log"
if not exist "%AT%" mkdir "%AT%"
echo ==== start %DATE% %TIME% > "%LOG%"
echo Installing Java 17 (may take a minute)...
winget install -e --id Microsoft.OpenJDK.17 --accept-package-agreements --accept-source-agreements --disable-interactivity >> "%LOG%" 2>&1
set "JAVA_HOME="
for /d %%D in ("C:\Program Files\Microsoft\jdk-17*") do set "JAVA_HOME=%%D"
if "%JAVA_HOME%"=="" (echo JAVA NOT FOUND >> "%LOG%" & echo Java install failed - Claude will read the log. & pause & exit /b 1)
echo JAVA_HOME=%JAVA_HOME% >> "%LOG%"
set "PATH=%JAVA_HOME%\bin;%PATH%"
if exist "%AT%\sdk\cmdline-tools\latest\bin\sdkmanager.bat" goto :haveclt
echo Downloading Android command-line tools...
curl.exe -L -o "%AT%\clt.zip" https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip >> "%LOG%" 2>&1
mkdir "%AT%\sdk\cmdline-tools" 2>nul
tar -xf "%AT%\clt.zip" -C "%AT%\sdk\cmdline-tools" >> "%LOG%" 2>&1
move "%AT%\sdk\cmdline-tools\cmdline-tools" "%AT%\sdk\cmdline-tools\latest" >> "%LOG%" 2>&1
:haveclt
set "SDKM=%AT%\sdk\cmdline-tools\latest\bin\sdkmanager.bat"
if not exist "%SDKM%" (echo SDKMANAGER MISSING >> "%LOG%" & echo Download failed - Claude will read the log. & pause & exit /b 1)
echo.
echo ================================================================
echo  Android SDK licenses: read each one and type y then Enter to accept.
echo ================================================================
call "%SDKM%" --sdk_root="%AT%\sdk" --licenses
echo Installing Android platform, build-tools and NDK (a few GB, takes a while)...
call "%SDKM%" --sdk_root="%AT%\sdk" "platform-tools" "platforms;android-35" "build-tools;35.0.0" "ndk;27.2.12479018" >> "%LOG%" 2>&1
echo Downloading Linux NDK copy for Claude's cloud compile checks...
if not exist "%AT%\ndk-linux.zip" curl.exe -L -o "%AT%\ndk-linux.zip" https://dl.google.com/android/repository/android-ndk-r27c-linux.zip >> "%LOG%" 2>&1
dir /s /b "%AT%\sdk\ndk" | findstr /i "ndk-build.cmd" >> "%LOG%" 2>&1
dir "%AT%" >> "%LOG%" 2>&1
echo ==== DONE %DATE% %TIME% >> "%LOG%"
echo.
echo Android tools step finished. Tell Claude. You can close this window.
pause
