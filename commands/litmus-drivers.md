---
description: List the protocol drivers Litmus Edge supports for creating new devices (ModbusTCP, OPC UA, BACnet, etc.).
---

Call `get_litmusedge_driver_list`.

Each driver record has exactly two fields, `name` and `id`. Verified against a live Edge: there is **no version field**, so do not add a Version column.

The catalog is large: a live 4.0.14 Edge returned **153 drivers**. Do not dump all of them. Default to grouping by protocol family (Allen-Bradley, Siemens, Modbus, OPC, BACnet, DNP3, MQTT, and so on) with counts, then list names only for the family the user asked about. If `$ARGUMENTS` names a protocol, filter to matching names and show those as a single-column list.

Note: this is the catalog of driver types this Edge can use, not a list of drivers currently in use. To see which drivers are actively configured, run `/litmus-devices` - each device shows the driver it uses.

Driver names from this list are what `create_devicehub_device` expects in `selected_driver`, so this is the first call when adding a device. The `litmus-onboard-device` skill covers the full add-and-verify sequence.
