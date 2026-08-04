---
description: List DeviceHub devices on the active Litmus Edge, with real connection state.
---

Optional driver filter: `$ARGUMENTS`

1. Call `get_devicehub_devices`. If `$ARGUMENTS` is non-empty, pass it as `filter_by_driver` (e.g. `ModbusTCP`).
2. Call `get_device_connection_status` with no `device_name`, which returns state for every device in one call.

Both calls are needed. `get_devicehub_devices` returns *configuration* only (name, driver, connection settings, enabled flag) and says nothing about whether a device is actually publishing. Liveness comes only from `get_device_connection_status`, which probes InfluxDB for recent records and returns `connected`, `stale`, or `no_data` per device. Join the two on device name.

Present one markdown table: Name, Driver, State.

Verified against a live Edge: `get_devicehub_devices` returns `name`, `id`, `driver`, `description`, `metadata`, `properties`, and nothing else per device. There is **no enabled flag**, so do not add an Enabled column. Whether a device is polling is only visible as `connected` in step 2. `properties` holds driver-specific connection fields (`networkAddress`, `networkPort`, `requestTimeoutMs`, ...), and `metadata` holds UNS tags.

The response also carries `count` and `summary.by_driver`, a driver-name to count map. Use `summary.by_driver` for the driver breakdown rather than counting rows yourself.

- `connected` - published within the freshness threshold (60s default)
- `stale` - has published before, but not recently
- `no_data` - InfluxDB holds no records for it at all

Then one line: how many are `connected` out of the total. If any are `stale` or `no_data`, add a second line naming them and pointing at the `litmus-troubleshoot` skill.

If `get_device_connection_status` fails because InfluxDB is not configured, still print the table with State as `unknown` and note that state needs InfluxDB credentials. Do not abandon the whole command over it.

No prose beyond the above.
