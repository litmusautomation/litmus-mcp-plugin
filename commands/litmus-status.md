---
description: Quick health check on the active Litmus Edge instance - identity, device count, cloud activation.
---

Get a fast summary of the Litmus Edge instance the user is currently connected to.

1. Call `get_litmusedge_friendly_name` to identify which Edge is connected.
2. Call `get_devicehub_devices` and report total count plus how many are offline (use the `summary` field if present).
3. Call `get_cloud_activation_status` and report cloud connection state.

Output as a tight three-line summary. No commentary, no suggestions, no follow-up questions.
