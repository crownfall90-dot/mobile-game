@echo off
setlocal
title Vita - build APK
rem Vita: build the test APK (Android arm64) with THIS laptop's Godot settings,
rem so it is signed with the same key as the installed game (update keeps progress).
rem Needs: Godot 4.5.1, Android export templates, Android SDK and JDK set in
rem Godot -> Editor Settings -> Export -> Android (as used for the previous APKs).

set "BRANCH=claude/project-thread-x4ht8m"
set "PROJECT="
if exist "%~dp0..\..\project.godot" set "PROJECT=%~dp0..\.."
if not defined PROJECT if exist "%~dp0project.godot" set "PROJECT=%~dp0."
if not defined PROJECT if exist "%LOCALAPPDATA%\Vita\mobile-game-claude-project-thread-x4ht8m\project.godot" set "PROJECT=%LOCALAPPDATA%\Vita\mobile-game-claude-project-thread-x4ht8m"
if not defined PROJECT goto no_project

set "GODOT="
if exist "D:\tools\godot\Godot_v4.5.1-stable_win64_console.exe" set "GODOT=D:\tools\godot\Godot_v4.5.1-stable_win64_console.exe"
if not defined GODOT if exist "D:\tools\godot\Godot_v4.5.1-stable_win64.exe" set "GODOT=D:\tools\godot\Godot_v4.5.1-stable_win64.exe"
if not defined GODOT if exist "%LOCALAPPDATA%\Vita\godot\Godot_v4.5.1-stable_win64_console.exe" set "GODOT=%LOCALAPPDATA%\Vita\godot\Godot_v4.5.1-stable_win64_console.exe"
if not defined GODOT if exist "%LOCALAPPDATA%\Vita\godot\Godot_v4.5.1-stable_win64.exe" set "GODOT=%LOCALAPPDATA%\Vita\godot\Godot_v4.5.1-stable_win64.exe"
if not defined GODOT goto no_godot

if not exist "%APPDATA%\Godot\export_templates\4.5.1.stable\android_debug.apk" goto no_templates

echo Project: %PROJECT%
echo Godot:   %GODOT%
where git >nul 2>nul
if errorlevel 1 goto build
pushd "%PROJECT%"
git pull --ff-only origin %BRANCH%
popd

:build
if not exist "%PROJECT%\build" mkdir "%PROJECT%\build"
echo Importing resources...
"%GODOT%" --headless --path "%PROJECT%" --import
echo Building APK...
"%GODOT%" --headless --path "%PROJECT%" --export-debug Android "%PROJECT%\build\vita-first-act.apk"
if not exist "%PROJECT%\build\vita-first-act.apk" goto fail_build
echo.
echo Done: %PROJECT%\build\vita-first-act.apk
goto end

:no_project
echo Vita project not found. Run play.bat once (it downloads the game), or put this file into the project's tools\windows folder.
goto end
:no_godot
echo Godot 4.5.1 not found in D:\tools\godot. Run play.bat once, or edit the paths in this file.
goto end
:no_templates
echo Android export templates for Godot 4.5.1 are not installed.
echo Open Godot 4.5.1 -^> Editor -^> Manage Export Templates -^> Download and Install, then run this again.
goto end
:fail_build
echo.
echo The build failed. Look at the messages above (Android SDK / JDK / keystore in Godot Editor Settings).
:end
echo.
pause
