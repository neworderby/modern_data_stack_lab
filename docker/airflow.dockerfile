FROM apache/airflow:2.10.4

USER root
RUN apt-get update && \
    apt-get install -y libpq-dev gcc git freetds-dev libkrb5-dev unixodbc-dev && \
    rm -rf /var/lib/apt/lists/*

USER airflow

COPY requirements.txt .
COPY requirements_mac.txt .

RUN pip install -r requirements.txt -r requirements_mac.txt

# Форк dbt-mysql пинится на dbt-core~=1.9.0a1, что несовместимо с dbt-core 1.10.x,
# поэтому ставим его без проверки зависимостей (адаптер используется вне этого проекта).
RUN pip install --no-deps "dbt-mysql @ git+https://github.com/stevetracvc/dbt-mysql@a38280b216a91f31c6dd81f1cf0c2421265c72cd#egg=dbt-mysql"

