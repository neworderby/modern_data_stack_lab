{{ config(materialized='view') }}
select id
       , user_id
       , scooter_hw_id
       , started_at
       , finished_at
       , start_lat
       , start_lon
       , finish_lat
       , finish_lon
       , distance as distance_m
       , cast(price/100.00 as decimal(20,2)) as price_rub
       , extract(epoch from (finished_at - started_at)) as duration_s
       , case when price <> 0 and extract(epoch from (finished_at - started_at)) > 0 then true else false end is_free
       , date(started_at) as date
from {{ source("raw", "trips") }}