@echo off
rem Vita: собрать тестовый APK (Android, arm64) тем же ключом, что прежние версии.
rem Нужны Godot 4.5.1, шаблон экспорта Android и настроенные Android SDK / JDK 17 (docs/HANDOFF.md).
chcp 65001 >nul
cd /d "%~dp0\..\.."
set GODOT=D:\tools\godot\Godot_v4.5.1-stable_win64_console.exe
if not exist "%GODOT%" (
  echo Не найден %GODOT%. Укажите путь в переменной GODOT в этом файле.
  pause
  exit /b 1
)
if not exist build mkdir build
"%GODOT%" --headless --path . --import
"%GODOT%" --headless --path . --export-debug Android build\vita-first-act.apk
if errorlevel 1 (echo Сборка не удалась, см. сообщения выше. & pause & exit /b 1)
echo Готово: build\vita-first-act.apk
pause
