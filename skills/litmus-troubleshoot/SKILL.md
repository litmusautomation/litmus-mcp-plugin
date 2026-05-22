---
name: litmus-troubleshoot
description: Diagnose offline, stale, or misbehaving devices on a Litmus Edge instance by combining device, tag, NATS, and InfluxDB data into a root-cause analysis.
---

When the user asks why a device is offline, stale, returning bad values, or otherwise misbehaving, run this diagnostic sequence using the litmus MCP tools.

## Sequence

1. **Confirm the device exists.** Call `get_devicehub_devices` and look for the device by name or ID. If not present, stop here and tell the user the device is not registered.

2. **Check device connection.** Call `get_device_connection_status` for the device. This probes InfluxDB for recent records and tells you whether the device is actually publishing data, not just configured.

3. **Check tag health.** Call `get_tag_status` for the device (or `get_all_tags_status` if you don't have a specific device yet). Tags in ERROR state localize the failure to specific registers vs the whole device.

4. **Read live values.** Call `get_current_value_from_topic` on the device's primary tag NATS topic. If a value comes back, the device-to-Edge link is alive in real time. If not, the problem is upstream (network, device power, credentials).

5. **Check historical continuity.** Call `query_tag_data` for the last 15 minutes of the device's main tag. Identify the exact timestamp where data stopped. This pins when the failure started, which often correlates with a known event (maintenance window, network change).

6. **Check cloud activation.** If the user mentions cloud-side symptoms, call `get_cloud_activation_status` to confirm the Edge is still talking to Litmus Cloud.

## Output

Present findings as three sections:
- **Working**: what's confirmed healthy
- **Failing**: the specific layer that broke and when
- **Likely cause**: one or two hypotheses ranked by probability

Do not dump raw tool output. Synthesize. Skip any step that's irrelevant to the user's specific question (e.g. don't query InfluxDB if they haven't configured it).
