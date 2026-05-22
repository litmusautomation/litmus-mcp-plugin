---
description: List configured tags for a device on Litmus Edge. Pass the device name or ID.
---

Device: `$ARGUMENTS`

1. Call `get_devicehub_device_tags` with the device argument.
2. Present the tags as a markdown table with columns: Name, Topic, Data Type, Current Status.
3. If the device argument doesn't match any device, suggest running `/litmus-devices` to see available devices.

No commentary beyond the table.
