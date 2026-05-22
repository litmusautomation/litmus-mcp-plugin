---
description: List the protocol drivers Litmus Edge supports for creating new devices (ModbusTCP, OPC UA, BACnet, etc.).
---

Call `get_litmusedge_driver_list`. Present as a markdown table with columns: Name, Version. No prose around it.

Note: this is the catalog of driver types this Edge can use, not a list of drivers currently in use. To see which drivers are actively configured, run `/litmus-devices` -- each device shows the driver it uses.
