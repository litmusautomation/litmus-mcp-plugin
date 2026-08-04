---
description: Summarize Litmus Edge network interfaces and firewall rules.
---

Optional interface name: `$ARGUMENTS`

`get_network_interface_info` returns details for a **single** interface and defaults to `eth0`. It is not a listing call, so do not expect one call to enumerate the box.

1. Call `get_packet_capture_interfaces` first. Despite the name, this is the enumeration of the device's network interfaces, so it is what tells you which names exist.
2. If `$ARGUMENTS` names an interface, call `get_network_interface_info` for just that one. Otherwise call it once per interface returned in step 1, capping at 6 interfaces to keep this fast.
3. Call `get_firewall_rules`.

Output two sections:

**Interfaces** - markdown table: Interface, Type, IPv4, Gateway, MTU, WAN.

Verified against a live Edge. The response is `{interface, details}`, where `details` is `{name, idx, type, wan, inet, inet6}` and `inet` is `{address, gateway, mtu, type}`. The address is CIDR (`10.17.2.87/22`) and `inet.type` is the assignment method (`dhcp`, `static`). `wan` is a boolean.

There is **no MAC address, no link state, and no speed** in the response, despite the tool description mentioning them. Do not include those columns and do not report link status. If an interface from step 1 cannot be queried, show it with blank fields rather than omitting it. Show the IPv6 row only when `inet6.address` is non-empty.

**Firewall** - markdown table: Port, Protocol, Policy, Interface, Description. The rule keys are `port`, `protocol`, `policy` (`ALLOW` or `DENY`, not `action`), `iface`, `desc`, `id`. If there are more than 15 rules, show every DENY plus the first 10 ALLOW and note how many were omitted.

No prose beyond the tables and any down-link flag.
