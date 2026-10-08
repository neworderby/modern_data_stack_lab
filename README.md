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
direnv allow .
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

# Основные команды dbt

- `dbt debug` - проверка подключения к хранилищу данных (проверка профиля)
- `dbt parse` - парсинг файлов проекта (проверка корректности)
- `dbt compile` - компилирует dbt-модели и создает SQL-файлы
- `dbt run` - материализация моделей в таблицы и представления
- `dbt test` - запускает тесты для проверки качества данных
- `dbt seed` - загружает данные в таблицы из CSV-файлов
- `dbt build` - основная команда, комбинирует run, test и seed
- `dbt docs generate` - генерирует документацию проекта
- `dbt docs serve` - запускает локальный сервер для просмотра документации
- `dbt compile` - компилирует шаблонизированные модели в полноценные SQL-скрипты
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

## Каталог данных (GitHub Pages)

Каталог dbt публикуется автоматически и доступен по ссылке:

**https://neworderby.github.io/modern_data_stack_lab/**

### Как работает автопубликация

Пайплайн настроен в `.github/workflows/deploy_docs.yml`. Схема:

```
git push в main
  → self-hosted runner на локальной машине принимает job
  → dbt docs generate (подключение к локальному Docker Postgres, localhost:5432)
  → артефакты (index.html, manifest.json, catalog.json)
  → коммит в ветку gh-pages
  → GitHub Pages публикует сайт (~1-2 минуты)
```

Ветка `gh-pages` создаётся и обновляется **автоматически** экшеном
`peaceiris/actions-gh-pages` — вручную её трогать не нужно.

### Self-hosted runner

Воркфлоу выполняется на локальной машине (`runs-on: self-hosted`), поэтому dbt
подключается к локальному Docker Postgres с кредами из `profiles.yml`
(дефолты `admin`/`postgres` зашиты в воркфлоу через `||`).

Runner установлен в `~/VSCode/modern_data_stack_lab/actions-runner/`
(добавлен в `.gitignore`, в репозиторий не попадает).

```bash
# Запуск runner (должен работать во время деплоя)
cd ~/VSCode/modern_data_stack_lab/actions-runner
./run.sh          # ждать "Listening for Jobs", терминал не закрывать

# Как фоновый сервис (переживает закрытие терминала и перезагрузку)
sudo ./svc.sh install
sudo ./svc.sh start
```

Важно: каталог обновляется только при работающем runner. Если машина выключена,
job копится в очереди и выполнится при следующем запуске runner.

### Настройка Pages (один раз)

Settings → Pages → Build and deployment:
- Source: **Deploy from a branch**
- Branch: **gh-pages** / `/ (root)`

### Локальный просмотр документации

Локально каталог можно смотреть без пуша (см. раздел «Документация dbt» ниже):
`dbt docs serve --port 8085` или `open dbt_dwh/target/index.html`.

## Бэклог проекта

Идеи по развитию стека — по мере завершения трека:

### Витрина репозитория

Чтобы проект можно было отправить ссылкой, без экскурсии по журналу. Делать по порядку, текущие модели не переписывать.

- [ ] Короткий вход в README: какие данные, какие слои, одна команда `dbt build`, ссылка на каталог. MetricFlow, порты и collation остаются ниже.
- [ ] `dbt build` в том же DAG, что и загрузка `raw` (`dags/load_scooters_raw.py`), чтобы контур не обрывался на сырье.
- [ ] CI без личного пути `/Users/daniil/.../.venv/bin/dbt`: на пуше гоняется `dbt build`, не только публикация docs с self-hosted runner.
- [ ] Выровнять версии: `dbt-core` 1.10.23 при `dbt-postgres` 1.9.0.
- [ ] Разложить модели по папкам слоёв (`staging` / `marts`) и поправить кривые имена (`trips_concurency` и описания в YAML без SQL-файла).
- [ ] Почистить `requirements.txt`: оставить пакеты, без которых проект не ставится, убрать следы полного `pip freeze` (Jupyter и прочее).

### BI-слой: Superset (в приоритете) или Redash

Добавить BI-инструмент контейнером в `compose.yaml` и собрать дашборд на март-моделях —
замкнёт цикл: source → dlt → dbt → mart → **дашборд**.

- **Superset** (приоритет): современный стек, чаще используется,
  богатые визуализации (40+ типов), кросс-фильтры. Использует Redis как кэш —
  он уже есть в compose (для Airflow Celery). Порт **8088** свободен. Минус: ~1.5–2 ГБ RAM.
- **Redash**: легче (~1 ГБ RAM), но менее продвинутый функционал дашбордов.

Планируемые дашборды на готовых март-моделях:

| Дашборд | Источник | Визуализация |
|---|---|---|
| Выручка по дням | `finance.revenue_daily` | линейный график |
| Поездки по возрастным группам | `trips_age_group` | stacked bar |
| Активность самокатов по районам | `trips_geom` | map |
| Воронка событий пользователей | `events_stat` | воронка (search → book → release) |

После подключения BI — добавить в `dbt_dwh/models/finance/properties.yml` exposure
`superset_financial_dashboard` (`depends_on: revenue_daily`), чтобы связь
«модель → дашборд» была видна в каталоге данных.

### Cube — по желанию, после MetricFlow и BI

Не второй обязательный семантический слой. MetricFlow уже задаёт метрики и размерности внутри dbt и отвечает через `mf query`. Cube — отдельный сервис перед хранилищем: те же меры и размерности, но с API (SQL, REST) и коннекторами к BI. Имеет смысл, только если дашборд или чат должны спрашивать «выручка по компании» по имени метрики, а не копировать SQL.

Один куб на `scooters` или `trips_users`, один запрос, без переноса всех метрик. Два полных каталога (MetricFlow и Cube) в этой лабе не вести.

### Другие идеи

- pytest-тесты для Python-кода (DAG'и, пайплайны) + CI-джоба в GitHub Actions
- Диаграмма архитектуры (mermaid) в README
- Рефакторинг `s3_pipeline/filesystem_pipeline.py` (убрать копипасту из примера dlt)

## Семантический слой (MetricFlow)

Метрики считаются поверх модели `trips_users` через MetricFlow. Описание лежит в YAML, CLI `mf` читает уже собранный `target/manifest.json`, а не файлы напрямую.

Команды ниже запускаются из `dbt_dwh/`, с активированным `.venv`.

### Установка

В задании пакет ставится через `uv add`. В этом репозитории зависимости живут в `requirements.txt`, поэтому пакет зафиксирован там и установлен в `.venv`:

```text
dbt-metricflow[dbt-postgres]==0.10.1
```

```bash
pip install "dbt-metricflow[dbt-postgres]==0.10.1"
mf --version    # mf, version 0.10.1
```

MetricFlow 0.10.1 требует `dbt-core>=1.10.4`, поэтому ядро поднялось с 1.9.6 до **1.10.23**. Адаптер `dbt-postgres` остался 1.9.0: `dbt --version` предупреждает, что плагин отстаёт от ядра. Для `mf` это не мешает.

Профиль копировать из `~/.dbt/` не нужно. `dbt_dwh/profiles.yml` уже лежит в каталоге проекта, пароль читается через `env_var()`, а `DBT_PROFILES_DIR` в `.envrc` указывает на `dbt_dwh/`. MetricFlow 0.10.1 не смотрит в `~/.dbt/profiles.yml`, но файл в текущей папке он видит. В `.gitignore` этот `profiles.yml` не добавлять.

### Time spine

Семантический слой требует модель-календарь с гранулярностью день или мельче.

`dbt_dwh/models/time_spine_daily.sql` строит даты через `dbt.date_spine` с 2023-06-01 по 2023-08-31 и отдаёт колонку `date_day`.

Конфиг обязан быть в секции `models:`, файл `dbt_dwh/models/time_spine_daily.yml`:

```yaml
models:
  - name: time_spine_daily
    config:
      materialized: "table"
    time_spine:
      standard_granularity_column: date_day
    columns:
      - name: date_day
        granularity: day
```

Если тот же блок положить в `seeds/properties.yml` под ключ `seeds:`, dbt видит SQL как модель и конфиг игнорирует. Тогда `dbt run` падает: `The semantic layer requires a time spine model with granularity DAY or smaller`.

```bash
dbt run -s time_spine_daily
```

### Семантическая модель и метрики

Файл `dbt_dwh/models/metrics/trips_users_metrics.yml`.

Семантическая модель `trips_users_metrics` смотрит на `ref('trips_users')`.

| Блок | Что задано |
|---|---|
| entities | `trip` (primary, `id`), `user` (foreign, `user_id`), `scooter` (foreign, `scooter_hw_id`) |
| dimensions | категориальные `sex`, `age`, `is_free`; временные `started_at` и `finished_date` с гранулярностью `day` |
| defaults | `agg_time_dimension: started_at` |
| measures | `revenue_sum` (sum `price_rub`), `users_count` (count_distinct `user_id`), `revenue_avg` (average `price_rub`), `trips_count` (count `id`), `free_trips_count` (sum_boolean `is_free`), `duration_m_median` (median `duration_s / 60.0`) |

У мер `revenue_sum`, `users_count`, `trips_count`, `free_trips_count` и `duration_m_median` стоит `create_metric: true`: MetricFlow сам заводит метрику с тем же именем. `revenue_avg` как мера метрику не создаёт, она объявлена отдельно и только по платным поездкам.

Явные метрики:

| Метрика | Тип | Смысл |
|---|---|---|
| `revenue_avg` | simple | средняя выручка, фильтр `Dimension('trip__is_free') = false` |
| `revenue_cumsum` | cumulative | накопленная выручка по мере `revenue_sum`, тот же фильтр платных поездок |
| `users_count_growth_mom` | derived | рост уникальных пользователей к прошлому месяцу: `(users_count - users_count_prev_month) * 100 / users_count_prev_month`, смещение `offset_window: 1 month` |
| `trips_per_scooter` | ratio | `trips_count / scooters_count`. Числитель — все поездки, знаменатель — метрика из модели `scooters_metrics` |

Имя измерения в фильтре — `сущность__измерение`, поэтому `is_free` пишется как `trip__is_free`.

Вторая модель — справочник самокатов, файл `dbt_dwh/models/metrics/scooters_metrics.yml`. Она смотрит на сид `ref('scooters')`. В CSV нет даты, поэтому временная размерность `actual_at` задана выражением `date(now())` и указана в `defaults.agg_time_dimension`. Сущность `scooter` (primary, `hardware_id`) совпадает с foreign-сущностью `scooter` в `trips_users_metrics`, по ней модели соединяются.

Меры справочника и колонки сида — разные имена. В CSV парк лежит в колонке `trips` (`sum(trips) as scooters` есть только в модели `companies`). В мере `expr` должен быть `trips`, а имя метрики — `scooters_count`. Иначе запрос падает с `column "scooters" does not exist`.

| Мера | Агрегация | Колонка сида |
|---|---|---|
| `scooters_count` | sum | `trips` |
| `models_count` | count_distinct | `model` |
| `companies_count` | count_distinct | `company` |

### Проверка

`mf` смотрит в `target/manifest.json`. После правки YAML сначала пересобрать манифест, иначе проверка читает старый файл и пишет `No metrics present in the model`.

```bash
dbt parse
mf health-checks       # SELECT 1 к Postgres
mf validate-configs    # семантика, модели, измерения, сущности, меры, метрики
```

Успешный прогон заканчивается `ERRORS: 0` на каждом шаге `validate-configs`.

Дальше семантический слой смотрят командами `mf`, без SQL.

Список метрик и доступных им размерностей:

```bash
mf list metrics
```

Список длиннее семи: к метрикам поездок добавились `trips_count`, `trips_per_scooter` и три метрики справочника (`scooters_count`, `models_count`, `companies_count`). У метрик поездок в коротком списке размерности `metric_time`, `trip__age`, `trip__finished_date`, `trip__is_free`, `trip__sex` и ещё одна (`trip__started_at`). У справочника размерности идут с префиксом `scooter__`.

Размерности одной метрики:

```bash
mf list dimensions --metrics revenue_sum
```

Это пять измерений семантической модели плюс служебная `metric_time`. Она смотрит на временное измерение по умолчанию, то есть на `started_at`:

```text
metric_time
trip__age
trip__finished_date
trip__is_free
trip__sex
trip__started_at
```

Какие значения бывают у размерности:

```bash
mf list dimension-values --metrics revenue_sum --dimension trip__sex
```

### Запросы метрик

Срезы считаются командой `mf query`. SQL писать не нужно: MetricFlow собирает запрос по метрике и группировкам.

Суммарная выручка за всё время:

```bash
mf query --metrics revenue_sum
```

```text
  revenue_sum
-------------
  2.33882e+07
```

`2.33882e+07` — это около 23.4 млн рублей. Ответ приходит не из готового кэша: CLI компилирует запрос и ходит в Postgres. На этом прогоне успешный запрос занял 0.21 с. Для разовой аналитики этого достаточно.

Та же метрика по дням. Группировка и сортировка идут по `trip__started_at` — это измерение `started_at` сущности `trip`, оно же время по умолчанию (`metric_time`):

```bash
mf query --metrics revenue_sum --group-by trip__started_at --order trip__started_at
```

Несколько метрик в одном запросе перечисляют через запятую. Чтобы свернуть время не по дню, а по месяцу, к измерению дописывают гранулярность: `trip__started_at__month`.

```bash
mf query --metrics revenue_avg,revenue_sum,revenue_cumsum --group-by trip__started_at__month --order trip__started_at__month
```

`revenue_avg` здесь — средняя выручка только платных поездок, `revenue_sum` — сумма за месяц, `revenue_cumsum` — накопленная сумма от начала календаря time spine. Тот же суффикс работает и для других гранулярностей, которые есть у измерения (`__week`, `__quarter`, `__year`).

Прирост уникальных пользователей к прошлому месяцу, отдельно по полу. В `--group-by` несколько размерностей перечисляют через запятую:

```bash
mf query --metrics users_count,users_count_growth_mom --group-by trip__started_at__month,trip__sex --order trip__started_at__month
```

`users_count` — число пользователей в этом месяце и поле, `users_count_growth_mom` — процент к тому же срезу месяц назад. У июня предыдущего месяца в time spine нет, поэтому прирост там `None`. Отдельная строка `trip__sex = None` — поездки без указанного пола.

```text
trip__started_at__month    trip__sex      users_count  users_count_growth_mom
-------------------------  -----------  -------------  ------------------------
2023-06-01T00:00:00        F                      834  None
2023-06-01T00:00:00        M                      836  None
2023-06-01T00:00:00        None                   201  None
2023-07-01T00:00:00        F                      840  0.72
2023-07-01T00:00:00        M                      836  0.00
2023-07-01T00:00:00        None                   200  -0.50
2023-08-01T00:00:00        F                      819  -1.80
2023-08-01T00:00:00        M                      821  -1.68
2023-08-01T00:00:00        None                   203  1.50
```

Число бесплатных поездок и медианная длительность по возрасту. `free_trips_count` считает только поездки с `is_free`, это не все поездки. Все поездки — отдельная метрика `trips_count`.

```bash
mf query --metrics free_trips_count,duration_m_median --group-by trip__age --order trip__age
```

На выходе строка на каждый возраст: сколько бесплатных поездок и медиана длительности в минутах.

### Справочник самокатов и связь двух моделей

После правки YAML снова `dbt parse`, затем запросы. Размерности справочника называются `scooter__колонка`, потому что сущность в модели — `scooter`.

Сколько самокатов в парке всего (`scooters_count` суммирует колонку `trips`):

```bash
mf query --metrics scooters_count
```

```text
  scooters_count
----------------
            4479
```

Тот же парк и число моделей по производителю:

```bash
mf query --metrics scooters_count --group-by scooter__company
mf query --metrics models_count --group-by scooter__company
```

```text
scooter__company      scooters_count
------------------  ----------------
Spin                             466
Segway-Ninebot                  1367
Unagi                            466
Xiaomi                          1295
Skip                             445
GoTrax                           440
```

Поездок на один самокат. Это ratio `trips_count / scooters_count`: поездки берутся из `trips_users`, парк из сида, соединение по `hardware_id`.

```bash
mf query --metrics trips_per_scooter --group-by scooter__company
```

```text
scooter__company      trips_per_scooter
------------------  -------------------
GoTrax                          23.7136
Segway-Ninebot                  23.5852
Skip                            23.1213
Spin                            23.4506
Unagi                           24.0064
Xiaomi                          23.8008
```

Поездки мужчин по модели, по убыванию числа поездок. `--where` принимает то же выражение `Dimension`, что и фильтр в YAML. Минус перед именем в `--order` — сортировка по убыванию.

```bash
mf query --metrics trips_count --group-by scooter__model --order -trips_count --where "{{Dimension('trip__sex')}}='M'"
```

Посмотреть SQL, который MetricFlow собрал, без выполнения выборки в виде таблицы:

```bash
mf query --metrics trips_per_scooter --group-by scooter__company --explain
```

Записать результат в CSV в текущей папке:

```bash
mf query --metrics trips_per_scooter --group-by scooter__company --csv data.csv
```

Предупреждения, которые этот прогон не ломают:

- предложение обновиться до MetricFlow 0.15.0 — курс зафиксирован на 0.10.1;
- `database "dwh" has a collation version mismatch` — база создана с collation 2.36, а в ОС библиотека 2.31.

На dbt 1.10 аргументы generic-тестов нужно класть во вложенный ключ `arguments:`. Плоская запись (`columns:` сразу под именем теста) на 1.9 была обязательной, на 1.10 даёт `MissingArgumentsPropertyInGenericTestDeprecation`.

## Схема `ops`, скаляр на компиляции и инкремент по дате

Команды ниже запускаются из `dbt_dwh/`, с активированным `.venv`. В этом прогоне `DWH_SCHEMA=raw`, поэтому модели без своей схемы садятся в `raw`, а `finance` — в `raw_finance`.

### Схема без префикса target

Макрос `generate_schema_name` оставляет имя схемы как есть для `ops`. Остальные кастомные схемы получают префикс target: `finance` становится `raw_finance`.

Сид регламентов ТО лежит в `dbt_dwh/seeds/ops/maintenance_policies.csv`, в `dbt_project.yml` у папки `ops` стоит `+schema: ops`.

```bash
dbt seed -s maintenance_policies
```

```text
1 of 1 OK loaded seed file ops.maintenance_policies ................ [INSERT 5 in 0.09s]
```

Пять строк справочника:

```bash
dbt show --inline "select service_code, interval_km, interval_days from {{ ref('maintenance_policies') }} order by interval_km"
```

```text
service_code      interval_km    interval_days
--------------  -------------  ---------------
TIRE_CHECK                200               14
BRAKE_CHECK               300               30
SAFETY_INSPECT            500               60
BOLT_TIGHTEN              800               90
BATTERY_HEALTH           1000              120
```

В манифесте рядом три разных схемы: `ops.maintenance_policies`, `raw.events_clean_v2`, `raw_finance.revenue_daily`.

### Скаляр из запроса: `select_first_value`

Макрос на этапе выполнения делает `run_query` и возвращает первое значение первой колонки. Его вызывают инкремент и тест ниже. Проверка на константе:

```bash
dbt show --inline "select {{ select_first_value('select 111') }} * 2 as result"
```

```text
  result
--------
     222
```

Файл макроса должен содержать `{% macro select_first_value %}`. Пустой `.sql` dbt не регистрирует, и та же команда падает с `'select_first_value' is undefined`. Запись в `macros/properties.yml` макрос не создаёт.

### Инкремент `events_clean_v2`

`events_prep` — view: события `raw.events` плюс колонка `date` из `timestamp`. `events_clean_v2` — incremental merge по `user_id`, `timestamp`, `type_id`. Окно дат задаёт `incremental_date_condition`. Параметры по умолчанию лежат в `meta.incrementality` модели:

```yaml
incrementality:
  start_date: "2023-06-01"
  days_max: 60
```

`days_back_from_today` в мете не задан, макрос берёт 1: верхняя граница `current_date - 1 day`. Значения читает `get_meta_value` из графа dbt. Отдельной команды у него нет.

Первая загрузка (`--full-refresh` или пустая таблица). Условие из `dbt compile -s events_clean_v2 --full-refresh`:

```sql
"date" >= date '2023-06-01'
and "date" < date '2023-06-01' + interval '60 day'
and "date" <= current_date - interval '1 day'
```

Сейчас в `raw.events_clean_v2` уже 322747 строк, даты с 2023-06-01 по 2023-08-30. В `raw.events` 338884 строк и тот же максимум, 2023-08-30. Следующий прогон без переменных берёт `max("date") + 1 day` и сливает пустое окно:

```bash
dbt run -s events_clean_v2
```

```text
1 of 1 OK created sql incremental model raw.events_clean_v2  [MERGE 0 in 0.29s]
```

Один конкретный день переписывает переменная `date`. Она отменяет и мету, и продолжение с `max("date")`:

```bash
dbt run -s events_prep events_clean_v2 --vars '{date: "2023-08-30"}'
```

```text
1 of 2 OK created sql view model raw.events_prep          [CREATE VIEW in 0.16s]
2 of 2 OK created sql incremental model raw.events_clean_v2 [MERGE 3768 in 0.24s]
```

Своё окно, короче 60 дней из меты:

```bash
dbt compile -s events_clean_v2 --vars '{start_date: "2023-07-01", days_max: 7}'
```

```sql
"date" >= date '2023-07-01'
and "date" < date '2023-07-01' + interval '7 day'
and "date" <= current_date - interval '1 day'
```

### Уникальность ключа из `meta`

Тест `unique_key_meta` берёт список колонок из `meta.unique_key` модели, а не из аргументов теста. На `events_full` ключ — `user_id`, `timestamp`, `type_id`. В `meta.testing` стоит `days_max: 60`: проверяются строки с `date` не старше 60 дней от максимума в таблице. Колонка `date` для этого добавлена во view `events_full`.

```bash
dbt run -s events_full
dbt test -s events_full
```

```text
1 of 2 PASS events_full_is_complete           [PASS in 0.18s]
2 of 2 PASS unique_key_meta_events_full_      [PASS in 0.34s]
```

## Документация dbt (docs generate / serve)

dbt умеет генерировать интерактивную документацию по моделям, sources, seeds и тестам:

```bash
cd dbt_dwh
dbt docs generate     # соберёт target/index.html и target/catalog.json
dbt docs serve        # поднимет локальный сервер с документацией
```

### ⚠️ Конфликт портов с Airflow

`dbt docs serve` по умолчанию использует порт **8080** — тот же, что и Airflow Webserver
(см. таблицу сервисов выше). При запуске поверх работающего Airflow появится ошибка:

```
OSError: [Errno 48] Address already in use
```

Airflow менять не нужно — запустите документацию на другом порту:

```bash
dbt docs serve --port 8085
```

Документация будет доступна на `http://localhost:8085`.

Занятые порты в этом проекте: **8080** (Airflow UI), **8081** (NocoDB), **5432/5433** (Postgres).
Свободный порт можно проверить командой:

```bash
lsof -iTCP -sTCP:LISTEN -P -n | grep -E '80[0-9][0-9]'
```

### 🧟 «Полумёртвый» docs-сервер: порт занят, но документация не открывается

Отдельная ловушка: если ранее `dbt docs serve` был запущен из **другого окружения**
(например, глобальный dbt более новой версии) и остался висеть в фоне, он занимает порт,
но **не отвечает на HTTP-запросы** — браузер бесконечно «грузит», curl рвёт соединение
по таймауту. Такое случается, когда сервер ждёт артефакты формата новой версии dbt
(parquet в `target/index/`), которых в проекте нет (артефакты старого формата — JSON).

Диагностика:

```bash
# Кто занимает порт
lsof -iTCP:8090 -sTCP:LISTEN -P -n

# Что за процесс (смотрим cwd — у docs-сервера это dbt_dwh/target)
ps -p <PID> -o pid,command
lsof -p <PID> | grep target

# Проверка, отвечает ли сервер на HTTP (000/exit 56 = не отвечает)
curl -s -m 5 -o /dev/null -w "code=%{http_code}\n" http://127.0.0.1:8090/
```

Лечение — убить зависший процесс и перезапустить сервер нужной версией dbt:

```bash
kill <PID>
dbt docs serve --port 8090
```

### ⚠️ Два dbt в разных окружениях

В проекте dbt установлен в `.venv` (версия 1.10.23, поднята вместе с MetricFlow). Если в системе есть ещё один dbt
(например, установленный глобально через pip/homebrew), команды могут запускаться
разными версиями с разным поведением. Признак: предупреждения вида
`dbt docs generate is not supported. Use dbt compile --write-catalog` — это вывод
dbt 1.11+, а не 1.10.23 из `.venv`.

Перед работой проверяйте, какой dbt используется:

```bash
which dbt       # должно быть: .../modern_data_stack_lab/.venv/bin/dbt
dbt --version
```

### Альтернатива без сервера

Документация dbt — статический сайт, её можно открыть напрямую:

```bash
open dbt_dwh/target/index.html
```

Ограничение: при открытии через `file://` в некоторых браузерах могут не работать
поиск и граф lineage (ограничения CORS), поэтому вариант с `--port` надёжнее.

### Описание seeds через docs-блоки

Подробные описания справочных таблиц (seeds) хранятся в docs-блоках в папке
`dbt_dwh/macros/` (файлы `*.md` с блоками `{% docs <name> %} ... {% enddocs %}`)
и подключаются в YAML через `{{ doc('<name>') }}`. Пример — сид `event_types`
(маппинг `type_id` → название события), описание в
`dbt_dwh/macros/event_types_docs.md`.

## Полезные ссылки
- [Техники модульного моделирования данных](https://www.getdbt.com/blog/modular-data-modeling-techniques) — статья dbt Labs о том, как дробить монолитный SQL на читаемые слои (staging / intermediate / marts), именование моделей и отладка «modelneck».
- [Sources в dbt](https://docs.getdbt.com/docs/build/sources?version=2) — официальная документация по объявлению источников (`sources`), функции `{{ source() }}`, тестам и проверке freshness сырых таблиц.
- [Seeds в dbt](https://docs.getdbt.com/docs/build/seeds) — загрузка CSV из папки `seeds/` в DWH через `dbt seed`: справочники и маппинги под `ref()`, когда seeds уместны (и когда нет), тесты/документация и `--full-refresh` при смене колонок.
- [Postgres-конфиги dbt](https://docs.getdbt.com/reference/resource-configs/postgres-configs?version=2) — справочник по адаптеру Postgres: incremental-стратегии (`append`, `merge`, `delete+insert`, microbatch), индексы, unlogged-таблицы и materialized views.
- [Справочник `dbt_project.yml`](https://docs.getdbt.com/reference/dbt_project.yml?version=2) — полное описание главного конфиг-файла проекта: пути, материалзации, vars, quoting, hooks и префикс `+`.
- [Как структурировать dbt-проект](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview?version=2) — best practices dbt Labs по структуре папок и слоям моделей (staging → intermediate → marts) на примере Jaffle Shop.
- [Как стилизовать dbt-проекты](https://docs.getdbt.com/best-practices/how-we-style/0-how-we-style-our-dbt-projects?version=2) — руководство по code style: ясность, единообразие, whitespace, naming и автоматизация через форматтеры/линтеры.
- [Telegram-чат dbt & modern data stack](https://t.me/dbt_users) — русско-английское сообщество пользователей dbt (вопросы, обсуждения, вакансии с тегом `#job`).
- [Обзор References в документации dbt](https://docs.getdbt.com/reference/references-overview?version=2) — точка входа в справочники: конфиги проекта и адаптеров, команды, Jinja, артефакты и Semantic Layer.
- [dbt Community Forum (Discourse)](http://discourse.getdbt.com/) — форум сообщества: помощь по dbt, show & tell, обсуждения практик analytics engineering.
- [Incremental models (документация)](https://docs.getdbt.com/docs/build/incremental-models?version=2) — как настраивать инкрементальные модели: `is_incremental()`, `unique_key`, `--full-refresh`, `on_schema_change` и фильтры новых строк.
- [Incremental models in-depth (best practices)](https://docs.getdbt.com/best-practices/materializations/4-incremental-models?version=2) — подробный разбор инкрементальных материалзаций: cutoff по `updated_at`, lookback для late-arriving facts и когда делать full refresh.
- [Understanding dbt Incremental Strategies (Indicium)](https://medium.com/indiciumtech/understanding-dbt-incremental-strategies-part-1-2-22bd97c7eeb5) — статья Bruno Souza de Lima: сравнение стратегий `append`, `merge`, `delete+insert`, `insert_overwrite` и когда лучше остаться на full refresh.
- [Почему мы перешли на микробатчи dbt (Павел Рословец)](https://kinescope.io/vQEduLgJgyeqDzi9orZsTH) — видео (~43 мин) про стратегию microbatch на практике: упрощение больших таблиц, ограничения из коробки и доработка через макросы вместо `is_incremental`.
- [Always Use TIMESTAMP WITH TIME ZONE](https://justatheory.com/2012/04/postgres-use-timestamptz/) — классическая заметка David Wheeler: почему в Postgres почти всегда стоит хранить время как `timestamptz` (UTC + конвертация), как вставлять с зоной/`Z`, когда использовать `AT TIME ZONE`, и исключение для партиционирования.
- [Карта часовых поясов мира](https://upload.wikimedia.org/wikipedia/commons/e/ec/World_Time_Zones_Map.svg) — SVG-карта часовых поясов (Wikimedia): наглядная шпаргалка к обсуждению UTC / `timestamptz` и смещений регионов.
- [Справочник функций Jinja в dbt](https://docs.getdbt.tech/reference/dbt-jinja-functions) — каталог контекстных функций и переменных: `ref`, `source`, `var`, `env_var`, `this`, `target`, `run_query`, `adapter`, `modules` и др.
- [Jinja и макросы](https://docs.getdbt.tech/docs/build/jinja-macros) — как смешивать SQL с Jinja (`{% %}`, `{{ }}`), писать переиспользуемые макросы, управление пробелами и «dbtonic»-практики.
- [Функция `var()`](https://docs.getdbt.tech/reference/dbt-jinja-functions/var) — передача переменных из `dbt_project.yml` / CLI в модели через `var()`, значения по умолчанию и типичные ошибки компиляции.
- [Хуки и операции](https://docs.getdbt.tech/docs/build/hooks-operations) — `pre-hook` / `post-hook`, `on-run-start` / `on-run-end` и `dbt run-operation`: кастомный SQL (grants, UDF, vacuum и т.п.) в жизненном цикле dbt.
- [Пользовательские схемы](https://docs.getdbt.tech/docs/build/custom-schemas) — конфиг `schema` и макрос `generate_schema_name`: как dbt собирает `<target>_<custom>`, чтобы окружения не перетирали друг друга, и кастомизация под prod/dev/CI.
- [Конфиг `grants`](https://docs.getdbt.tech/reference/resource-configs/grants) — декларативные права доступа к моделям/seeds/snapshots при материализации (вместо ручных `GRANT` в post-hook), настройка в `dbt_project.yml` и на уровне ресурса.
- [Свойство `freshness`](https://docs.getdbt.com/reference/resource-properties/freshness) — справочник SLA свежести sources: `warn_after` / `error_after`, `loaded_at_field` / `loaded_at_query`, `filter` и иерархия конфигов для `dbt source freshness`.
- [Data tests (руководство)](https://docs.getdbt.com/docs/build/data-tests) — как писать и запускать тесты качества данных: generic vs singular, `dbt test`, кастомные generic-тесты и организация тестового слоя.
- [Конфиги data tests](https://docs.getdbt.com/reference/data-test-configs) — настройки тестов: `severity`, `where`, `store_failures`, `limit`, `fail_calc`, tags/`enabled` и приоритет YAML → `config()` → `dbt_project.yml`.
- [Свойство `data_tests`](https://docs.getdbt.com/reference/resource-properties/data-tests) — синтаксис объявления тестов в YAML на моделях/sources/seeds: встроенные `unique`, `not_null`, `accepted_values`, `relationships` и кастомные имена.
- [Конфиг `severity`](https://docs.getdbt.com/reference/resource-configs/severity) — `severity: error|warn` плюс пороги `error_if` / `warn_if`: когда падение теста — ошибка, а когда достаточно warning (например, «>10 дублей — warn, >1000 — error»).
- [Пакет `dbt_utils`](https://hub.getdbt.com/dbt-labs/dbt_utils/latest/) — официальный пакет утилит dbt Labs (v1.4.1): макросы вроде `generate_surrogate_key`, `union_relations`, `pivot` и доп. тесты (`expression_is_true` и др.); ставится через `packages.yml` + `dbt deps`.
- [Пакет `audit_helper`](https://hub.getdbt.com/dbt-labs/audit_helper/latest/) — пакет dbt Labs (v0.14.0, dbt `>=1.2`) для сверки двух выборок или таблиц: какие строки и колонки разошлись, а не только «число строк совпало». Нужен при переписывании модели, сравнении dev и prod и проверке, что рефакторинг не изменил результат.
- [Пакет `dbt_expectations`](https://hub.getdbt.com/metaplane/dbt_expectations/latest/) — пакет тестов в стиле Great Expectations (v0.10.10, репозиторий переехал с Calogica на Metaplane): expect-проверки диапазонов, форматов, распределений и других DQ-правил поверх dbt. Нужен dbt `>=1.7`.
- [Пакеты в dbt](https://docs.getdbt.com/docs/build/packages) — как подключать чужой код: `packages.yml`, hub / git / local, `dbt deps` и что попадает в `dbt_packages/`.
- [Команда `dbt deps`](https://docs.getdbt.com/reference/commands/deps) — установка зависимостей из `packages.yml`, lock-файл `package-lock.yml`, `--upgrade` и `--add-package`.
- [dbt Hub](https://hub.getdbt.com/) — реестр пакетов: версии, совместимость с dbt и готовый фрагмент для `packages.yml`.
- [Как собрать свой пакет](https://docs.getdbt.com/guides/building-packages?step=1) — гайд по публикации пакета: структура репозитория, `require-dbt-version`, интеграционные тесты, GitHub Pages для docs и добавление в Hub.
- [awesome-dbt](https://github.com/Hiflylabs/awesome-dbt) — курируемый список ресурсов и пакетов dbt (Hiflylabs).
- [Our top dbt packages pick (Astrafy)](https://astrafy.io/the-hub/blog/technical/our-top-dbt-packages-pick) — разбор пакетов по ролям: утилиты, тесты, аудит проекта, генераторы кода и наблюдаемость.
- [Пакет `dbt_date`](https://hub.getdbt.com/godatadriven/dbt_date/latest/) — макросы для дат (v0.21.0): date spine, периоды, финансовые календари. Актуальная версия требует dbt `>=1.10.5`.
- [Пакет `dbt_product_analytics`](https://hub.getdbt.com/mjirv/dbt_product_analytics/latest/) — макросы продуктовой аналитики (v0.3.1): сессии, воронки и срезы событий поверх событийной таблицы.
- [Пакет `elementary`](https://hub.getdbt.com/elementary-data/elementary/latest/) — наблюдаемость dbt (v0.26.0): аномалии, свежесть, объёмы, алерты и отчёт по результатам тестов.
- [Пакет `re_data`](https://hub.getdbt.com/re-data/re_data/latest/) — фреймворк надёжности данных (v0.11.0): метрики качества во времени и алерты. Заявлен диапазон dbt `>=1.0, <2.0`.
- [Пакет `dbt_artifacts`](https://hub.getdbt.com/brooklyn-data/dbt_artifacts/latest/) — складывает метаданные прогонов dbt (модели, тесты, время, результаты) в таблицы хранилища (v2.11.1).
- [Пакет `dbt_project_evaluator`](https://dbt-labs.github.io/dbt-project-evaluator/latest/) — проверка проекта на best practices dbt Labs (моделирование, тесты, документация, структура, производительность). Запуск: `dbt build --select package:dbt_project_evaluator`.
- [Пакет `dbt_meta_testing`](https://github.com/tnightengale/dbt-meta-testing) — требует покрытие тестами и описаниями через `required_tests` / `required_docs` в `dbt_project.yml`; проверка командой `dbt run-operation`.
- [Пакет `dbt-codegen`](https://github.com/dbt-labs/dbt-codegen) — генерация YAML для sources и моделей и черновиков base-моделей из уже лежащих в базе таблиц.
- [Семантические модели dbt](https://docs.getdbt.tech/docs/build/semantic-models) — из чего состоит модель MetricFlow: `model: ref()`, обязательный `defaults.agg_time_dimension`, сущности (`primary` / `foreign` как ключи соединения), измерения (`time` и `categorical`) и меры. Несколько семантических моделей могут ссылаться на один dbt-узел, если имена разные. Двойное подчёркивание в имени модели нельзя: `__` занято под `сущность__измерение`.
- [FAQ семантического слоя dbt](https://docs.getdbt.tech/docs/use-dbt-semantic-layer/sl-faqs) — зачем слой: одни определения метрик, MetricFlow сам собирает SQL и соединения между моделями. Важная граница: API и коннекторы к BI (Tableau, Excel и др.) входят в платный Semantic Layer dbt Cloud (Starter и выше). В dbt Core, как в этой лабе, метрики задаются в YAML и запрашиваются локально через `mf`, без этого API.
- [Команды MetricFlow](https://docs.getdbt.tech/docs/build/metricflow-commands) — справочник CLI: `list metrics`, `list dimensions`, `list dimension-values`, `query` (`--group-by`, `--where`, `--order`, `--explain`, `--csv`), `validate-configs`. После правки YAML нужен `dbt parse`: он обновляет `semantic_manifest.json`, модели заново не собирает. В dbt Cloud те же команды идут с префиксом `dbt sl`, не `mf`.
- [Что такое семантический слой (Dimodelo)](https://www.dimodelo.com/blog/2023/what-is-a-semantic-layer-what-why-how-and-more/) — зачем он бизнесу: общий словарь сущностей и метрик, чтобы отчёты не спорили из-за разных формул. Четыре вида: копия данных (Power BI, Druid), виртуальный слой без копии (Cube, LookML, MetricFlow — на запрос генерируется SQL), гибрид и «мета»-описание в dbt. Прямое подключение слоя к сырым источникам в обход склада автор считает слабой идеей.
- [Интеграция dbt и Cube](https://cube.dev/blog/introducing-dbt-integration-with-cube) — анонс октября 2023: пакет `cube_dbt` читает `manifest.json`, выбирает модели (например `models/marts/`) и разворачивает их в кубы с размерностями и типами колонок. Меры, соединения и предагрегации дописывают уже в Cube. Схема в статье та же, что в бэклоге: звезда собирается в dbt, метрики для BI и API отдаёт Cube.
- [Markdown Guide: Basic Syntax](https://www.markdownguide.org/basic-syntax/) — шпаргалка по синтаксису Markdown: заголовки, списки, таблицы, код-блоки, ссылки; основа для README и технической документации (включая docs-блоки dbt).
- [Free for Dev: Web Hosting](https://github.com/ripienaar/free-for-dev?tab=readme-ov-file#web-hosting) — большой каталог бесплатных сервисов для разработчиков (раздел web hosting): хостинг статики, PaaS, CDN и прочее — полезно, когда нужен бесплатный деплой пет-проекта.
- [GitHub Marketplace: Actions](https://github.com/marketplace?type=actions) — каталог готовых экшенов для GitHub Actions (деплой, кэширование, линтеры, релизы); перед использованием стороннего экшена смотрят звёзды, версию (`@v4`) и документацию — как с `peaceiris/actions-gh-pages` в этом проекте.
- [dbt Documentation (руководство)](https://docs.getdbt.com/docs/build/documentation) — как устроена документация dbt: docs-блоки `{% docs %}`, свойства в YAML, `dbt docs generate/serve` и автогенерируемый каталог с графом lineage.