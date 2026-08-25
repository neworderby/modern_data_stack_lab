select
    company,
    count(*) as models,
    sum(trips) as scooters
from
    {{ ref("scooters") }}
group by
    1