@echo off
setlocal
title Vita
rem Vita for Windows: one file. Double-click it anywhere.
rem   1 = play: downloads/updates the game and Godot 4.5.1, then runs Vita.
rem   2 = build APK: builds the Android test APK with this laptop's Godot settings
rem       (same signing key as before, so the update keeps the player's progress).

set "BRANCH=claude/project-thread-x4ht8m"
set "ZIP_URL=https://github.com/crownfall90-dot/mobile-game/archive/refs/heads/%BRANCH%.zip"
set "GODOT_URL=https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_win64.exe.zip"
set "HOME_DIR=%LOCALAPPDATA%\Vita"
set "DL_DIR=%HOME_DIR%\mobile-game-claude-project-thread-x4ht8m"
if not exist "%HOME_DIR%" mkdir "%HOME_DIR%"

echo.
echo   Vita
echo   1 - play
echo   2 - build APK for the phone
echo.
choice /c 12 /n /m "Press 1 or 2: "
set "MODE=%errorlevel%"

rem ---- project folder: the one around this file, or the latest download ----
set "PROJECT="
if exist "%~dp0..\..\project.godot" set "PROJECT=%~dp0..\.."
if not defined PROJECT if exist "%~dp0project.godot" set "PROJECT=%~dp0."
if defined PROJECT goto update_git
echo Downloading the latest Vita from GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%ZIP_URL%' -OutFile '%HOME_DIR%\vita.zip'; if (Test-Path '%DL_DIR%') { Remove-Item -Recurse -Force '%DL_DIR%' }; Expand-Archive -Force '%HOME_DIR%\vita.zip' '%HOME_DIR%'"
if errorlevel 1 goto fail_download
set "PROJECT=%DL_DIR%"
goto find_godot

:update_git
where git >nul 2>nul
if errorlevel 1 goto find_godot
pushd "%PROJECT%"
git pull --ff-only origin %BRANCH%
popd

rem ---- Godot 4.5.1: D:\tools\godot or a copy downloaded once ----
:find_godot
set "GODOT="
if exist "D:\tools\godot\Godot_v4.5.1-stable_win64_console.exe" set "GODOT=D:\tools\godot\Godot_v4.5.1-stable_win64_console.exe"
if not defined GODOT if exist "%HOME_DIR%\godot\Godot_v4.5.1-stable_win64_console.exe" set "GODOT=%HOME_DIR%\godot\Godot_v4.5.1-stable_win64_console.exe"
if defined GODOT goto have_godot
echo Downloading Godot 4.5.1 (about 60 MB, only once)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%GODOT_URL%' -OutFile '%HOME_DIR%\godot.zip'; Expand-Archive -Force '%HOME_DIR%\godot.zip' '%HOME_DIR%\godot'"
if errorlevel 1 goto fail_download
set "GODOT=%HOME_DIR%\godot\Godot_v4.5.1-stable_win64_console.exe"
if not exist "%GODOT%" goto fail_godot

:have_godot
echo Project: %PROJECT%
echo Importing resources (the first time takes a minute)...
"%GODOT%" --headless --path "%PROJECT%" --import
if "%MODE%"=="2" goto build

echo Starting Vita...
"%GODOT%" --path "%PROJECT%"
goto end

:build
if not exist "%APPDATA%\Godot\export_templates\4.5.1.stable\android_debug.apk" goto no_templates
if not exist "%PROJECT%\build" mkdir "%PROJECT%\build"
echo Building APK...
"%GODOT%" --headless --path "%PROJECT%" --export-debug Android "%PROJECT%\build\vita-first-act.apk"
if not exist "%PROJECT%\build\vita-first-act.apk" goto fail_build
echo.
echo Done: %PROJECT%\build\vita-first-act.apk
explorer /select,"%PROJECT%\build\vita-first-act.apk"
goto end

:no_templates
echo Android export templates for Godot 4.5.1 are not installed.
echo Open Godot 4.5.1 -^> Editor -^> Manage Export Templates -^> Download and Install, then run this again.
goto end
:fail_build
echo.
echo The build failed. Look at the messages above (Android SDK / JDK / keystore in Godot Editor Settings).
goto end
:fail_download
echo.
echo Download failed. Check the internet connection and try again.
goto end
:fail_godot
echo.
echo Godot was not found after download: %HOME_DIR%\godot
:end
echo.
pause
