# SQL — Настройки и скрипты базы данных DWH

В этой директории находятся SQL-скрипты для инициализации и управления
хранилищем данных (DWH) на базе **PostgreSQL 17** (контейнер `postgres-dwh`).

## Архитектура схем

```
┌────────────────────────────────────────────────────────────┐
│                        raw                                 │
│  Сырые данные "как есть"                                   │
│  Загрузка: dlt / Airbyte / прямые INSERT                   │
│  Таблицы: raw.orders, raw.customers, raw.products          │
├────────────────────────────────────────────────────────────┤
│                        stage                               │
│  Очистка, нормализация, приведение типов                   │
│  Трансформация: dbt (staging models)                       │
│  Таблицы: stage.stg_orders, stage.stg_customers            │
├────────────────────────────────────────────────────────────┤
│                        dds                                 │
│  Детальный слой — размерности и факты                      │
│  Трансформация: dbt (dimensional models)                   │
│  Таблицы: dds.dim_customers, dds.dim_products,             │
│           dds.dim_date, dds.fct_sales                      │
├────────────────────────────────────────────────────────────┤
│                        mart                                │
│  Витрины данных для аналитики и отчетов                    │
│  Трансформация: dbt (marts models)                         │
│  Таблицы: mart.daily_sales, mart.customer_lifetime_value    │
└────────────────────────────────────────────────────────────┘
```

## Схемы

| Схема | Назначение | Кто заполняет |
|---|---|---|
| `raw` | Сырые данные без изменений | dlt / Airbyte / Python |
| `stage` | Очищенные, нормализованные данные | dbt (staging) |
| `dds` | Размерности (dim_) и факты (fct_) | dbt (dimensional) |
| `mart` | Витрины данных для аналитики | dbt (marts) |

## Файлы

| Файл | Назначение |
|---|---|
| `01_init_schemas.sql` | Создание схем и расширений FDW |

## Подключение к DWH

```bash
# Из командной строки (через psql)
psql -h localhost -p 5432 -U admin -d dwh

# Через DBeaver
Host: localhost
Port: 5432
Database: dwh
User: admin
Password: postgres
```

## Запуск скриптов

```bash
# Инициализация схем
psql -h localhost -p 5432 -U admin -d dwh -f sql/01_init_schemas.sql

# Проверка созданных схем
psql -h localhost -p 5432 -U admin -d dwh -c "\dn"
```