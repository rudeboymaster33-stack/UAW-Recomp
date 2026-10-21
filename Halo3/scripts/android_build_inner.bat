@echo on
REM Retroid build: SDK (arm64, only when its patches change) -> recompile Halo 3 -> libmain.so -> Halo3.apk
set "ROOT=%~dp0..\"
set PATH=C:\Program Files\CMake\bin;C:\Program Files\Git\cmd;%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%
REM Android build tools: this project's own copy if there is one, otherwise the ones
REM already installed for the Universe at War project (same tools, saves several GB).
set "AT=%ROOT%android-tools"
if not exist "%AT%\sdk\ndk" set "AT=%ROOT%..\UAW-Recomp\android-tools"
set "ASDK=%AT%\sdk"
set "NDK=%ASDK%\ndk\27.2.12479018"
set "BT=%ASDK%\build-tools\35.0.0"
set "PLAT=%ASDK%\platforms\android-35\android.jar"
for /d %%D in ("C:\Program Files\Microsoft\jdk-17*") do set "JAVA_HOME=%%D"
set "PATH=%JAVA_HOME%\bin;%PATH%"
set "SDKSRC=%ROOT%rexglue-sdk"
set "SDKBUILD=%SDKSRC%\out\build\android-arm64"
set "SDKINST=%SDKSRC%\out\install\android-arm64"
set "HOSTREX=%SDKSRC%\out\install\win-amd64\bin\rexglue.exe"
set "STAMP=%SDKSRC%\out\patches_built.txt"
set "PROJ=%ROOT%project"
set "GBUILD=%PROJ%\out\build\android-arm64"
set "APKW=%ROOT%out\android"
set "TC=-DCMAKE_TOOLCHAIN_FILE=%NDK%\build\cmake\android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-31 -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release"
set "ARCHFLAGS=-march=armv8.2-a+fp16+dotprod+rcpc"
call "%ROOT%scripts\paths.bat"

if not exist "%NDK%\build\cmake\android.toolchain.cmake" (echo ==== NDK MISSING - Android build tools not found & goto :fail)

echo ==== SDK COPY
REM First time: this project's own copy of the SDK, taken from the Universe at War
REM project (same version and patches), including its already-built tools and
REM Android libraries, so nothing has to be built for PC.
if exist "%SDKSRC%\CMakeLists.txt" goto :havesdk
for %%I in ("%ROOT%..\UAW-Recomp\rexglue-sdk") do set "UAWSDK=%%~fI"
if not exist "%UAWSDK%\CMakeLists.txt" (echo ==== UAW SDK NOT FOUND: %UAWSDK% & goto :fail)
robocopy "%UAWSDK%" "%SDKSRC%" /E /XD "%UAWSDK%\out\build" /NFL /NDL /NP
if errorlevel 8 goto :fail
dir /b "%UAWSDK%\..\patches\*.patch" > "%STAMP%"
:havesdk
if not exist "%HOSTREX%" (echo ==== HOST REXGLUE MISSING: %HOSTREX% & goto :fail)

echo ==== PYTHON
set "PYEXE="
for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python3*") do if exist "%%D\python.exe" set "PYEXE=%%D\python.exe"
if "%PYEXE%"=="" (echo ==== PYTHON MISSING & goto :fail)
echo PYEXE=%PYEXE%

echo ==== SDK PATCH
cd /d "%SDKSRC%"
call "%ROOT%scripts\apply_sdk_patches.bat"
if errorlevel 1 goto :fail
REM Rebuild the Android SDK libraries only when the patch set changed.
dir /b "%ROOT%patches\*.patch" > "%SDKSRC%\out\patches_now.txt"
if not exist "%SDKINST%\lib\librexruntime.so" goto :sdkbuild
if not exist "%STAMP%" goto :sdkbuild
fc /b "%STAMP%" "%SDKSRC%\out\patches_now.txt" >nul
if errorlevel 1 goto :sdkbuild
echo SDK libraries up to date.
goto :game
:sdkbuild
echo ==== SDK CONFIGURE
cmake -S "%SDKSRC%" -B "%SDKBUILD%" -G Ninja %TC% "-DCMAKE_C_FLAGS=%ARCHFLAGS%" "-DCMAKE_CXX_FLAGS=%ARCHFLAGS%" "-DCMAKE_INSTALL_PREFIX=%SDKINST%" -DREXGLUE_USE_VULKAN=ON -DREXGLUE_USE_D3D12=OFF -DREXGLUE_ENABLE_TRACY=OFF "-DPYTHON_EXECUTABLE=%PYEXE%" "-DPython3_EXECUTABLE=%PYEXE%"
if errorlevel 1 goto :fail
echo ==== SDK BUILD
cmake --build "%SDKBUILD%" --parallel 6
if errorlevel 1 goto :fail
cmake --install "%SDKBUILD%"
if errorlevel 1 goto :fail
copy /y "%SDKSRC%\out\patches_now.txt" "%STAMP%"

:game
echo ==== GAME CONFIGURE
if not exist "%PROJ%\assets" mkdir "%PROJ%\assets"
if not exist "%PROJ%\assets\default.xex" copy /y "%ROOT%files\default.xex" "%PROJ%\assets\default.xex"
if not exist "%PROJ%\assets\default.xex" (echo ==== default.xex MISSING & goto :fail)
REM Halo 3 also loads two audio DLLs (Waves); they are recompiled as extra modules.
if not exist "%PROJ%\assets\waveshell-xbox.dll" copy /y "%GAME%\WaveShell-Xbox.dll" "%PROJ%\assets\waveshell-xbox.dll"
if not exist "%PROJ%\assets\waveslibdll.dll" copy /y "%GAME%\WavesLibDLL.dll" "%PROJ%\assets\waveslibdll.dll"
if not exist "%PROJ%\assets\waves" mkdir "%PROJ%\assets\waves"
if not exist "%PROJ%\assets\waves\l360.dll" copy /y "%GAME%\waves\L360.dll" "%PROJ%\assets\waves\l360.dll"
if not exist "%PROJ%\assets\waves\q10.dll" copy /y "%GAME%\waves\Q10.dll" "%PROJ%\assets\waves\q10.dll"
if not exist "%PROJ%\assets\waveslibdll.dll" (echo ==== GAME DLLs MISSING - run menu option 1 first & goto :fail)
if not exist "%PROJ%\assets\waves\q10.dll" (echo ==== GAME DLLs MISSING - run menu option 1 first & goto :fail)
copy /y "%ROOT%files\halo3_manifest.toml" "%PROJ%\halo3_manifest.toml"
cd /d "%PROJ%"
"%HOSTREX%" codegen halo3_manifest.toml
if errorlevel 1 goto :fail
cmake -S "%PROJ%" -B "%GBUILD%" -G Ninja %TC% "-DCMAKE_C_FLAGS=%ARCHFLAGS%" "-DCMAKE_CXX_FLAGS=%ARCHFLAGS%" "-DCMAKE_PREFIX_PATH=%SDKINST%" -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH "-Drexglue_DIR=%SDKINST%\lib\cmake\rexglue" "-DHALO3_HOST_REXGLUE=%HOSTREX%"
if errorlevel 1 goto :fail
echo ==== GAME BUILD
cmake --build "%GBUILD%" --parallel 6
if errorlevel 1 goto :fail

echo ==== APK
if exist "%APKW%" rmdir /s /q "%APKW%"
mkdir "%APKW%\classes" "%APKW%\dex" "%APKW%\apk\lib\arm64-v8a"
set "SDLJAVA=%SDKSRC%\thirdparty\sdl3\android-project\app\src\main\java"
dir /s /b "%SDLJAVA%\*.java" "%ROOT%android\java\*.java" > "%APKW%\sources.txt"
javac -source 8 -target 8 -nowarn -encoding UTF-8 -classpath "%PLAT%" -d "%APKW%\classes" @"%APKW%\sources.txt"
if errorlevel 1 goto :fail
jar cf "%APKW%\classes.jar" -C "%APKW%\classes" .
if errorlevel 1 goto :fail
java -cp "%BT%\lib\d8.jar" com.android.tools.r8.D8 --release --min-api 31 --lib "%PLAT%" --output "%APKW%\dex" "%APKW%\classes.jar"
if errorlevel 1 goto :fail
"%BT%\aapt2.exe" compile --dir "%ROOT%android\res" -o "%APKW%\res.zip"
if errorlevel 1 goto :fail
"%BT%\aapt2.exe" link -o "%APKW%\base.apk" -I "%PLAT%" --manifest "%ROOT%android\AndroidManifest.xml" --min-sdk-version 31 --target-sdk-version 35 "%APKW%\res.zip"
if errorlevel 1 goto :fail
copy /y "%GBUILD%\libmain.so" "%APKW%\apk\lib\arm64-v8a\" || goto :fail
REM The recompiled game DLLs (audio plugins).
for %%F in ("%GBUILD%\libhalo3_*.so") do copy /y "%%F" "%APKW%\apk\lib\arm64-v8a\"
if not exist "%APKW%\apk\lib\arm64-v8a\libhalo3_q10.so" goto :fail
copy /y "%SDKINST%\lib\librexruntime.so" "%APKW%\apk\lib\arm64-v8a\" || goto :fail
copy /y "%SDKINST%\lib\librexgpu-xenos.so" "%APKW%\apk\lib\arm64-v8a\" || goto :fail
copy /y "%NDK%\toolchains\llvm\prebuilt\windows-x86_64\sysroot\usr\lib\aarch64-linux-android\libc++_shared.so" "%APKW%\apk\lib\arm64-v8a\" || goto :fail
copy /y "%APKW%\dex\classes.dex" "%APKW%\apk\" || goto :fail
copy /y "%APKW%\base.apk" "%APKW%\unaligned.apk" || goto :fail
cd /d "%APKW%"
jar -uf unaligned.apk -C apk classes.dex -C apk lib
if errorlevel 1 goto :fail
"%BT%\zipalign.exe" -f -p 4 unaligned.apk aligned.apk
if errorlevel 1 goto :fail
if not exist "%AT%\debug.keystore" keytool -genkeypair -keystore "%AT%\debug.keystore" -storepass android -keypass android -alias uaw -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=UAW Recomp"
java -jar "%BT%\lib\apksigner.jar" sign --v4-signing-enabled false --ks "%AT%\debug.keystore" --ks-pass pass:android --key-pass pass:android --out "%ROOT%Halo3.apk" aligned.apk
if errorlevel 1 goto :fail
echo ==== SUCCESS
exit /b 0
:fail
echo ==== FAILED
exit /b 1
