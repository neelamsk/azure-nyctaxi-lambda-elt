# core.trip_clean
- **vendor_code** (varchar): Source vendor identifier (uppercased, trimmed).
- **trip_id** (bigint): Trip identifier if present in source; nullable if absent.
- **pickup_ts_utc / dropoff_ts_utc** (datetime2): Normalized to UTC.
- **trip_distance_km** (decimal): Distance normalized to kilometers.
- **fare_amount** (decimal): Fare in source currency units.
- **payment_type** (varchar): Canonical code (via ref.payment_type_map).
- **is_night_ride** (bit): Derived flag (22:00–05:59).
- **ingest_date, source_file_name, loaded_at**: Lineage columns.

# ref.payment_type_map
- **payment_type_src** → **payment_type_std**, with validity windows.
