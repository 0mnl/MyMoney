# Architecture Decision Records

Каждое значимое архитектурное решение проекта фиксируется отдельным файлом по шаблону из раздела 19.1 Bible.

## Формат имени
`NNNN-kebab-case-title.md`, где `NNNN` — порядковый номер (4 цифры).

## Формат содержимого

```markdown
# ADR-NNNN: Название решения

## Статус
Предложено / Принято / Отклонено / Заменено ADR-XXXX

## Контекст
Какая проблема решается.

## Решение
Что решено.

## Последствия
Что это значит для дальнейшей разработки.
```

## Запланированные ADR для Этапа 0

- `0001-tech-stack.md` — Ktor+Postgres+Exposed+Koin+JWT (backend), Flutter+Riverpod+Isar+Dio (mobile).
- `0002-money-representation.md` — целые копейки, `BIGINT` / `Int64`, единая валюта RUB на MVP.
- `0003-sql-layer-exposed.md` — выбор Exposed вместо jOOQ/JDBI.
- `0004-conflict-resolution.md` — last-write-wins по `updated_at`, проигравшая версия в `transaction_history`.
- `0005-sync-rest-contract.md` — REST-контракт `/sync/pull` и `/sync/push`.

## Принятые после Этапа 0

- `0006-single-currency-rub.md` — MVP работает только с рублём; поле `currency` остаётся в схеме как задел, пункт «Валюта» убран из Настроек.
