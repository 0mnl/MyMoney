# ADR-0005: REST-контракт синхронизации

## Статус
Принято (2026-07-18)

## Контекст

Клиент MyMoney (Flutter + Isar) работает Offline First: локальная БД — источник истины. Периодически и при событиях (открытие приложения, сохранение операции, ручной pull-to-refresh) клиент должен обмениваться данными с сервером (Ktor + Postgres) для распространения изменений между устройствами одного пользователя и между членами семьи (§ 6.7 Bible).

ADR-0004 зафиксировал стратегию разрешения конфликтов (LWW + сохранение проигравшей в истории). Оставалось определить конкретный сетевой контракт: эндпоинты, форму DTO, семантику ответов, авторизацию.

Требования, влияющие на контракт:
- Batch-обмен (не по одной записи) — минимизация количества HTTP-запросов.
- Идемпотентность — клиент может повторить push при потере сети.
- Клиентские UUID — ID сущности постоянен с момента создания на клиенте (§ 25.4 Bible).
- JWT-авторизация с refresh-токенами (см. Bible § 25.6, ADR-0001).
- Готовность к OpenAPI-спецификации (`docs/api/openapi.yaml` появится параллельно с реализацией Ktor-роутов).

## Решение

### Общие правила

- Транспорт — HTTPS (в dev — HTTP допустимо).
- Формат — JSON, кодировка UTF-8.
- Время — ISO 8601 в UTC (`2026-07-18T12:34:56.789Z`).
- Идентификаторы — строковые UUID v4.
- Денежные суммы — целые числа в копейках (`amount: 12345` = 123.45 ₽), см. ADR-0002.
- Ошибки — стандартная форма:
  ```json
  { "error": { "code": "STRING_CODE", "message": "human readable", "details": {} } }
  ```
- Все защищённые эндпоинты требуют заголовок `Authorization: Bearer <accessToken>`.
- Access-token живёт **15 минут**, refresh-token — **30 дней**. При 401 клиент вызывает `/auth/refresh`; при 401 на refresh — форс-логин.

### Эндпоинты

#### Аутентификация

```
POST /auth/register
Body: { "email": "user@example.com", "password": "..." }
200:  { "userId": "uuid", "familyId": "uuid" }
409:  email already registered
```

```
POST /auth/login
Body: { "email": "...", "password": "..." }
200:  { "accessToken": "jwt", "refreshToken": "opaque", "userId": "uuid", "familyId": "uuid" }
401:  invalid credentials
```

```
POST /auth/refresh
Body: { "refreshToken": "opaque" }
200:  { "accessToken": "jwt", "refreshToken": "opaque" }        // rotation: старый отозван
401:  refresh token invalid / expired / revoked
```

```
POST /auth/logout-all                                           (JWT)
Body: {}
204:  все refresh-токены пользователя помечены revoked_at = NOW()
```

#### Синхронизация

```
GET /sync/pull?since=<ISO-timestamp>                            (JWT)
200:
{
  "serverTime": "2026-07-18T12:34:56.789Z",
  "entities": {
    "account":      [ AccountDto,      ... ],
    "category":     [ CategoryDto,     ... ],
    "transaction":  [ TransactionDto,  ... ],
    "budget":       [ BudgetDto,       ... ],
    "goal":         [ GoalDto,         ... ],
    "debt":         [ DebtDto,         ... ],
    "subscription": [ SubscriptionDto, ... ],
    "family":       [ FamilyDto,       ... ],
    "familyMember": [ FamilyMemberDto, ... ]
  }
}
```

- `since` — момент последней успешной синхронизации клиента. Если параметр опущен — сервер возвращает полный набор (первичная загрузка).
- В каждой коллекции возвращаются все записи семьи текущего пользователя, у которых `updated_at > since`. Включая soft-deleted (`is_deleted: true`) — клиент применит удаления локально.
- `serverTime` — сохраняется клиентом как новое значение `since` для следующего pull.

```
POST /sync/push                                                 (JWT)
Body:
{
  "entities": {
    "account":      [ AccountDto,      ... ],
    "category":     [ CategoryDto,     ... ],
    "transaction":  [ TransactionDto,  ... ],
    ...
  }
}
200:
{
  "serverTime": "2026-07-18T12:35:00.000Z",
  "accepted":  [ { "table": "transaction", "id": "uuid" }, ... ],
  "conflicts": [
    {
      "table": "transaction",
      "id": "uuid",
      "serverVersion": TransactionDto     // актуальная серверная версия, клиент обязан принять
    },
    ...
  ]
}
```

- Клиент отправляет **только грязные** записи (`isDirty = true` в Isar).
- Сервер применяет LWW по `updated_at` (см. ADR-0004): если серверный `updated_at` > клиентского — запись попадает в `conflicts`, клиент обязан сохранить свою локальную версию в истории и принять серверную. Иначе — запись попадает в `accepted`, клиент помечает её `isDirty = false`.
- Push идемпотентен: повторный push той же записи с тем же `updated_at` не меняет ничего.

#### Семейный бюджет

```
POST /family/invite                                             (JWT)
Body: { "email": "invitee@example.com" }
200:  { "inviteToken": "opaque-single-use-token", "expiresAt": "ISO" }
409:  семья уже содержит 2 участников (лимит MVP)
404:  приглашаемый email не зарегистрирован
```

```
POST /family/accept                                             (JWT)
Body: { "inviteToken": "opaque" }
204:  участник добавлен, серверная семья пригласившего = family_id принявшего
409:  токен уже использован / истёк / чужая семья уже содержит 2 участников
```

### DTO-формы

Все DTO повторяют структуру таблиц из § 25.4 Bible один-в-один, с двумя отличиями:
- Внутренние поля БД (`is_deleted` в SELECT для pull) сериализуются как `isDeleted: boolean`.
- Snake_case → camelCase в JSON (`family_id` → `familyId`, `attachment_photo_path` → `attachmentPhotoPath`).

Пример `TransactionDto`:
```json
{
  "id": "uuid",
  "familyId": "uuid",
  "accountId": "uuid",
  "categoryId": "uuid | null",
  "type": "INCOME | EXPENSE | TRANSFER",
  "targetAccountId": "uuid | null",
  "amount": 12345,
  "currency": "RUB",
  "occurredAt": "2026-07-18T12:00:00.000Z",
  "comment": "string | null",
  "attachmentPhotoPath": "string | null",
  "createdBy": "uuid",
  "createdAt": "ISO",
  "updatedAt": "ISO",
  "isDeleted": false
}
```

Формальная спецификация всех DTO — `docs/api/openapi.yaml` (создаётся на Шаге 0.5).

## Обоснование

**Почему batch pull-push, а не WebSocket / SSE / GraphQL Subscriptions.**
- Простота реализации на Ktor и Dio.
- Offline First режим и так предполагает, что реалтайм — не критичен: главное, что данные консистентны после синхронизации.
- WebSocket добавляет сложность в разрешение конфликтов и переподключения. Пост-MVP при необходимости можно добавить push-уведомления через FCM для оповещения об изменениях в семье.

**Почему один эндпоинт `/sync/push` для всех сущностей.**
- Атомарность на уровне запроса: одна и та же семья не может оказаться в half-synced состоянии.
- Уменьшает количество сетевых roundtrip'ов на слабом соединении.
- Обратная сторона — размер payload может расти; при необходимости позже добавить чанки/пагинацию.

**Почему UUID генерирует клиент, а не сервер.**
- Прямое требование Offline First: создание сущности не должно ждать сети.
- Push становится idempotent upsert — та же запись с тем же ID может быть отправлена повторно без создания дубликата.

**Почему access + refresh, а не одиночный long-lived JWT.**
- Стандартная модель для мобильных приложений.
- Короткий access ограничивает окно компрометации. Refresh хранится в secure storage устройства.
- Логаут со всех устройств реализуется через отзыв всех refresh-токенов пользователя (см. таблицу `refresh_token`, § 25.4 Bible).

## Последствия

**Правила, вступающие в силу:**
- Все API-роуты имеют префикс версии: `/v1/...` (например, `/v1/sync/pull`). Пропущен в кратких формах выше — добавляется в OpenAPI-спеке.
- Клиентский sync-worker выполняет push **перед** pull в рамках одного цикла синхронизации. Это гарантирует, что клиентские изменения не будут перезаписаны свежими pull'ами до попадания на сервер.
- Клиент **обязан** обработать ответ push — если поле `conflicts` не пустое, клиент **до следующего push** сохраняет проигравшие версии в историю (см. ADR-0004).
- Сервер **обязан** валидировать, что все сущности в push-payload принадлежат `familyId` пользователя из JWT — иначе 403.
- Пароль в `/auth/register` и `/auth/login` — plain text в теле HTTPS-запроса (стандартная практика). Хэширование argon2id — на сервере.

**Тесты, обязательные:**
- Push после потери сети: клиент повторяет запрос, дубликаты не создаются.
- Refresh-токен с ротацией: старый становится невалиден после успешного refresh.
- Logout-all инвалидирует все активные refresh-токены пользователя.
- Push с записью не своей семьи → 403.

**Что делать при росте нагрузки:**
- Добавить пагинацию в `/sync/pull` (query-параметры `limit`, `cursor`).
- Разнести sync по коллекциям (`/sync/pull/transaction?since=...`) при разной частоте изменений.
- Оба варианта — отдельным ADR, не в скоупе MVP.

## Ссылки

- Bible § 22, § 25.6 — контекст.
- ADR-0004 — стратегия конфликтов.
- ADR-0002 — представление денежных сумм.
- OpenAPI-спецификация — `docs/api/openapi.yaml` (создаётся отдельно).
