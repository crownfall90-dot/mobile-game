@echo off
rem Vita: подтянуть свежую ветку с GitHub и запустить игру в окне (Godot 4.5.1 на ноутбуке).
rem Двойной щелчок по файлу. Путь к Godot — как в docs/HANDOFF.md; поменяйте GODOT ниже, если он другой.
chcp 65001 >nul
cd /d "%~dp0\..\.."
set BRANCH=claude/project-thread-x4ht8m
set GODOT=D:\tools\godot\Godot_v4.5.1-stable_win64.exe
if not exist "%GODOT%" set GODOT=D:\tools\godot\Godot_v4.5.1-stable_win64_console.exe
if not exist "%GODOT%" (
  echo Не найден Godot 4.5.1 в D:\tools\godot\. Укажите путь в переменной GODOT в этом файле.
  pause
  exit /b 1
)
echo Обновляю игру с GitHub (ветка %BRANCH%)...
git fetch origin %BRANCH%
git checkout %BRANCH% || (echo Не удалось переключить ветку: сохраните или отмените свои изменения. & pause & exit /b 1)
git pull --ff-only origin %BRANCH%
echo Импорт ресурсов (первый раз может занять минуту)...
"%GODOT%" --headless --path . --import
echo Запуск Vita...
start "" "%GODOT%" --path .
