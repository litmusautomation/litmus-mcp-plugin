---
name: litmus-onboard-device
description: Add a new industrial device to Litmus Edge DeviceHub and get it actually publishing data - pick a driver, create the device, set connection properties, add tags, then verify data flows through tag state, live value, topic and historian. Use when the user wants to add, connect, register, or onboard a PLC, sensor, meter, or any device, or asks why a device they just created has no data.
---

Creating a device in DeviceHub does **not** make it work. Stopping after creation produces a device that exists, looks configured, and returns nothing.

Verified against a live Edge 4.0.14: a freshly created device comes back with `Properties: []`, completely empty. The tool description says "default configuration", but there are no driver defaults to inherit, so setting connection properties is mandatory rather than a tidy-up. `create_devicehub_device` also returns a `next_steps` field; read it, it is the authoritative list for that driver.

One correction to a common assumption, confirmed live: **there is no enable step.** DeviceHub devices in 4.0.14 have no `Enabled` field, the SDK catalog exposes no device enable or disable function, and a tag reached `State: OK` within seconds of creation with nothing enabled. If you are looking for a way to switch a device on, you are looking for something that does not exist.

This is a write workflow against live industrial equipment. Confirm the target with the user before each state-changing call.

## Step 0: collect what you need before touching anything

Ask for whatever the user has not already given:

- Protocol (Modbus TCP, OPC UA, BACnet, MQTT, ...)
- Network address: IP and port, plus protocol specifics such as Modbus slave or unit ID, or an OPC UA endpoint path
- Which data points they want, and for each: register address, data type, and how often to poll
- A device name

Do not invent register addresses or IPs. A wrong address either reads the wrong physical quantity silently or fails, and on real equipment writing to a guessed address is genuinely unsafe. If the user does not know their register map, say that is the blocker and stop.

## Step 1: pick the driver

Call `get_litmusedge_driver_list` for the catalog of drivers this Edge supports. Match the user's protocol to an exact driver name; that string is what `selected_driver` expects. If the protocol is not in the catalog, stop and say so rather than substituting a near match.

## Step 2: create the device

Call `create_devicehub_device` with `name` and `selected_driver`.

Names become part of tag topics and InfluxDB measurement names, so pick something stable and descriptive (`ProductionLine_PLC1`, not `test2`). Renaming later breaks anything already consuming the old topics.

Confirm with `get_devicehub_devices` filtered by that driver.

## Step 3: set connection properties

The device now exists with driver defaults, which means it is pointed at nothing useful. It needs the real IP, port, and protocol-specific fields.

**There is no dedicated MCP tool for updating device connection properties.** This is the step that requires the SDK fallback, and it is verified working:

1. `litmus_sdk_discover` with `prefix='le.devicehub'` to confirm the function and its parameter names. The one you want is `le.devicehub.UpdateDevice(device)`. Note the catalog is alphabetical and long, so `Update*` sits well down the list.
2. Read the current record with `litmus_sdk_read` on `le.devicehub.GetDevice(deviceID)` or `le.devicehub.ListDevices()`, so you send a real payload rather than one built from scratch.
3. Show the user the exact function and the full argument set.
4. Only after they explicitly approve, call `litmus_sdk_write` with `user_approved=true`.

The device object shape, confirmed live:

```
{ID, Name, DriverID, Description,
 Properties:   [{Key, Value}, ...],
 MetaData:     [{Key, Value}, ...],
 DHParams:     [{Key, Value}, ...],
 WorkerParams: [{Key, Value}, ...],
 AliasTopics: bool, Debug: bool}
```

`Properties` is a **list of `{Key, Value}` pairs, not an object.** Convert to a dict, set your keys, convert back, and pass the whole device object to `UpdateDevice`. This differs from `create_devicehub_tag`, whose `properties` argument really is a plain object, so do not carry one shape across to the other.

Real property keys look like `networkAddress`, `networkPort`, `masterAddress`, `outstationAddress`, `class123PollPeriod`, `enableTimeSync`, `description`. They are driver-specific: read an existing working device of the same driver to see which ones that driver expects.

`AliasTopics` controls whether the device publishes friendly `devicehub.alias.<Device>.<Tag>` subjects. Working devices on a live Edge had it `true`. If topics never appear in step 5, check this.

Never set `user_approved=true` preemptively. The server rejects the call without it specifically so a human sees the payload first, and these functions overwrite device configuration with no undo. Use only dotted paths `litmus_sdk_discover` actually returned; guessed paths fail.

See the `litmus-sdk-fallback` skill for the full escalation rules.

## Step 4: add tags

For each data point, call `create_devicehub_tag` with `device_name`, `register_name`, `tag_name`, and `value_type`.

- `register_name` is the driver-specific **register type**, not an address: `HoldingRegister` for Modbus, `S` for the Generator driver. Get valid values from the driver catalog in step 1.
- `value_type` is the data type: `float64`, `int64`, `bit`, `string`.
- Required driver properties (address, count, polling interval) auto-fill from driver defaults. Override individual fields with `properties`, e.g. `{"address": "5", "pollingInterval": "500"}`.

Address and polling interval are almost always wrong at defaults, so pass them explicitly rather than relying on fill-in.

Start with one tag and verify it before creating the rest. A register-map misunderstanding caught on tag one costs a single call; caught on tag forty it costs forty corrections.

Check what already exists with `get_devicehub_device_tags` (paginated: honor `has_more` and `next_offset`).

## Step 5: verify data actually flows

Creation succeeding is not evidence of data. Verify in this order, because each layer depends on the one before it.

1. **`get_tag_status` for the device.** `OK` means the driver is reading the register. `Failed` means it is not, and the address, data type, or connection is wrong. Fix this before going further: the later layers cannot succeed while a tag is `Failed`. This resolves fast, within a few seconds of tag creation.

2. **Read the live value and sanity-check its magnitude.** A temperature reading 6553.5 is a scaling or data-type error, not a hot machine. Byte-order and type mismatches produce plausible-looking but wrong numbers, so check the value, not just its presence.

   `get_current_value_of_devicehub_tag` **fails on an Edge with a self-signed certificate**, verified live: the NATS client attempts TLS regardless of `NATS_TLS=false` and rejects the cert, returning `[SSL: CERTIFICATE_VERIFY_FAILED]`. That is a transport limitation, not a bad tag. Fall back to the CLI:

   ```bash
   litmus-cli --insecure le data subscribe 'devicehub.alias.<Device>.<Tag>' --limit 2 --wait 15s --nats-no-tls
   ```

3. **Topic and historian, with realistic expectations.** `list_nats_topics` with `pattern` set to the device name, then `get_device_connection_status`.

   Both lag behind tag creation. On a live Edge, immediately after a tag reached `State: OK`, `list_nats_topics` returned **zero** matching topics and connection status was **`no_data`** with `last_seen: null`. Neither means failure. Topic registration and the first historian write both trail the first poll cycles, so re-check after a minute rather than concluding the tag is not publishing. Note the status is `no_data` on a brand-new device, not `stale`: `stale` implies it published before and stopped, which cannot be true yet.

The `litmus-verify-dataflow` skill covers this verification in more depth.

## Output

Report as a checklist showing what was done and what was verified:

- Driver selected, device created, connection properties set, tags created (with count)
- Verification: tag state, live value with a plausibility note, and topic plus historian status with the caveat that both lag
- Anything left for the user, especially steps that needed approval and did not get it

Do not report an enable step. There isn't one.

If you stopped partway, say exactly where and what state the device is in. A half-configured device the user believes is finished is worse than one they know is unfinished.

## Cleaning up a test device

There is no dedicated delete-device tool. Removal is `delete_devicehub_tag` per tag, then `litmus_sdk_write` on `le.devicehub.DeleteDeviceByName(name)` with approval. Both verified working. Confirm with `get_devicehub_devices` that the name is gone and the device count is back where it started.

If you stopped partway, say exactly where and what state the device is in. A half-configured device that the user believes is finished is worse than one they know is unfinished.
