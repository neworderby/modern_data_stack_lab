select
    date(started_at) as date,
    count(*) as trips,
    max(price) / 100 as max_price_rub,
    avg(distance) / 1000 as avg_distance_km
from
    raw.trips
group by
    1