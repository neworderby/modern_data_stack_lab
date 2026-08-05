select started_at::date as date_start, count(1) as trips, max(price) as max_price, avg(distance) as avg_distance 
from raw.trips
group by 1
having count(1) < 1000