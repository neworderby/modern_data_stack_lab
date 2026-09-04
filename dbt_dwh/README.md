# dbt_dwh

dbt-проект DWH для данных сервиса самокатов (scooters). Источник — публичный S3-бакет `inzhenerka-public`, приёмник — PostgreSQL.

## Структура

```
dbt_dwh/
├── models/
│   ├── properties.yml      # источники (raw.trips, raw.users, raw.events), тесты, конфиги моделей
│   └── ...                 # SQL-модели (staging → marts)
├── macros/                 # кастомные макросы (updated_at, date_in_moscow, ...)
├── seeds/                  # CSV-файлы, загружаемые через dbt seed
├── tests/                  # singular-тесты
└── dbt_project.yml         # конфигурация проекта
```

## Основные команды

```bash
dbt run                 # собрать все модели
dbt run -s trips_prep   # собрать конкретную модель
dbt test                # прогнать все тесты
dbt test -s source:raw.users   # тесты конкретного источника
dbt build               # run + test в правильном порядке
dbt docs generate && dbt docs serve   # документация
```

---

## Тесты (Data Quality)

Тесты описываются в YAML-файлах (`models/properties.yml`) в блоках `data_tests:` под колонками источников/моделей.

### ⚠️ Важно: синтаксис dbt 1.9 vs 1.10+

В проекте используется **dbt 1.9.6**. В ней аргументы тестов передаются **напрямую**, без обёртки `arguments:` (этот блок появился только в dbt 1.10+).

```yaml
# ✅ dbt 1.9 (текущая версия)
data_tests:
  - accepted_values:
      values: [ "M", "F" ]
  - relationships:
      name: "every_trip_has_user"
      to: "source('raw', 'users')"
      field: "id"
```

```yaml
# ❌ dbt 1.10+ — НЕ работает на dbt 1.9
data_tests:
  - accepted_values:
      arguments:          # упадёт с ошибкой:
        values: [ "M", "F" ]   # macro 'dbt_macro__test_accepted_values'
                               # takes no keyword argument 'arguments'
```

Если после копирования примера из актуальной документации dbt появляется ошибка
`macro '...' takes no keyword argument 'arguments'` — просто убери уровень
вложенности `arguments:` и подними параметры на уровень выше.

Либо обновиться: `pip install --upgrade "dbt-core>=1.10" dbt-postgres` — тогда
новый синтаксис заработает как есть.

### Готовые (generic) тесты

| Тест | Что проверяет | Пример из проекта |
|------|---------------|-------------------|
| `not_null` | в колонке нет NULL | `user_id` в `raw.trips` |
| `accepted_values` | значения из списка | `sex` в `[M, F]` у `raw.users` |
| `relationships` | ссылочная целостность | каждая поездка ссылается на существующего `users.id` |
| `unique` | значения не повторяются | — |
| `dbt_utils.*` | расширенные проверки (пакет) | — |

Синтаксис на примере `raw.trips.user_id`:

```yaml
sources:
  - name: "raw"
    tables:
      - name: "trips"
        columns:
          - name: "user_id"
            data_tests:
              - not_null
              - relationships:
                  name: "every_trip_has_user"
                  to: "source('raw', 'users')"
                  field: "id"
```

### Серьёзность (severity)

Тест можно сделать предупреждением вместо ошибки — прогон не упадёт, но в логе будет WARN:

```yaml
- not_null:
    config:
      severity: "warn"
```

### Кастомные (singular) тесты

SQL-файл в папке `tests/` — тест проходит, если запрос возвращает **0 строк**:

```sql
-- tests/no_negative_prices.sql
select * from raw.trips where price < 0
```

### Запуск

```bash
dbt test                          # все тесты
dbt test -s source:raw.users      # тесты одного источника
dbt test -s every_trip_has_user   # тест по имени
dbt build                         # модели + тесты одной командой
```

---

## Sources

Источник `raw` (loader: S3):

| Таблица | Описание | Тесты |
|---------|----------|-------|
| `raw.trips` | Поездки самокатов | `not_null`, `relationships` на `user_id`, freshness |
| `raw.users` | Пользователи сервиса | `accepted_values` на `sex`, `not_null` (warn) |
| `raw.events` | События (с дубликатами) | — |

Freshness проверяется отдельно: `dbt source freshness`.

## Resources

- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
