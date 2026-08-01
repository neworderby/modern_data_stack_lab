Modern data stack tools for Data Warehouse:
DBT, Airflow, Dagster, DuckDB, Airbyte, DLT, Docker, Postgres

mkdir modern_data_stack
cd modern_data_stack
python3.12 -m venv .venv
source .venv/bin/activate
pip install "dlt[duckdb]"
pip install pandas
pip install "dlt[parquet]" 
pip install clickhouse_connect

Репозиторий содержит инструменты для разработки и управления данными. Будет дополняться по мере развития проекта.