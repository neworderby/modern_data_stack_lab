from airflow.decorators import dag, task
from airflow.models import Variable
from datetime import timedelta, datetime
import os

@dag(dag_id='dbt',
    schedule_interval="0 5 * * *",
    catchup=False,
    max_active_runs=1,
    max_active_tasks=1,
    dagrun_timeout=timedelta(minutes=30),
    start_date=datetime(2024, 1, 1)
)

@task.bash()
def run():
    db_user = Variable.get('DESTINATION__POSTGRES__USERNAME')
    db_password = Variable.get('DESTINATION__POSTGRES__PASSWORD')
    return f"""
        export DB_USER={db_user}
        export DB_PASSWORD={db_password}
        cd /opt/dbt_dwh && dbt clean && dbt deps && dbt run
        """