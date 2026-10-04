select
    id,
    sex,
    birth_date
from
    {{ source("raw", "users") }}