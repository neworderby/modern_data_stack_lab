"""
Проект монтируется в контейнер как /opt/dbt_dwh (см. compose.yaml).
Профиль подключения к DWH задаётся через DBT_PROFILES_DIR=/opt/dbt_dwh
и переменные окружения DWH_USER / DWH_PASSWORD / DWH_HOST / DWH_DB_NAME,
которые читает profiles.yml (через env_var).
"""

from airflow.decorators import dag, task
from datetime import timedelta, datetime


@dag(
    dag_id="dbt",
    schedule="0 5 * * *",
    catchup=False,
    max_active_runs=1,
    max_active_tasks=1,
    dagrun_timeout=timedelta(minutes=30),
    start_date=datetime(2024, 1, 1),
    tags=["dbt", "dwh"],
)
def dbt_dag():

    @task.bash()
    def run():
        return "cd /opt/dbt_dwh && dbt clean && dbt deps && dbt run"

    run()


dbt_dag()
