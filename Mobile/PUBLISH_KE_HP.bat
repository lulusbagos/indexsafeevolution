@echo off
setlocal enabledelayedexpansion
title Indexsafe MBS Mobile - One-Click Build & Publish to Phone
color 0A

echo ========================================================
echo   INDEXSAFE / MBS MOBILE - BUILD & PUBLISH KE HP
echo ========================================================
echo.

set "FLUTTER_BAT=D:\5. INSTALASI\flutter\bin\flutter.bat"
set "ADB_EXE=D:\Android\sdk\platform-tools\adb.exe"
set "PROJECT_DIR=%~dp0"

echo [1/3] Memeriksa koneksi HP via ADB...
"%ADB_EXE%" devices
echo.

echo [2/3] Membangun APK (Bypass ManageEngine Block)...
cd /d "%PROJECT_DIR%"
call "%FLUTTER_BAT%" build apk --debug --android-skip-build-dependency-validation
if %ERRORLEVEL% neq 0 (
    color 0C
    echo [ERROR] Gagal melakukan build APK!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Memasang dan menjalankan aplikasi di HP...
"%ADB_EXE%" install -r -d "build\app\outputs\flutter-apk\app-debug.apk"
if %ERRORLEVEL% neq 0 (
    color 0C
    echo [ERROR] Gagal memasang APK ke HP! Pastikan HP terhubung dan USB Debugging aktif.
    pause
    exit /b %ERRORLEVEL%
)

"%ADB_EXE%" shell am start -n id.indexim.mbs/.MainActivity

echo.
echo ========================================================
echo   SUKSES! Aplikasi telah terpasang dan dibuka di HP.
echo ========================================================
echo.
pause
