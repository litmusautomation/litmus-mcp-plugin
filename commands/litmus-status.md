---
description: Quick health check on the active Litmus Edge instance - device count, driver status, cloud activation.
---

Get a fast summary of the Litmus Edge instance the user is currently connected to.

1. Call `dh_list_devices` and report the count.
2. Call `dh_list_drivers` and report which drivers are active vs stopped.
3. Call `dm_cloud_activation_status` and report cloud connection state.

Output as a tight three-line summary. No commentary, no suggestions, no follow-up questions.
