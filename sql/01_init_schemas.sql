-- ============================================================================
-- Инициализация схем хранилища данных (DWH)
-- Запуск: psql -h localhost -p 5432 -U admin -d dwh -f sql/01_init_schemas.sql
-- ============================================================================

-- Схема для сырых данных (EL слой)
-- Данные загружаются "как есть" через dlt, Airbyte, или прямыми INSERT
CREATE SCHEMA IF NOT EXISTS raw;

-- Схема для промежуточного слоя (staging)
-- Очистка, нормализация, приведение типов — dbt staging models
CREATE SCHEMA IF NOT EXISTS stage;

-- Схема для детального слоя (detail data store)
-- Размерности (dim_) и факты (fct_) — dbt dimensional models
CREATE SCHEMA IF NOT EXISTS dds;

-- Схема для витрин данных (data marts)
-- Агрегированные данные для аналитики и отчетов — dbt marts
CREATE SCHEMA IF NOT EXISTS mart;

-- ============================================================================
-- Расширения (опционально — для FDW и доп. возможностей)
-- ============================================================================

-- FDW для MS SQL Server
CREATE EXTENSION IF NOT EXISTS tds_fdw WITH SCHEMA raw;

-- FDW для MySQL
CREATE EXTENSION IF NOT EXISTS mysql_fdw WITH SCHEMA raw;