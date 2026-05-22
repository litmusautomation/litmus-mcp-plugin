---
description: Quick overview of edges registered in your Litmus Edge Manager project.
---

1. Call `lem_dashboard_usage` to get the project usage summary.
2. Call `lem_list_devices` to enumerate registered edges.
3. Output a tight summary:
   - One line: total devices, online vs offline (from dashboard usage).
   - Markdown table of devices: Name, Version, Last Seen, License Status.

If `EDGE_MANAGER_URL` is not configured, say "LEM is not configured for this plugin instance" and stop.
