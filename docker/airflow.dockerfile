FROM apache/airflow:2.10.4

USER root
RUN apt-get update && \
    apt-get install -y libpq-dev gcc git freetds-dev libkrb5-dev unixodbc-dev && \
    rm -rf /var/lib/apt/lists/*

USER airflow

COPY requirements.txt .
COPY requirements_mac.txt .

RUN pip install -r requirements.txt -r requirements_mac.txt