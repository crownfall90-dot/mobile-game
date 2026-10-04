# Android: подтверждённая совместимость Vita

Срез 30.09.2026, VITA-ANDROID-COMPAT-01. Этап **PARTIAL**, релизный gate закрыт.
Последний опубликованный кандидат: 0.19.5-test/code28. Нового APK в этом этапе нет.
Отсутствие crash в headless не является проверкой Android GPU/JNI.

## Требования и инфраструктура

- Godot **4.5.1.stable.official.f62fdbde1**, `gl_compatibility`, portrait.
- Опубликованные APK: **min API 24, target API 35**. AAB-пресет: **24/36**.
  Минимум совпадает; target пока различается. Перед сменой target нужен отдельный
  Gradle-кандидат и проверка Android 16, включая Back и системные ограничения.
- `gradle_build/min_sdk`/`target_sdk` у APK пустые намеренно: native export
  использует template. [Код Godot 4.5.1](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/export/export_plugin.cpp)
  запрещает overrides без Gradle. Вписать 24 в это поле сейчас означало бы ошибку экспорта.
- arm64 и armv7 опубликованы отдельно; package `com.crownfall90.vita.test`,
  code28, один прежний сертификат v2/v3. Статическая проверка manifest/ABI/signature
  описана в HANDOFF. Это **PARTIAL**, исполнение armv7 не проверено.
- ADB: подключённых устройств нет. В доступном SDK нет Emulator/system-images,
  AVD не найден. Эмулятор не изображает драйвер Adreno 720 конкретного телефона.
- Прогресс хранится в общем формате Profile v2; формат/package не менялись.
  Реальное обновление поверх старого APK и сохранность прогресса требуют телефона.

## API matrix

| Android | API | Emulator | Physical / источник |
|---|---|---|---|
| 7 / 7.1 | 24 / 25 | NOT TESTED | NOT TESTED |
| 8 / 8.1 | 26 / 27 | NOT TESTED | NOT TESTED |
| 9 | 28 | NOT TESTED | NOT TESTED |
| 10 | 29 | NOT TESTED | NOT TESTED |
| 11 | 30 | NOT TESTED | NOT TESTED |
| 12 / 12L | 31 / 32 | NOT TESTED | NOT TESTED |
| 13 | 33 | NOT TESTED | NOT TESTED |
| 14 | 34 | NOT TESTED | NOT TESTED |
| 15 | 35 | NOT TESTED | NOT TESTED |
| 16 | 36 | NOT TESTED | FAIL: отчёты тестеров ниже; не полный протокол ретеста |

## Device matrix

GPU записан из отчёта, SoC не выводится по торговому имени. ABI установленного
приложения не подменяем списком ABI, поддерживаемых телефоном.

| Device | SoC/GPU | Android | ABI | Version | Scenarios | Result | Issues |
|---|---|---|---|---|---|---|---|
| DNY-NX9 | SoC не установлен / Adreno 720 | API 36, 10.0.0.208C185E4R2P2 | не зафиксирована | 0.19.5-test | home_06, попытка 2, активная игра | FAIL (автоотчёт тестера) | #26 |
| DNY-NX9 | Adreno 720 | API 36 | не зафиксирована | 0.19.4-test | room_wall / kitchen_sink после game→hub | FAIL; ретест этих путей 0.19.5 NOT TESTED | #24/#25 |
| SM-A556E | SoC не установлен / ANGLE, Samsung Xclipse 530, Vulkan 1.3.279 | API 36, A556EXXSIDZI3 | не зафиксирована | 0.19.3/0.19.4 | novel, home_01 | FAIL; 0.19.5 NOT TESTED | #13–15/#23 |
| RMX3709 | SoC не установлен / Adreno 730 | API 36 по отчётам | не зафиксирована | 0.19.2–0.19.4 | ручные вылеты в комнате; поза занятия | PARTIAL; 0.19.5 NOT TESTED | комментарии #5 |
| Honor400 | не установлены | неизвестно | неизвестно | нет подтверждённого ретеста | прежний путь нужен от владельца | NOT TESTED | не связывать автоматически с DNY-NX9 |
| Xiaomi/Redmi/POCO | не установлены | — | — | — | нет доступного устройства | NOT TESTED | — |
| Pixel / чистый Android | не установлены | — | — | — | нет доступного устройства | NOT TESTED | — |
| Mali / PowerVR / настоящий 32-bit Android | нет доступного устройства | — | — | — | runtime не проверен | NOT TESTED | — |

Ни одного полного `PASS physical`/`PASS emulator` для нового протокола нет.
ANGLE в отчёте Samsung не означает, что Vita перешла на Vulkan renderer.

## Карта автоматических отчётов

`status` ниже — системный exit status, не triage. Общий SIGSEGV/status11 не
доказывает общую причину. Triage и ручные отзывы — [FEEDBACK_BACKLOG](FEEDBACK_BACKLOG.md).

| Issue | Version | Model | Android | GPU | Screen | Level | Reason | Status | Scenario |
|---|---|---|---|---|---|---|---|---|---|
| [#8](https://github.com/crownfall90-dot/mobile-game/issues/8) | 0.19.2-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | novel | — | не установлено | — | новелла; marker |
| [#9](https://github.com/crownfall90-dot/mobile-game/issues/9) | 0.19.2-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | game | home_02 | не установлено | — | home_02; marker |
| [#10](https://github.com/crownfall90-dot/mobile-game/issues/10) | 0.19.2-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | hub | — | не установлено | — | Hub; marker |
| [#11](https://github.com/crownfall90-dot/mobile-game/issues/11) | 0.19.2-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | hub | — | не установлено | — | Hub; marker |
| [#12](https://github.com/crownfall90-dot/mobile-game/issues/12) | 0.19.2-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | hub | — | не установлено | — | Hub; marker |
| [#13](https://github.com/crownfall90-dot/mobile-game/issues/13) | 0.19.4-test | SM-A556E | Android 36.A556EXXSIDZI3 | ANGLE ((Samsung Xclipse 530) on Vulkan 1.3.279) | novel | — | native_crash | 11 | пролог |
| [#14](https://github.com/crownfall90-dot/mobile-game/issues/14) | 0.19.4-test | SM-A556E | Android 36.A556EXXSIDZI3 | ANGLE ((Samsung Xclipse 530) on Vulkan 1.3.279) | novel | — | java_crash | 0 | пролог; Java stack отсутствует |
| [#15](https://github.com/crownfall90-dot/mobile-game/issues/15) | 0.19.4-test | SM-A556E | Android 36.A556EXXSIDZI3 | ANGLE ((Samsung Xclipse 530) on Vulkan 1.3.279) | game | home_01 | native_crash | 11 | home_01 |
| [#16](https://github.com/crownfall90-dot/mobile-game/issues/16) | 0.19.4-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | hub | — | native_crash | 11 | Hub; точные шаги неизвестны |
| [#17](https://github.com/crownfall90-dot/mobile-game/issues/17) | 0.19.4-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | game | home_01 | native_crash | 11 | home_01 |
| [#18](https://github.com/crownfall90-dot/mobile-game/issues/18) | 0.19.4-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | hub | — | native_crash | 11 | Hub |
| [#19](https://github.com/crownfall90-dot/mobile-game/issues/19) | 0.19.4-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | hub | — | native_crash | 11 | Hub |
| [#20](https://github.com/crownfall90-dot/mobile-game/issues/20) | 0.19.4-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | game | home_04 | native_crash | 11 | home_04 |
| [#21](https://github.com/crownfall90-dot/mobile-game/issues/21) | 0.19.4-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | game | home_01 | native_crash | 11 | home_01 |
| [#22](https://github.com/crownfall90-dot/mobile-game/issues/22) | 0.19.4-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | hub | — | native_crash | 11 | Hub |
| [#23](https://github.com/crownfall90-dot/mobile-game/issues/23) | 0.19.3-test | SM-A556E | Android 36.A556EXXSIDZI3 | ANGLE ((Samsung Xclipse 530) on Vulkan 1.3.279) | game | home_01 | native_crash | 11 | старый crash, задержанная доставка |
| [#24](https://github.com/crownfall90-dot/mobile-game/issues/24) | 0.19.4-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | hub | — | native_crash | 11 | game→hub, room_wall, busy/talking |
| [#25](https://github.com/crownfall90-dot/mobile-game/issues/25) | 0.19.4-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | hub | — | native_crash | 11 | game→hub, kitchen_sink, router_busy |
| [#26](https://github.com/crownfall90-dot/mobile-game/issues/26) | 0.19.5-test | DNY-NX9 | Android 36.10.0.0.208C185E4R2P2 | Adreno (TM) 720 | game | home_06 | native_crash | 11 | home_06 attempt2, активная физика |

## Что установлено / что пока гипотеза

- #8–12 не содержат системной причины: running marker сам по себе не доказывает crash.
- #13–25 содержат 12 native_crash и 1 java_crash; #23 относится к старой 0.19.3.
- #24/#25 — узкая общая зона game→hub→repair. В 0.19.5 переиспользуется
  NoiseTexture2D и исправлен тип uniform. Native stack отсутствует: точная причина
  SIGSEGV не установлена, кандидат нельзя назвать подтверждённым исправлением.
- #26 — единственный полученный в этом срезе автоотчёт **0.19.5-test**,
  native_crash reason5/status11. Home_06, attempt2, finished=false, router_busy=false;
  перед crash был вход Hub→Game и касания, без возврата/ремонта. Отдельное
  расследование VITA-ANDROID-GAME-01. Число успешных физических переходов неизвестно.
- Все 15 комментариев #5 просмотрены: технический тест; неясное сообщение;
  ручные вылеты DNY/RMX; цвет feedback; поза без названия занятия; предложение
  перехода комнаты; комод, одежда и звёзды. Индекс содержит каждый источник.
  Ручные «вылет» не превращаем в native_crash без ApplicationExitInfo/стека.

## Проверка общих путей кода

- Physics2D: контакты Level накапливаются в очередях, обработка в `_physics_process`;
  удаление Item/shape — `queue_free`, freeze Enemy и выключение Pin/Pipe — deferred.
  Restart сначала снимает старый Level с дерева. Нарушение physics flush в прогоне
  не найдено; доказательства причины #26 нет. Dirt обновляет collision rows и texture,
  FluidRenderer использует SubViewport/MultiMesh: эти GPU-пути требуют device trace.
- Rendering: canvas_item shaders; FluidRenderer при выходе отсоединяет viewport texture
  и выключает обновление viewport. Общая NoiseTexture2D сохранена. Генерация ImageTexture
  есть у dirt, background, item art, pin/icons; произвольный vendor fallback не добавлен.
  Headless использует dummy renderer и не проверяет OpenGL driver.
- Java bridge: исправлен конкретный пробел Reports — исключение проверяется после
  каждого вызова, первый сбой прекращает чтение. Раньше поздний вызов мог скрыть ранний.
  API<30 прекращает путь до ApplicationExitInfo. Null history/empty history допускаются.
  Нельзя связывать эту правку с #14 без Java stack. JNI на Android пока NOT TESTED.
- Network: HTTPRequest живёт в Reports, не в popup; timeout25s, очередь на диске,
  повтор через60s, ID сохраняется при повторе. Offline не уничтожает pending report.
  Selfcheck проверяет обработку ответов/черновика; реальное прерывание сети Android
  и отправка после OS kill в этом этапе NOT TESTED.
- Storage: tmp проверяется чтением до замены; повреждённый основной файл не затирает
  backup; при ошибке записи сохраняется старый файл и планируется повтор. Home-selfcheck
  покрывает corruption/recovery/reset. Физический полный диск/kill во время write NOT TESTED.
- Pause/Back: Router обрабатывает системные notifications, busy блокирует Back;
  пауза игры и duplicate popup защищены. Profile flush при pause, Reports checkpoint,
  Sfx приостанавливает звук. Симуляция обработчиков не проверяет Activity recreation,
  screen lock, звонок/overlay, OEM memory pressure или аппаратный Back.
- Layout: существующие layout-тесты kitchen/bath/living и safe rect сохранены.
  720×1280, 20:9, tablet/foldable и реальные вырезы/клавиатура по новому протоколу
  не получили полного визуального/device PASS; прежние кадры 450×800/1000 — в HANDOFF.

## Компьютерный набор

Запуск: `python tools/check_android_compat.py --godot <Godot-4.5.1>`.
Логи: игнорируемый `build/android-compat/`. Набор использует существующие проверки,
ограничивает время, считает ошибки, warnings и ObjectDB; отдельно указывает ожидаемые
corruption warnings и отсутствие физической проверки. Итоги этапа — в HANDOFF.

Home06: реальные digging/water loss → restart → attempt2 с работающей физикой,
50 циклов, low FX чередуется; 20 вызовов pause/resume с двойным pause.
Hub: 25 room_wall completion + 25 kitchen_sink + все 19 ремонтов/четыре финала.
Результат Home.finish в Hub-тесте задаётся тестом; реальные решения уровней проверяет
отдельный verify G1–G7, это не 69 прохождений игроком.

## Godot 4.5.1 и native debug

[Release notes 4.5.1](https://godotengine.org/article/maintenance-release-godot-4-5-1/):
Android fragment cleanup уже входит в установленную версию. Перечисленные Jolt fixes
относятся к 3D; они не объясняют Physics2D Vita. Совпадающий engine bug не доказан.
Внешние #119626 (Mali), #116990 (Adreno650/3D shader), #112956 (3D Compatibility)
не дают соответствующего стека Vita; обновление движка без сравнения не выполнялось.
[JavaClassWrapper](https://docs.godotengine.org/en/4.5/classes/class_javaclasswrapper.html)
требует проверять exception после Java-вызова — на этом основана правка Reports.

[Assets 4.5.1](https://github.com/godotengine/godot/releases/tag/4.5.1-stable)
содержат Android symbols для editor и **template_release**, отдельного template_debug
в списке нет. Нельзя символизировать debug APK release-символами без совпадения Build ID.
Движок не пересобирали, NDK/symbols не скачивали без native backtrace.

### При доступном ADB

1. Установить текущий подписанный APK поверх старого (`adb install -r ...`), сохранить
   `dumpsys package com.crownfall90.vita.test`, модель/API/GPU и факт сохранения прогресса.
2. **До запуска** в отдельном терминале включить `adb logcat -b all -v threadtime > build/android-compat/device-logcat.txt`.
   Не фильтровать только PID игры: tombstone пишет также debuggerd. Не очищать буферы.
3. Записать время, после старта `adb shell pidof com.crownfall90.vita.test`.
   Повторить проблемный путь, остановить capture Ctrl+C; сохранить
   `adb logcat -b crash -d` отдельно. Искать F DEBUG, signal11, SIGSEGV, backtrace,
   libgodot_android.so, vendor driver и Java exception.
4. Если разрешено устройством — `adb bugreport build/android-compat/device-bugreport.zip`.
   Доступ к `/data/tombstones` без специальных прав не обещается. Приложение/данные
   не удалять; после сбоя один раз запустить с сетью для Reports.
5. Сопоставить timestamp/build/ABI/Build ID библиотеки и symbols до ndk-stack/addr2line.
   Сырые logcat/bugreport могут содержать личные данные: хранить локально в build,
   в HANDOFF только очищенный результат/ссылку. Сейчас capture НЕ выполнялся: нет устройства.

## Release gate / следующий шаг

#24/#25/#26 остаются investigate. Требуется DNY-NX9: room_wall→кухня,
kitchen_sink→Hub, ещё10 переходов и home_06 water loss/restart; SM-A556E:
пролог/home_01/3–5 переходов/сворачивание с проверкой native и Java. RMX3709:
действия с точным названием/отменой, переходы; Honor400 — когда доступен.
На каждом зафиксировать Android, Settings/versionCode, update vs clean, старый save,
число переходов, Back, feedback, suspend/resume и issue нового crash.
Новый публичный релиз «стабильнее» до этих проверок не разрешён критерием задачи.
