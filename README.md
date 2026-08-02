# Modern Data Stack Lab

DWH-проект на базе **dbt**, **Apache Airflow**, **PostgreSQL** и **NocoDB**.

## Установленные сервисы

| Сервис | Контейнер | Образ | Порт (хост) | Назначение |
|---|---|---|---|---|
| Airflow Webserver | `airflow-webserver` | apache/airflow:2.10.4 (кастомный) | **8080** | Веб-интерфейс Airflow |
| Airflow Scheduler | `airflow-scheduler` | apache/airflow:2.10.4 (кастомный) | — | Планировщик DAG |
| Airflow Worker | `airflow-worker` | apache/airflow:2.10.4 (кастомный) | — | Celery worker |
| Airflow Triggerer | `airflow-triggerer` | apache/airflow:2.10.4 (кастомный) | — | Deferrable operators |
| Airflow Init | `airflow-init` | apache/airflow:2.10.4 (кастомный) | — | Инициализация БД, импорт подключений, создание admin-юзера |
| Airflow CLI | `airflow-cli` | apache/airflow:2.10.4 (кастомный) | — | CLI (профиль `debug`) |
| Airflow DB | `airflow-db` | postgres:13 | **5433** | Метаданные Airflow |
| Redis | `airflow-redis` | redis:7.2-bookworm | — | Брокер сообщений Celery |
| DWH Postgres | `postgres-dwh` | postgres:17.2 (кастомный, FDW) | **5432** | Хранилище данных (DWH) |
| NocoDB | `noco-db` | nocodb/nocodb:latest | **8081** | No-code интерфейс для работы с БД |

### Кастомные Docker-образы

- **`docker/airflow.dockerfile`** — Airflow + dbt, dlt, duckdb, pandas, pymssql и другие зависимости из `requirements.txt`.
- **`docker/postgres.dockerfile`** — PostgreSQL 17 с предустановленными FDW-расширениями:
  - `tds_fdw` — для подключения к MS SQL Server
  - `mysql_fdw` — для подключения к MySQL

## Быстрый старт

### Предварительные требования

- [Docker](https://docs.docker.com/get-docker/) с поддержкой Docker Compose v2
- Свободные порты на хосте: **5432, 5433, 8080, 8081**
- Минимум 4 ГБ RAM и 2 CPU для Docker

### Шаг 1. Клонирование репозитория

```bash
git clone https://github.com/neworderby/modern_data_stack_lab.git
cd modern_data_stack_lab
```

### Шаг 2. Создание файла `.env`

Создайте файл `.env` в корне проекта со переменными и задайте их значения:

```env
# === Airflow ===
AIRFLOW_UID="50000"
AIRFLOW__CORE__TEST_CONNECTION="Enabled"
PYTHONPATH="./plugins"
AIRFLOW__CORE__DEFAULT_TIMEZONE="Europe/Moscow"
_AIRFLOW_WWW_USER_USERNAME="admin"
_AIRFLOW_WWW_USER_PASSWORD="airflow"
AIRFLOW_FERNET_KEY="<СГЕНЕРИРОВАТЬ_КЛЮЧ>"
AIRFLOW_DB_USER="airflow"
AIRFLOW_DB_PASSWORD="airflow"
AIRFLOW_DB_NAME="airflow"

# === DWH Postgres ===
DWH_USER="admin"
DWH_PASSWORD="postgres"

# === NocoDB ===
NOCODB_ADMIN_EMAIL="admin@example.com"
NOCODB_ADMIN_PASSWORD="admin123"
```

#### Генерация FERNET_KEY

Выполните команду и вставьте результат в `AIRFLOW_FERNET_KEY`:

```bash
python3 -c "import secrets, base64; print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode())"
```

> **Важно:** Значения `AIRFLOW_DB_USER`, `AIRFLOW_DB_PASSWORD`, `AIRFLOW_DB_NAME`, `DWH_USER`, `DWH_PASSWORD`, `NOCODB_ADMIN_EMAIL`, `NOCODB_ADMIN_PASSWORD` должны совпадать с теми, что указаны в `connections.json` (см. Шаг 3).

### Шаг 3. Создание файла `connections.json`

Создайте файл `connections.json` в корне проекта. Этот файл содержит подключения Airflow, которые **автоматически импортируются** при первом запуске.

```json
{
  "postgres_dwh": {
    "conn_type": "postgres",
    "host": "postgres-dwh",
    "port": 5432,
    "schema": "dwh",
    "login": "admin",
    "password": "postgres",
    "description": "Connection to DWH Postgres (postgres-dwh)"
  },
  "airflow_db": {
    "conn_type": "postgres",
    "host": "postgres",
    "port": 5432,
    "schema": "airflow",
    "login": "airflow",
    "password": "airflow",
    "description": "Airflow metadata database"
  },
  "nocodb_api": {
    "conn_type": "http",
    "host": "noco-db",
    "port": 8080,
    "login": "admin@example.com",
    "password": "admin123",
    "description": "NocoDB API connection"
  },
  "redis_default": {
    "conn_type": "redis",
    "host": "redis",
    "port": 6379,
    "description": "Redis connection"
  }
}
```

#### Как настроить подключения под себя

| Поле в `connections.json` | Соответствует в `.env` | Описание |
|---|---|---|
| `postgres_dwh` → `login` / `password` | `DWH_USER` / `DWH_PASSWORD` | Креды DWH Postgres |
| `postgres_dwh` → `schema` | — | Имя БД DWH (по умолчанию `dwh`) |
| `airflow_db` → `login` / `password` | `AIRFLOW_DB_USER` / `AIRFLOW_DB_PASSWORD` | Креды metadata-БД Airflow |
| `airflow_db` → `schema` | `AIRFLOW_DB_NAME` | Имя БД Airflow |
| `nocodb_api` → `login` / `password` | `NOCODB_ADMIN_EMAIL` / `NOCODB_ADMIN_PASSWORD` | Креды NocoDB |

> **`host` в подключениях** — это имя Docker-контейнера в сети `dwh_network`, **не** `localhost`. Менять не нужно.

### Шаг 4. Запуск

```bash
docker compose up -d --build
```

Сборка образов занимает 5–10 минут при первом запуске.
Контейнер `airflow-init` автоматически:
1. Выполнит миграции БД Airflow
2. Импортирует подключения из `connections.json`
3. Создаст admin-пользователя

> **Важно:** Виртуальное окружение Python на хосте (`.venv`) **не требуется** для запуска контейнеров. Все зависимости (dlt, dbt, duckdb, pandas и др.) уже установлены внутри Docker-образа через `requirements.txt`. Достаточно одной команды `docker compose up -d --build`.

### Локальная разработка (опционально)

Если вы хотите запускать dbt или Python-скрипты **на хосте** (например, для быстрой разработки dbt-моделей без пересборки контейнера), создайте виртуальное окружение:

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

> `requirements.txt` содержит только пакеты, которые ставятся из коробки без системных библиотек. Для работы с MS SQL (`pyodbc`, `pymssql`) см. `requirements_mac.txt` / `requirements_win.txt` — они требуют установки `unixodbc` и `freetds` через `brew install unixodbc freetds` (macOS).

#### Настройка dbt-проекта

После установки зависимостей инициализируйте dbt-проект:

```bash
dbt init dbt_dwh --profiles-dir ./dbt_dwh
```

На вопросы интерактивного мастера ответьте:

| Параметр | Значение |
|---|---|
| Adapter | `postgres` |
| Host | `localhost` |
| Port | `5432` |
| Database | `dwh` |
| Username | `admin` |
| Password | `postgres` |
| Schema | `dds` |
| Threads | `4` |

dbt создаст:
- Папку `dbt_dwh/` с базовой структурой проекта (`dbt_project.yml`, `models/`, `macros/`, ...)
- Файл `dbt_dwh/profiles.yml` с настройками подключения

> **Важно:** `profiles.yml` хранится **внутри проекта** (`dbt_dwh/profiles.yml`), а не в `~/.dbt/`. Это делает проект самодостаточным. Переменная `DBT_PROFILES_DIR` уже настроена в `.envrc` через direnv.

#### Подключение через переменные окружения

Вместо хардкода кредов в `profiles.yml` используются переменные окружения из `.env`. Для этого в `profiles.yml` применяется функция `env_var()`:

```yaml
dbt_dwh:
  outputs:
    dev:
      type: postgres
      host: "{{ env_var('DWH_HOST', 'localhost') }}"
      port: "{{ env_var('DWH_PORT', '5432') | int }}"
      database: "{{ env_var('DWH_DB_NAME', 'dwh') }}"
      schema: "{{ env_var('DWH_SCHEMA', 'dds') }}"
      user: "{{ env_var('DWH_USER') }}"
      password: "{{ env_var('DWH_PASSWORD') }}"
      threads: 4
  target: dev
```

Соответствие переменных:

| Переменная в `.env` | Значение по умолчанию | Назначение |
|---|---|---|
| `DWH_USER` | `admin` | Пользователь DWH Postgres |
| `DWH_PASSWORD` | `postgres` | Пароль DWH Postgres |
| `DWH_DB_NAME` | `dwh` | Имя базы данных |
| `DWH_HOST` | `localhost` | Хост (для локальной разработки) |
| `DWH_PORT` | `5432` | Порт |
| `DWH_SCHEMA` | `dds` | Схема по умолчанию |

Переменные загружаются автоматически через [direnv](https://direnv.net/) (файл `.envrc` → `dotenv`). Если direnv не установлен, экспортируйте переменные вручную:

```bash
export $(grep -v '^#' .env | xargs)
```

#### Проверка подключения (dbt debug)

Перейдите в папку проекта и проверьте, что dbt корректно подключается к DWH:

```bash
cd dbt_dwh
dbt debug
```

В выводе должно быть:
```
Connection test: [OK connection ok]
All checks passed!
```

Если dbt не находит `profiles.yml` — проверьте, что переменная `DBT_PROFILES_DIR` указывает на папку `dbt_dwh/`:

```bash
echo $DBT_PROFILES_DIR
# должно быть: /Users/<user>/VSCode/modern_data_stack_lab/dbt_dwh
```

Либо укажите путь явно:

```bash
dbt debug --profiles-dir .
```

#### Запуск dbt-моделей

```bash
cd dbt_dwh

# Запуск всех моделей
dbt run --target dev

# Запуск тестов
dbt test --target dev

# Генерация документации
dbt docs generate --target dev
dbt docs serve --target dev

## Основные команды dbt

- `dbt debug` - проверка подключения к хранилищу данных (проверка профиля)
- `dbt parse` - парсинг файлов проекта (проверка корректности)
- `dbt compile` - компилирует dbt-модели и создает SQL-файлы
- `dbt run` - материализация моделей в таблицы и представления
- `dbt test` - запускает тесты для проверки качества данных
- `dbt seed` - загружает данные в таблицы из CSV-файлов
- `dbt build` - основная команда, комбинирует run, test и seed
- `dbt docs generate` - генерирует документацию проекта
- `dbt docs serve` - запускает локальный сервер для просмотра документации
```

> **Важно:** все команды dbt выполняются **из папки `dbt_dwh/`**, где находятся `dbt_project.yml` и `profiles.yml`.

### Шаг 5. Проверка

После запуска убедитесь, что все сервисы здоровы:

```bash
docker compose ps
```

Доступные интерфейсы:

| Сервис | URL | Логин | Пароль |
|---|---|---|---|
| Airflow UI | http://localhost:8080 | `admin` | `airflow` |
| NocoDB | http://localhost:8081 | `admin@example.com` | `admin123` |
| DWH Postgres | localhost:5432 | `admin` | `postgres` |
| Airflow DB | localhost:5433 | `airflow` | `airflow` |

Подключения в Airflow (Admin → Connections):

| Connection ID | Тип | Host | Порт |
|---|---|---|---|
| `postgres_dwh` | postgres | postgres-dwh | 5432 |
| `airflow_db` | postgres | postgres | 5432 |
| `nocodb_api` | http | noco-db | 8080 |
| `redis_default` | redis | redis | 6379 |

## Структура проекта

```
modern_data_stack_lab/
├── .env                  # Переменные окружения (создать вручную, в .gitignore)
├── .envrc                # direnv
├── .gitignore
├── compose.yaml          # Docker Compose конфигурация
├── connections.json      # Airflow connections (создать вручную, в .gitignore)
├── requirements.txt      # Python-зависимости для Airflow-образа
├── requirements_mac.txt  # macOS-специфичные пакеты
├── requirements_win.txt  # Windows-специфичные пакеты
├── load_env.ps1          # Скрипт загрузки .env для PowerShell (Windows)
├── docker/
│   ├── airflow.dockerfile
│   └── postgres.dockerfile
├── raw/                  # Исходные данные (CSV, файлы)
├── dbt_dwh/              # dbt-проект (локальная разработка)
│   ├── dbt_project.yml
│   ├── profiles.yml      # настройки подключения dbt
│   ├── models/
│   ├── macros/
│   └── ...
├── dags/                 # DAG-файлы Airflow
├── sql/                  # SQL-скрипты инициализации БД
│   ├── 01_init_schemas.sql
│   └── README.md         # Описание схем DWH
├── logs/                 # Логи Airflow
├── config/               # Конфигурация Airflow
└── plugins/              # Кастомные плагины Airflow
```

## Управление окружением

```bash
# Запуск
docker compose up -d --build

# Остановка (данные сохраняются в volumes)
docker compose down

# Остановка с удалением данных
docker compose down -v

# Логи конкретного сервиса
docker compose logs -f airflow-webserver

# Подключение к DWH Postgres извне
psql -h localhost -p 5432 -U admin -d dwh

# Airflow CLI (debug-профиль)
docker compose run --rm airflow-cli
```

## Подключение к базам данных

### Параметры подключения

В проекте две PostgreSQL-базы данных:

#### 1. DWH Postgres (хранилище данных)

| Параметр | Значение (извне) | Значение (из контейнеров) |
|---|---|---|
| Host | `localhost` | `postgres-dwh` |
| Port | `5432` | `5432` |
| Database | `dwh` | `dwh` |
| User | `admin` | `admin` |
| Password | `postgres` | `postgres` |

#### 2. Airflow DB (метаданные Airflow)

| Параметр | Значение (извне) | Значение (из контейнеров) |
|---|---|---|
| Host | `localhost` | `postgres` |
| Port | `5433` | `5432` |
| Database | `airflow` | `airflow` |
| User | `airflow` | `airflow` |
| Password | `airflow` | `airflow` |

### Подключение через DBeaver

1. Откройте [DBeaver](https://dbeaver.io/download/)
2. Нажмите **New Connection** (иконка розетки с плюсиком)
3. Выберите **PostgreSQL**
4. Заполните параметры:

**Для DWH Postgres:**
- **Host:** `localhost`
- **Port:** `5432`
- **Database:** `dwh`
- **Username:** `admin`
- **Password:** `postgres`

**Для Airflow DB:**
- **Host:** `localhost`
- **Port:** `5433`
- **Database:** `airflow`
- **Username:** `airflow`
- **Password:** `airflow`

5. Нажмите **Test Connection** — должно появиться "Connected"
6. Нажмите **Finish**

> Если DBeaver просит скачать драйвер — согласитесь (скачается автоматически).

### Подключение через psql

```bash
# DWH Postgres
psql -h localhost -p 5432 -U admin -d dwh
# пароль: postgres

# Airflow DB
psql -h localhost -p 5433 -U airflow -d airflow
# пароль: airflow
```

### Инициализация схем DWH

После запуска контейнеров выполните инициализацию схем:

```bash
psql -h localhost -p 5432 -U admin -d dwh -f sql/01_init_schemas.sql
```

Будут созданы схемы:

| Схема | Назначение |
|---|---|
| `raw` | Сырые данные — загрузка через dlt |
| `stage` | Очищенные данные — dbt staging |
| `dds` | Размерности и факты — dbt dimensional |
| `mart` | Витрины данных — dbt marts |

Подробнее — в `sql/README.md`.

## Безопасность

- `.env` и `connections.json` добавлены в `.gitignore` — секреты не попадают в репозиторий
- Все креды в `compose.yaml` ссылаются на переменные из `.env` через `${...}`
- Dockerfile'ы не содержат кредов
- Fernet-ключ шифрует подключения в metadata-БД Airflow