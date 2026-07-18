# MyMoney — Backend

Kotlin + Ktor 3 + PostgreSQL 16 + Exposed + Koin + JWT, Clean Architecture.

Полный контекст — `docs/MyMoney_Project_Bible.md` § 25. Технические решения — `docs/adr/`.

## Требования

- JDK 17+
- Docker (для локального Postgres)
- Gradle 8.10+ (обёртка `./gradlew` появится после первого запуска; будет закоммичена отдельно)

## Быстрый старт

```bash
# 1. Скопировать env
cp ../.env.example ../.env

# 2. Поднять Postgres
cd ..
docker compose up -d postgres

# 3. Собрать и запустить сервер (из папки backend/)
cd backend
./gradlew run
```

Сервер поднимается на `http://localhost:8080`. Приложение при старте:
1. Читает конфиг из `application.conf` + env-переменных.
2. Применяет миграции Flyway (`db/migration/V*.sql`) — схема создаётся автоматически.
3. Регистрирует HTTP-роуты (`/healthz`, `/v1/*` — по мере реализации).

## Полезные команды Gradle

```bash
./gradlew run                # локальный запуск
./gradlew build              # компиляция + тесты
./gradlew test               # только тесты
./gradlew buildFatJar        # собрать fat JAR (mymoney-backend.jar)
./gradlew flywayInfo         # состояние миграций (использует env DB_URL/USER/PASSWORD)
./gradlew flywayMigrate      # ручной прогон миграций (обычно приложение делает это само на старте)
./gradlew flywayValidate     # проверка целостности миграций
```

## Структура (Clean Architecture)

```
src/main/kotlin/mymoney/
├── domain/
│   ├── model/          — доменные сущности (Account, Category, Transaction, ...)
│   ├── repository/     — интерфейсы репозиториев
│   └── usecase/        — бизнес-сценарии
├── data/
│   ├── db/             — Exposed таблицы, HikariCP конфиг
│   └── repository/     — реализации репозиториев (Exposed DSL внутри transaction { })
├── delivery/
│   └── http/           — Ktor роуты, DTO, JWT-фильтры
├── config/             — типизированный доступ к application.conf
├── di/                 — Koin модули
└── Application.kt      — точка входа
```

Правила:
- Domain не знает про Exposed / Ktor.
- Data не знает про Ktor.
- Delivery не знает про SQL.
- Все use case — один класс = одно действие (см. § 20 Bible).

## Миграции

- Расположение: `src/main/resources/db/migration/`
- Формат имени: `V{версия}__{краткое_описание}.sql` (два подчёркивания!)
- Никогда не редактировать уже применённую миграцию — только добавлять новую.
- `SchemaUtils.create()` из Exposed **запрещён** в production-коде (см. ADR-0003).

## Переменные окружения

| Переменная | По умолчанию | Назначение |
|---|---|---|
| `PORT` | `8080` | HTTP-порт сервера |
| `DB_URL` | `jdbc:postgresql://localhost:5432/mymoney` | JDBC URL Postgres |
| `DB_USER` | `mymoney` | пользователь БД |
| `DB_PASSWORD` | `mymoney_dev_password` | пароль (dev-only default) |
| `DB_POOL_SIZE` | `10` | размер HikariCP пула |
| `JWT_SECRET` | `dev-only-change-me-in-production` | HMAC-ключ подписи JWT |
| `JWT_ISSUER` | `mymoney` | iss |
| `JWT_AUDIENCE` | `mymoney-mobile` | aud |
| `JWT_ACCESS_TTL_MINUTES` | `15` | TTL access-токена |
| `JWT_REFRESH_TTL_DAYS` | `30` | TTL refresh-токена |

## Тестирование

Тесты используют Testcontainers для поднятия Postgres — не H2, не in-memory (см. ADR-0003, "риск диалектных различий"). Docker должен быть запущен.

```bash
./gradlew test
```
