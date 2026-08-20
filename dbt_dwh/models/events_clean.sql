select distinct
    user_id,
    "timestamp",
    type_id
from
    {{ source("raw", "events") }}
{% if is_incremental() %}
    where
        "timestamp" > (select max("timestamp") from {{ this }})
{% else %}
    where
        "timestamp" < date '2023-08-01'
{% endif %}    