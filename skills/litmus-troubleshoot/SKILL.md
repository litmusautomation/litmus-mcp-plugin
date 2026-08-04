---
name: litmus-troubleshoot
description: Diagnose an offline, stale, or misbehaving device on a Litmus Edge instance. Use when a device is not reporting, values look wrong or frozen, tags are failing, or the user asks why data stopped arriving. Combines device config, tag runtime state, live NATS values, and InfluxDB history into a layered root-cause analysis.
---

Industrial data flows through four layers, and the whole point of this skill is to find which one broke:

```
physical device -> driver poll (DeviceHub tag) -> NATS topic (live) -> InfluxDB (history)
```

A symptom looks identical from the top no matter which layer failed, so work bottom-up from evidence rather than guessing. The single most useful distinction: **NATS carries live values, InfluxDB carries history.** "No live value but history exists" and "history stopped but live values flow" are different faults with different causes.

## Step 1: gather everything in one call

Call `get_device_data_for_inference` with the device name. One call returns device metadata, all tags, per-tag statistics, and recent samples. It is built for exactly this diagnosis and it replaces four or five separate calls.

Useful arguments: `time_range` (default `1h`; widen to `24h` when the user says "since yesterday"), `sample_size` (default 20, max 100).

If it fails because the device name does not match, call `get_devicehub_devices` to list what exists and correct the name. If it still does not exist, stop: the device is not registered, and nothing downstream can work. That is the answer.

If InfluxDB is not configured, this call degrades or fails. Fall back to steps 2 and 4 only, and say up front that history-based conclusions are unavailable.

## Step 2: localize to device or tag

Call `get_tag_status` for the device. State is `OK`, `Failed`, or `Unknown`.

This separates two very different faults:

- **All tags failing** - the device or its link is down. Cause is connection-level: power, network path, wrong IP or port, bad credentials, device not enabled.
- **Some tags failing** - the link is fine and the device is answering. Cause is configuration-level: bad register address, wrong data type, unsupported function code, polling interval too aggressive.

Do not skip this. Reporting "the device is down" when only three of forty registers are misconfigured sends the user to the wrong place entirely.

Call `get_device_connection_status` for the freshness view. It returns `connected`, `stale`, or `no_data`, and `threshold_seconds` (default 60) sets what counts as fresh. `no_data` means InfluxDB has never held records for it, which points at a device that was never working rather than one that stopped.

## Step 3: check whether live data still flows

Only now touch NATS, and only if steps 1 and 2 left it ambiguous.

First call `list_nats_topics` with `pattern` set to the device or tag name. **Do not guess a topic subject.** Subjects are not derivable from device names, and a guessed subject fails in a way that looks like a dead device, which is a false diagnosis. If the topic does not appear, note that the tag may not be published to NATS at all.

Then call `get_current_value_from_topic` with the exact subject.

- Value returned - the device-to-Edge path is alive right now. Any "no data" symptom is downstream: historian, dashboard, or the consumer.
- Nothing returned - the break is at or below the driver poll.

Avoid `get_multiple_values_from_topic` here. It **blocks** until `num_samples` messages arrive, so on a dead topic it stalls the diagnosis rather than failing fast. Use it only after a live value is confirmed and you need a trend.

**If the call fails with an SSL certificate error, that is not the device.** All three live-value tools connect to the broker with TLS regardless of `NATS_TLS=false`, and reject self-signed certificates. On a live 4.0.14 Edge this surfaced as `[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: self-signed certificate` while every REST call in the same tool returned 200. Diagnosing that as a dead device or a dead topic is the wrong call and sends the user to the plant floor for a server-side transport limit.

Fall back to the CLI, which can turn broker TLS off and is verified working against an Edge where these tools fail:

```bash
litmus-cli --insecure le data subscribe 'devicehub.alias.<Device>.<Tag>' --limit 2 --wait 15s --nats-no-tls
```

## Step 4: pin when it broke

Call `query_tag_data` for the affected tag with `time_range` wide enough to contain the transition (`1h`, then `24h`, then `7d`). Results come back newest first, capped at 500 records. Find the last good timestamp.

That timestamp is the most actionable output of the whole diagnosis. Correlate it against `get_system_events` over the same window, filtering `severity='ERROR'` then `'WARN'`. `from_timestamp` and `to_timestamp` are Unix epoch **seconds**, and they default to the last hour, so set them explicitly to match the window you care about.

For "values look wrong" rather than "values stopped", use `get_tag_statistics` instead. It returns mean, min, max, stddev, count, and a baseline of mean +/- 2 sigma. A reading inside baseline means the user's expectation is off; outside it means the signal genuinely moved. Frozen values show as a stddev at or near zero, which is worth calling out because a stuck sensor reports plausible data forever.

## Step 5: widen only if the device looks fine

If the device itself checks out, the fault is environmental:

- `get_system_event_stats` - memory, storage, CPU, and last-hour event counts by severity. Storage near full stops the historian while live NATS keeps flowing, which produces exactly the "live works, history stopped" pattern. Compute storage from the raw `storage.dataSize` and `storage.totalSize` fields: `health.data_storage_used_pct` is wrong upstream and can come back negative. This tool also returns `success: true` while substituting per-field `*_error` keys, so check for those before trusting any number.
- `get_cloud_activation_status` - only for cloud-side symptoms such as data missing in LEM or a dashboard while present locally.
- `get_network_interface_info` and `get_firewall_rules` - for a device on a different subnet, or a protocol port that may be blocked.

## Step 6: packet capture, last resort

Only when the device is confirmed reachable, tags still fail, and the suspicion is protocol-level (malformed responses, timeouts, unexpected function codes).

1. `get_packet_capture_interfaces` to pick an interface.
2. `get_packet_capture_status` to confirm no capture is already running.
3. `start_packet_capture` with `interface` and `duration` in minutes (1 to 30).

**Let it run to completion.** The pcap file is only retained when the capture finishes naturally. `stop_packet_capture` **discards** the file, so it is for aborting an unwanted capture, never for collecting one early. Tell the user the duration before starting, and do not offer to stop it early to "get the results faster" - that destroys them.

## Output

Four sections, synthesized. Never dump raw tool output.

- **Symptom** - one line restating what is actually observed, in layer terms.
- **Working** - layers confirmed healthy, so the user knows what not to touch.
- **Broken** - the specific layer that failed and, when known, the timestamp it failed at.
- **Likely cause** - one or two hypotheses ranked by probability, each with the concrete next action.

Name what you could not check and why (InfluxDB unconfigured, NATS unreachable, topic not found). A gap stated is useful; a gap silently skipped makes the report look more conclusive than it is.

Skip any step the symptom rules out. A user asking "why is this one tag frozen" does not need firewall rules.
