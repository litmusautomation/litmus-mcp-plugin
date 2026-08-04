---
name: litmus-verify-dataflow
description: Trace a Litmus Edge data point end to end - driver tag to live NATS topic to InfluxDB history - and confirm each hop. Use when the user asks whether data is flowing, why a value appears live but not in history (or vice versa), where a tag's data goes, what topic or measurement a tag maps to, or wants a dashboard or historian gap explained.
---

Data crosses three boundaries after the driver reads it, and each can fail independently:

```
DeviceHub tag  ->  NATS topic  ->  InfluxDB measurement
 (driver poll)      (live bus)      (historian)
```

Users usually report this as "the data is missing", but which hop broke determines the fix entirely. Establish the mapping first, then test each hop, then say which one fails.

The distinction that drives everything here: **NATS answers "is it flowing right now", InfluxDB answers "what happened before".** Neither substitutes for the other, and the two tools that read them behave very differently.

## Step 1: establish the identity of the tag

Call `get_devicehub_device_tags` with `device_name` for the tag's configuration: `tag_name`, `id`, `address`, `data_type`, `description`. It is paginated, so honor `has_more` and `next_offset` rather than assuming one page covers the device.

This call does **not** return the tag's topic, verified against a live Edge. Resolve the subject in step 3 with `list_nats_topics`, which reports devicehub subjects as `devicehub.alias.<DeviceName>.<TagName>`. Do not construct that string yourself and assume it: confirm it appears in the listing.

Confirm the tag is actually reading: `get_tag_status` with `device_name` and `tag_name`. If the state is `Failed` or `Unknown`, stop here. Nothing downstream can carry data the driver never read, so any further hop testing just confirms consequences of this one fault. Hand off to `litmus-troubleshoot`.

## Step 2: hop one, driver to live value

Call `get_current_value_of_devicehub_tag` with `device_name` and `tag_name` (or `tag_id`).

**Known failure on self-signed Edges.** This tool reaches the broker after its REST calls, and the NATS client attempts TLS regardless of `NATS_TLS=false`, then rejects a self-signed certificate. On a live 4.0.14 sandbox it failed with `read_failed` and `[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: self-signed certificate` even though every REST call in the same tool returned 200. `VALIDATE_CERTIFICATE=false` covers the REST API only; it does not reach the NATS connection.

The same limitation applies to `get_current_value_from_topic` and `get_multiple_values_from_topic`, so all three live-value tools are unusable on such an Edge.

When you hit it, do not report the device as dead. It is a transport limitation on the MCP server side, and the tag may be publishing perfectly. Fall back to the CLI, which can disable broker TLS:

```bash
litmus-cli --insecure le data subscribe 'devicehub.alias.<Device>.<Tag>' --limit 2 --wait 15s --nats-no-tls
```

That path is verified working against the same Edge that fails through the MCP tools. See the `litmus-cli` skill.

Check the value's plausibility, not just its presence. A value inside the expected range confirms the poll. A wildly scaled number (a temperature of 6553.5) or a frozen one points at a data-type, byte-order, or scaling error rather than a transport problem.

## Step 3: hop two, tag to NATS topic

Call `list_nats_topics` with `pattern` set to the device or tag name. Never guess a subject: subjects are not derivable from device and tag names, and a guessed subject fails exactly like a dead topic, which produces a confident wrong diagnosis.

The response merges three sources and labels which reported each topic:

- `analytics` - broadest registry (Litmus Edge 4.0.x and newer)
- `devicehub` - per-tag input/output topics
- `digitaltwins` - per-instance payload topics

Also read the per-source status. If a source was skipped or unavailable, a missing topic may just mean that component was not queried. Say so rather than reporting the topic as absent.

If the topic does not appear at all, the tag is not published to NATS. That is a configuration answer, not a fault: nothing downstream, including the historian, will ever see it.

With the exact subject, call `get_current_value_from_topic`.

Prefer that over `get_multiple_values_from_topic`, which **blocks** until `num_samples` messages arrive and therefore hangs on a silent topic instead of failing fast. Reach for it only after a single value is confirmed and the user wants a trend, and keep `num_samples` small (default 10, max 100). Neither tool returns history; both wait for the next publish.

## Step 4: hop three, NATS to historian

Call `list_influxdb_measurements` to see what the historian actually holds, rather than assuming a name.

For DeviceHub data the convention is one measurement **per device** in the `tsdata` database, named `<DeviceName>.<DeviceID>`, holding all of that device's tags as rows. So there is no per-tag measurement to look for: you narrow to a tag by filtering rows, not by finding a differently-named series. Other producers can register measurements named after their NATS topic, so confirm against the listing instead of relying on either pattern.

Then confirm records are landing, easiest via `get_device_connection_status` for the device: `connected` means recent records exist, `stale` means records exist but not recently, `no_data` means InfluxDB has never held any for it.

For the actual series use, in order of preference:

- `query_tag_data` with `device_name` and `tag_name` - resolves the topic for you. Newest first, `limit` max 500. Best default.
- `get_device_historical_data` with `device_query` - fuzzy device-name matching, for when the measurement name is unknown.
- `get_historical_data_from_influxdb` with an exact `measurement` - most precise, once step 4 gave you the real name.
- `get_tag_statistics` - mean, min, max, stddev, count, and a mean +/- 2 sigma baseline. Use for "are these values normal" instead of eyeballing raw samples. A stddev at or near zero means a frozen signal, which reads as healthy data but is not.

When the answer needs an InfluxQL condition, or the same check across many tags or devices, drop to the CLI instead. It filters server-side and loops in one shell command, and its `le data` plane covers both hops:

```bash
litmus-cli le data measurements --contains Machine3
litmus-cli le data poll 'Machine3.<deviceID>' --last 1h --filter "\"tag\" = 'Temperature'"
litmus-cli le data subscribe 'devicehub.alias.Machine3.*' --limit 5 --wait 15s
```

`le data` authenticates separately from the REST API (broker token, InfluxDB DB user) and its timestamps are epoch milliseconds. See the `litmus-cli` skill.

## Reading the result

The failure pattern names the cause:

| Live value | History | Cause |
|---|---|---|
| yes | yes | Flow is healthy. The problem is in the consumer: dashboard query, time range, or credentials. |
| yes | no | Historian side. Check storage headroom via `get_system_event_stats` - a full disk stops writes while the live bus keeps running. Also check the tag is actually selected for storage. |
| no | yes | Flow stopped recently. Use `query_tag_data` to find the last good timestamp, then `get_system_events` over that window. |
| no | no | Nothing is flowing. Go back to `get_tag_status` and `litmus-troubleshoot`; this is a device or driver fault, not a transport one. |

"Live yes, history no" immediately after creating a tag is normal - the historian needs a poll cycle or two. Re-check before calling it a fault.

## Output

- **Mapping** - the resolved chain: `device / tag -> topic -> measurement`. This alone answers a large share of the questions that trigger this skill.
- **Per-hop result** - each of the three hops marked confirmed, failed, or not checked, with the evidence.
- **Verdict** - which hop breaks and the concrete next action, or confirmation that flow is healthy and the problem lies in the consumer.

State any hop you could not verify and why (InfluxDB not configured, NATS unreachable, source skipped). Do not present two verified hops as an end-to-end confirmation.
