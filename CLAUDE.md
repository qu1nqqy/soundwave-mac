# soundwave-mac

Приложение для macOS для soundwave: следит за Apple Music, берёт цвета обложки и ритм
и шлёт их по UDP на ESP32 (репо `soundwave-firmware`, там же задан формат пакета).

## Устройство

- Swift Package + Makefile, приложение в строке меню (SwiftUI `MenuBarExtra`), macOS 15+, Swift 6.
- `Sources/SoundwaveCore/` — логика без системных API (протокол, палитра, `Spectrum`, `BassLevel`,
  `BeatDetector`, `Envelope`, `LightScene`). Всё, что можно проверить без системы, — сюда и под тесты
  (`Tests/SoundwaveCoreTests/`, Swift Testing).
- `Sources/Soundwave/` — приложение: `NowPlaying` (уведомления Music + AppleScript за обложкой),
  `AudioTap` (Core Audio process tap на Music), `Analyzer`, `AudioMonitor`, `LightSender` (UDP:
  состояние раз в секунду + 60 Гц в такт), `AppState`, `MenuView`.
- Протокол задаёт прошивка (`soundwave-firmware`): Fill `0x01`, Palette `0x02`, Level `0x03`.
  Меняешь протокол — меняй обе стороны и тесты с обеих сторон.

## Сборка и проверки

```sh
make check   # lint + test + app — то же, что CI
make run     # собрать, подписать «Apple Development», запустить
```

Makefile выставляет `DEVELOPER_DIR` на Xcode: у Command Line Tools сломан плагин TestingMacros.
`.app` подписывается постоянным сертификатом, иначе TCC забывает разрешения после каждой пересборки.

## Кто что пишет

Весь код здесь, включая тесты, пишет Claude. Пользователь знает Swift только на уровне синтаксиса
и не собирается его учить, поэтому:

- сборка и запуск должны быть простыми (одна команда), это описано в README;
- объяснять изменения простыми словами, без погружения в Swift.

## Коммиты

- Conventional commits на русском, в прошедшем времени от первого лица, с маленькой буквы:
  `feat: добавил захват звука`, `fix: исправил …`, `refactor: …`, `test: …`, `ci: …`, `docs: …`, `chore: …`.
- Каждый коммит с трейлером `Co-Authored-By: Claude …`.

## Версии

- Semver, версия — `CFBundleShortVersionString` в `Resources/Info.plist`. Релиз — тег `v<версия>`.
- Перед PR `dev` → `main` поднять версию: исправления — патч (0.0.1 → 0.0.2), новые возможности — минор.
  CI (`version`) не даст выпустить уже существующую версию.

## Ветки

- `dev` — рабочая ветка, коммиты идут сюда.
- `main` — стабильная, защищена: только PR.
- **Пушить (в любую ветку) только по просьбе пользователя.** Коммитить локально — можно.

## Чего нет в репо

Общий README проекта и теория лежат уровнем выше (`../README.md`, `../docs/`).
Это личные заметки пользователя: в репо их не добавлять и ссылки на них не ставить.
