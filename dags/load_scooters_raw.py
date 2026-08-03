"""
DAG: Загрузка сырых данных кикшеринга из S3 в DWH через dlt.

Источник: https://github.com/Inzhenerka/scooters_data_generator
Файлы загружаются напрямую из S3 (Amazon) в Postgres DWH (схема raw).

Поток данных:
    S3 → DuckDB (extract, чтение по HTTPS) → dlt (load) → Postgres (raw)

Стратегия: replace (полная замена таблиц при каждом запуске)
            — обеспечивает идемпотентность.

Таблицы:
    raw.trips       — поездки пользователей на самокатах (Parquet)
    raw.users       — пользователи кикшеринга (Parquet)
    raw.events      — события из мобильного приложения (Parquet)
    raw.payments    — оплаты поездок (Parquet)
    raw.weather     — погода (JSON)
    raw.mo_geojson  — границы МО (GeoJSON, целиком как text)
"""

import pendulum
from airflow import DAG
from airflow.operators.python import PythonOperator
import dlt
import duckdb
import requests

# Базовый URL к файлам на S3 (публичный бакет, доступ по HTTPS)
S3_BASE_URL = (
    "https://inzhenerka-public.s3.eu-west-1.amazonaws.com/scooters_data_generator"
)

# Списки таблиц по формату
TABLES_PARQUET = ["trips", "users", "events", "payments"]
TABLES_JSON = ["weather"]
TABLES_GEOJSON = ["mo"]


def load_parquet_to_raw(**context):
    """Читает Parquet-файлы из S3 через DuckDB и грузит в Postgres через dlt."""

    duck = duckdb.connect()

    for table_name in TABLES_PARQUET:
        url = f"{S3_BASE_URL}/{table_name}.parquet"

        # DuckDB умеет читать Parquet напрямую по HTTPS — без AWS-кредов
        arrow_table = duck.execute(f"SELECT * FROM '{url}'").fetch_arrow_table()
        row_count = arrow_table.num_rows
        print(f"[{table_name}] Extracted {row_count} rows from {url}")

        # dlt-пайплайн: назначение — Postgres, схема — raw
        pipeline = dlt.pipeline(
            pipeline_name="scooters_raw",
            destination="postgres",
            dataset_name="raw",
        )

        # replace: при каждом запуске таблица пересоздаётся (идемпотентность)
        load_info = pipeline.run(
            arrow_table,
            table_name=table_name,
            write_disposition="replace",
        )

        print(f"[{table_name}] Loaded: {load_info}")

    duck.close()


def load_json_to_raw(**context):
    """Читает JSON-файлы из S3 через DuckDB и грузит в Postgres через dlt."""

    duck = duckdb.connect()

    for table_name in TABLES_JSON:
        url = f"{S3_BASE_URL}/{table_name}.json"

        # DuckDB умеет читать JSON напрямую по HTTPS
        arrow_table = duck.execute(f"SELECT * FROM '{url}'").fetch_arrow_table()
        row_count = arrow_table.num_rows
        print(f"[{table_name}] Extracted {row_count} rows from {url}")

        pipeline = dlt.pipeline(
            pipeline_name="scooters_raw",
            destination="postgres",
            dataset_name="raw",
        )

        load_info = pipeline.run(
            arrow_table,
            table_name=table_name,
            write_disposition="replace",
        )

        print(f"[{table_name}] Loaded: {load_info}")

    duck.close()


def load_geojson_to_raw(**context):
    """
    Загружает mo.geojson как единый текстовый документ в raw.mo_geojson.

    GeoJSON — это сложный формат (FeatureCollection с MultiPolygon),
    DuckDB не умеет читать его по HTTPS напрямую. Поэтому:
      1. Скачиваем файл через requests
      2. Заворачиваем в Arrow-таблицу (1 строка, 1 колонка raw_data:text)
      3. Грузим в Postgres через dlt

    Парсинг геометрии можно сделать позже на этапе трансформации (dbt/SQL).
    """
    import pyarrow as pa

    url = f"{S3_BASE_URL}/mo.geojson"

    # Скачиваем файл целиком как текст
    resp = requests.get(url)
    resp.raise_for_status()
    raw_text = resp.text

    print(f"[mo_geojson] Downloaded {len(raw_text)} bytes from {url}")

    # Заворачиваем в Arrow-таблицу: одна строка, одна колонка с полным JSON
    arrow_table = pa.table({"raw_data": [raw_text]})

    pipeline = dlt.pipeline(
        pipeline_name="scooters_raw",
        destination="postgres",
        dataset_name="raw",
    )

    # Явно указываем тип text, чтобы dlt не пытался угадать
    load_info = pipeline.run(
        arrow_table,
        table_name="mo_geojson",
        write_disposition="replace",
        columns={"raw_data": {"data_type": "text"}},
    )

    print(f"[mo_geojson] Loaded: {load_info}")


with DAG(
    dag_id="load_scooters_raw",
    schedule="@daily",
    start_date=pendulum.datetime(2025, 1, 1, tz="Europe/Moscow"),
    catchup=False,
    tags=["dlt", "raw", "scooters", "s3"],
    default_args={"retries": 2, "retry_delay": pendulum.duration(minutes=1)},
) as dag:

    load_raw_parquet = PythonOperator(
        task_id="load_parquet_to_raw",
        python_callable=load_parquet_to_raw,
    )

    load_raw_json = PythonOperator(
        task_id="load_json_to_raw",
        python_callable=load_json_to_raw,
    )

    load_raw_geojson = PythonOperator(
        task_id="load_geojson_to_raw",
        python_callable=load_geojson_to_raw,
    )

    # Паркет → JSON → GeoJSON (последовательный запуск)
    load_raw_parquet >> load_raw_json >> load_raw_geojson
