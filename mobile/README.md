# MyMoney — Mobile

Flutter + Riverpod + Isar + Dio. Offline First. Clean Architecture.

Полный контекст — `docs/MyMoney_Project_Bible.md` § 25. Технические решения — `docs/adr/`.

## Требования

- Flutter 3.24+ (Dart SDK 3.5+)
- Android SDK для сборки под Android
- Xcode для сборки под iOS (пост-MVP)

Проверка среды:
```bash
flutter doctor -v
```

## Быстрый старт

Из папки `mobile/`:

```bash
# 1. Установить зависимости
flutter pub get

# 2. Сгенерировать код (Isar collections, Freezed data classes, JSON, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# 3. Запустить в эмуляторе
flutter run
```

**Важно:** на этом этапе `build_runner build` не должен падать, но и полезных
файлов не сгенерирует — в `data/local/entities/` ещё нет Isar-коллекций
(они появятся в Этапе 1 дорожной карты, § 15 Bible).

## Установка API-адреса

По умолчанию клиент ходит на `http://10.0.2.2:8080` (адрес хоста из
Android-эмулятора). Переопределить:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8080
```

Для iOS-симулятора — `http://localhost:8080`. Для физического устройства
в той же сети — IP-адрес хост-машины.

## Структура (Clean Architecture)

```
lib/
├── domain/
│   ├── model/          — plain Dart entities (Account, Category, Transaction, ...)
│   ├── repository/     — abstract repository interfaces
│   └── usecase/        — бизнес-сценарии (один класс = одно действие)
├── data/
│   ├── local/          — Isar collections (аннотированные Dart-классы), DAO
│   ├── remote/         — Dio-клиент, API DTO, mapper'ы
│   └── repository/     — реализации domain/repository (offline-first)
├── presentation/
│   ├── screens/        — экраны (по одной папке на модуль)
│   ├── providers/      — Riverpod-провайдеры экранного уровня
│   ├── widgets/        — переиспользуемые виджеты
│   ├── navigation/     — go_router
│   └── theme/          — Material 3 тема
├── core/               — env, глобальные Riverpod-провайдеры, error handling
├── sync/               — фоновая синхронизация (см. § 25.6 Bible)
└── main.dart
```

Правила:
- Presentation никогда не обращается к Isar / Dio напрямую — только через репозиторий.
- Repository возвращает **domain-модели**, не Isar-entity и не API DTO.
- Один use case = один класс = одно действие (см. § 20 Bible).

## Полезные команды

```bash
flutter pub get                                        # зависимости
flutter pub upgrade                                    # обновить в пределах ограничений pubspec
dart run build_runner watch --delete-conflicting-outputs   # автогенерация в реальном времени
flutter test                                           # unit + widget тесты
flutter analyze                                        # статический анализ
flutter run                                            # запуск в эмуляторе
flutter build apk --release                            # release APK
```

## Ключевые правила Offline First

- **Локальная БД (Isar) — источник истины.** UI подписывается на Isar-потоки
  и обновляется мгновенно при локальных изменениях, независимо от сети.
- **Sync идёт в фоне**, не блокирует UI. При потере сети — retry с backoff.
- **Все ID генерируются на клиенте (UUID).** См. ADR-0005.
- **Все денежные суммы — целые копейки (`int`).** См. ADR-0002.
- **Стратегия конфликтов — last-write-wins по `updated_at`.** См. ADR-0004.

## Что дальше (по roadmap)

- **Этап 1:** Isar-коллекции для Account, Category, Transaction; репозитории;
  экран добавления операции (≤ 3 шага, см. UC-03).
- **Этап 2:** бюджет и цели.
- **Этап 3:** аналитика и PDF-экспорт.
- **Этап 4:** авторизация + синхронизация с бэком (Dio-клиент API).
- **Этап 5:** долги и подписки.
- **Этап 6:** полировка MVP.
