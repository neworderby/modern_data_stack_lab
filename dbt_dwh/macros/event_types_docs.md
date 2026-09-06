{% docs event_types_description %}

## Event types

Reference table (seed) maintained by the analytics team. It maps unique event
type identifiers (`type_id`) from the raw mobile app events table
(`raw.events`) to their human-readable names (`type`).

### Purpose

Raw event data contains only numeric `type_id` values, which are not
interpretable on their own. This seed serves as the single source of truth for
resolving those identifiers into meaningful event names. It is used to enrich
event-based models (e.g. `events_full`, `events_stat`) via a join on
`type_id`, and to make downstream reporting readable for business users.

### Contents

| type_id | type            | Description |
|---------|-----------------|-------------|
| 0       | `start_search`  | User opened the map / started searching for a scooter |
| 1       | `book_scooter`  | User booked (reserved) a scooter |
| 2       | `release_scooter` | User released (unlocked and started riding) a booked scooter |
| 3       | `cancel_search` | User cancelled the search / booking session |

### Data characteristics

- Grain: one row per unique `type_id`; the mapping is stable and rarely changes.
- `type_id` — integer, primary key of the mapping, matches the values in
  `raw.events.type_id`.
- `type` — lowercase snake_case event name, unique across the table.
- The seed is small (a handful of rows) and is loaded via `dbt seed` with a
  comma delimiter.

### Usage notes

- Always join on `type_id` — never hardcode the mapping in models, so that new
  event types added by the analytics team are picked up automatically.
- Events with a `type_id` missing from this seed will produce `null` type
  names after the join; treat such rows as unknown/unclassified events and
  investigate rather than dropping them.
- When a new event type is introduced, the analytics team updates this CSV;
  run `dbt seed --full-refresh` to reload the reference table.

{% enddocs %}
