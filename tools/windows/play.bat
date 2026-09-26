@echo off
setlocal
title Vita - play
rem Vita: download (or update) the game and run it in Godot 4.5.1.
rem Works from anywhere: inside the project (tools\windows) it uses that folder,
rem otherwise it downloads the latest branch into %LOCALAPPDATA%\Vita.
rem Godot is taken from D:\tools\godot or downloaded once into %LOCALAPPDATA%\Vita\godot.

set "BRANCH=claude/project-thread-x4ht8m"
set "ZIP_URL=https://github.com/crownfall90-dot/mobile-game/archive/refs/heads/%BRANCH%.zip"
set "GODOT_URL=https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_win64.exe.zip"
set "HOME_DIR=%LOCALAPPDATA%\Vita"
if not exist "%HOME_DIR%" mkdir "%HOME_DIR%"

rem ---- 1. project folder ----
set "PROJECT="
if exist "%~dp0..\..\project.godot" set "PROJECT=%~dp0..\.."
if not defined PROJECT if exist "%~dp0project.godot" set "PROJECT=%~dp0."
if defined PROJECT goto update_git
echo [1/3] Downloading the latest Vita from GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%ZIP_URL%' -OutFile '%HOME_DIR%\vita.zip'; if (Test-Path '%HOME_DIR%\mobile-game-claude-project-thread-x4ht8m') { Remove-Item -Recurse -Force '%HOME_DIR%\mobile-game-claude-project-thread-x4ht8m' }; Expand-Archive -Force '%HOME_DIR%\vita.zip' '%HOME_DIR%'"
if errorlevel 1 goto fail_download
set "PROJECT=%HOME_DIR%\mobile-game-claude-project-thread-x4ht8m"
goto find_godot

:update_git
echo [1/3] Project: %PROJECT%
where git >nul 2>nul
if errorlevel 1 goto find_godot
pushd "%PROJECT%"
git pull --ff-only origin %BRANCH%
popd

rem ---- 2. Godot 4.5.1 ----
:find_godot
set "GODOT="
if exist "D:\tools\godot\Godot_v4.5.1-stable_win64.exe" set "GODOT=D:\tools\godot\Godot_v4.5.1-stable_win64.exe"
if not defined GODOT if exist "%HOME_DIR%\godot\Godot_v4.5.1-stable_win64.exe" set "GODOT=%HOME_DIR%\godot\Godot_v4.5.1-stable_win64.exe"
if defined GODOT goto run
echo [2/3] Downloading Godot 4.5.1 (about 60 MB, only once)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%GODOT_URL%' -OutFile '%HOME_DIR%\godot.zip'; Expand-Archive -Force '%HOME_DIR%\godot.zip' '%HOME_DIR%\godot'"
if errorlevel 1 goto fail_download
set "GODOT=%HOME_DIR%\godot\Godot_v4.5.1-stable_win64.exe"
if not exist "%GODOT%" goto fail_godot

rem ---- 3. run ----
:run
echo [3/3] Importing resources (first time takes a minute)...
"%GODOT%" --headless --path "%PROJECT%" --import
echo Starting Vita...
"%GODOT%" --path "%PROJECT%"
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
