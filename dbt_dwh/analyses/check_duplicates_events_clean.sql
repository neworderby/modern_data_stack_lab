--should be 0 rows    
select
    user_id,
    "timestamp",
    type_id
from
    {{ ref('events_clean')}}
group by
    1,
    2,
    3
having
    count(*) > 1