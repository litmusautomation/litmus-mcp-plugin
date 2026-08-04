---
description: Quick check on the active Litmus Edge - identity, device liveness, cloud activation.
---

Fast orientation on the Edge the plugin is currently pointed at.

1. Call `get_litmusedge_friendly_name` to identify which Edge is connected.
2. Call `get_device_connection_status` with no arguments. This gives per-device `connected` / `stale` / `no_data` in one call, which is what "how many devices are up" actually means. `get_devicehub_devices` returns configuration only and has no liveness field, so do not use it to answer that.
3. Call `get_cloud_activation_status` for the Litmus Edge Manager registration and last sync time.

Output exactly three lines:

- Edge name, and the URL host it resolved to if available.
- `N of M devices connected`, naming up to three that are not.
- Cloud activation state plus last sync time, or the error message if activation is failing.

If step 2 fails because InfluxDB is not configured, fall back to `get_devicehub_devices` for a configured-device count and label it as configured rather than connected, so the number is not mistaken for liveness.

No commentary, no suggestions, no follow-up questions. For resource and event health use `/litmus-health`.
