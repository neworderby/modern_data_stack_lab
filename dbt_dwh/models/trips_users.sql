select t1.id,
       t1.user_id,
       t1.scooter_hw_id,
       t1.started_at,
       t1.finished_at,
       t1.start_lat,
       t1.start_lon,
       t1.finish_lat,
       t1.finish_lon,
       t1.distance_m,
       t1.price_rub,
       t1.duration_s,
       t1.is_free,
       t1.date,
       t2.sex,
       extract(year from t1.started_at) - extract(year from t2.birth_date) as age,
       {{ updated_at() }}
from {{ ref("trips_prep") }} t1
left join {{ source("raw", "users") }} t2 on t1.user_id = t2.id
{% if is_incremental() %}
    where
        t1.id > (select max(id) from {{ this }})
    order by
        t1.id
    limit
        75000
{% else %}
    where
        t1.id <= 75000
{% endif %}