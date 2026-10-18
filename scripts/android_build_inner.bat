@echo on
REM Android build: SDK (arm64) -> game libmain.so -> APK. Called by 21_build_android.bat
set "ROOT=%~dp0..\"
set PATH=C:\Program Files\CMake\bin;C:\Program Files\Git\cmd;%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%
set "AT=%ROOT%android-tools"
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
set "PROJ=%ROOT%project"
set "GBUILD=%PROJ%\out\build\android-arm64"
set "APKW=%ROOT%out\android"
set "TC=-DCMAKE_TOOLCHAIN_FILE=%NDK%\build\cmake\android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-31 -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release"
set "ARCHFLAGS=-march=armv8.2-a+fp16+dotprod+rcpc"

if not exist "%NDK%\build\cmake\android.toolchain.cmake" (echo ==== NDK MISSING & goto :fail)

echo ==== PYTHON
set "PYEXE="
for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python3*") do if exist "%%D\python.exe" set "PYEXE=%%D\python.exe"
if "%PYEXE%"=="" winget install -e --id Python.Python.3.12 --scope user --accept-package-agreements --accept-source-agreements --disable-interactivity
for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python3*") do if exist "%%D\python.exe" set "PYEXE=%%D\python.exe"
if "%PYEXE%"=="" (echo ==== PYTHON MISSING & goto :fail)
echo PYEXE=%PYEXE%
echo ==== SDK PATCH
cd /d "%SDKSRC%"
git apply --reverse --check "%ROOT%patches\0002-android-port.patch" 2>nul
if errorlevel 1 (
  git apply "%ROOT%patches\0002-android-port.patch"
  if errorlevel 1 goto :fail
)

echo ==== SDK CONFIGURE
cmake -S "%SDKSRC%" -B "%SDKBUILD%" -G Ninja %TC% "-DCMAKE_C_FLAGS=%ARCHFLAGS%" "-DCMAKE_CXX_FLAGS=%ARCHFLAGS%" "-DCMAKE_INSTALL_PREFIX=%SDKINST%" -DREXGLUE_USE_VULKAN=ON -DREXGLUE_USE_D3D12=OFF -DREXGLUE_ENABLE_TRACY=OFF "-DPYTHON_EXECUTABLE=%PYEXE%" "-DPython3_EXECUTABLE=%PYEXE%"
if errorlevel 1 goto :fail
echo ==== SDK BUILD
cmake --build "%SDKBUILD%" --parallel 6
if errorlevel 1 goto :fail
cmake --install "%SDKBUILD%"
if errorlevel 1 goto :fail

echo ==== GAME CONFIGURE
if not exist "%PROJ%\assets" mkdir "%PROJ%\assets"
if not exist "%PROJ%\assets\default.xex" copy /y "%ROOT%files\default.xex" "%PROJ%\assets\default.xex"
copy /y "%ROOT%files\uaw_manifest.toml" "%PROJ%\uaw_manifest.toml"
cmake -S "%PROJ%" -B "%GBUILD%" -G Ninja %TC% "-DCMAKE_C_FLAGS=%ARCHFLAGS%" "-DCMAKE_CXX_FLAGS=%ARCHFLAGS%" "-DCMAKE_PREFIX_PATH=%SDKINST%" -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH "-Drexglue_DIR=%SDKINST%\lib\cmake\rexglue" "-DUAW_HOST_REXGLUE=%HOSTREX%"
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
"%BT%\aapt2.exe" link -o "%APKW%\base.apk" -I "%PLAT%" --manifest "%ROOT%android\AndroidManifest.xml" --min-sdk-version 31 --target-sdk-version 35
if errorlevel 1 goto :fail
copy /y "%GBUILD%\libmain.so" "%APKW%\apk\lib\arm64-v8a\" || goto :fail
copy /y "%SDKINST%\lib\librexruntime.so" "%APKW%\apk\lib\arm64-v8a\" || goto :fail
copy /y "%SDKINST%\lib\librexgpu-xenos.so" "%APKW%\apk\lib\arm64-v8a\" || goto :fail
copy /y "%NDK%\toolchains\llvm\prebuilt\windows-x86_64\sysroot\usr\lib\aarch64-linux-android\libc++_shared.so" "%APKW%\apk\lib\arm64-v8a\" || goto :fail
copy /y "%APKW%\dex\classes.dex" "%APKW%\apk\" || goto :fail
copy /y "%APKW%\base.apk" "%APKW%\unaligned.apk" || goto :fail
cd /d "%APKW%"
REM Merge dex + libs into the aapt2 base apk using Java's jar tool (keeps zip valid)
jar -uf unaligned.apk -C apk classes.dex -C apk lib
if errorlevel 1 goto :fail
"%BT%\zipalign.exe" -f -p 4 unaligned.apk aligned.apk
if errorlevel 1 goto :fail
if not exist "%AT%\debug.keystore" keytool -genkeypair -keystore "%AT%\debug.keystore" -storepass android -keypass android -alias uaw -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=UAW Recomp"
java -jar "%BT%\lib\apksigner.jar" sign --ks "%AT%\debug.keystore" --ks-pass pass:android --key-pass pass:android --out "%ROOT%UniverseAtWar.apk" aligned.apk
if errorlevel 1 goto :fail
echo ==== SUCCESS
exit /b 0
:fail
echo ==== FAILED
exit /b 1
