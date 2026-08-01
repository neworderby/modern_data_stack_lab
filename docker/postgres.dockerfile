ARG base_tag=17.2
ARG pg_version=17

# build stage
FROM docker.io/postgres:${base_tag} AS build

ARG pg_version
ARG fdw_version=2.0.4

ARG fdw_url=https://github.com/tds-fdw/tds_fdw/archive/refs/tags/v${fdw_version}.zip

ARG source_files=/tmp/tds_fdw
ARG source_root=tds_fdw-${fdw_version}

ARG MYSQL_FDW_VERSION=2_9_2
ARG MYSQL_FDW_URL=https://github.com/EnterpriseDB/mysql_fdw/archive/REL-${MYSQL_FDW_VERSION}.tar.gz
ARG SOURCE_FILES=/tmp/mysql_fdw

#Устанавливаем зависимости
RUN apt-get update && \
    # compilation deps
    apt-get install -y --no-install-recommends wget unzip ca-certificates \
    make gcc gnupg \
    postgresql-server-dev-${pg_version}\
    freetds-dev \
    libmariadb-dev-compat \
    # runtime deps
    libsybdb5 freetds-common

#Устанавливаем tds_fdw для обращения к MS SQL
RUN rm -rf ${source_files} && \
    mkdir -p ${source_files} && \
    wget -O sources.zip ${fdw_url} && \
    unzip sources.zip -d ${source_files} && \
    rm sources.zip && \
    cd ${source_files}/${source_root} && \
    # install
    make USE_PGXS=1 && \
    make USE_PGXS=1 install;

#Устанавливаем MYSQL аддон
RUN mkdir -p ${SOURCE_FILES} && \
    wget -O - ${MYSQL_FDW_URL} | tar -zx -C ${SOURCE_FILES} --strip-components=1 && \
    cd ${SOURCE_FILES} && \
    # compilation
    make USE_PGXS=1 && \
    make USE_PGXS=1 install

# final stage
FROM docker.io/postgres:${base_tag}

ARG pg_version
ARG extdir=/usr/share/postgresql/${pg_version}/extension
ARG extlibdir=/usr/lib/postgresql/${pg_version}/lib
ARG libdir=/usr/lib/x86_64-linux-gnu

COPY --from=build ${extdir}/tds_fdw* ${extdir}/
COPY --from=build ${extlibdir}/tds_fdw.so ${extlibdir}/
COPY --from=build ${libdir}/libsybdb.so.5.1.0 ${libdir}/
COPY --from=build ${extdir}/mysql_fdw* ${extdir}/
COPY --from=build ${extlibdir}/mysql_fdw.so ${extlibdir}/
COPY --from=build ${libdir}/libmysqlclient.so ${libdir}/libmysqlclient_r.so ${libdir}/
COPY --from=build ${libdir}/libmariadb3/ ${libdir}/libmariadb3/

RUN cd ${libdir} && \
    ln -sf libsybdb.so.5.1.0 libsybdb.so.5 && \
    ln -sf libsybdb.so.5 libsybdb.so;