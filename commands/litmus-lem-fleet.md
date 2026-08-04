---
description: Overview of edges registered in your Litmus Edge Manager project.
---

1. Call `lem_dashboard_usage` for the project-level summary (device counts, license usage, deployment stats).
2. Call `lem_list_devices` to enumerate the fleet.

   This tool is paginated and its default `limit` is only **10**, with zero-indexed `page`. Pass `limit=100` and keep incrementing `page` until a page returns fewer records than the limit, or until you have 300 devices. Reporting page 0 as the fleet is the default failure here and it makes any fleet larger than 10 look tiny.

   It also defaults to `status='ACTIVE'`, so decommissioned or pending edges are excluded unless you ask for them. Say which status you listed.

3. Call `lem_get_project_alerts` for what needs attention right now.

Output:

- One line: total devices from `lem_dashboard_usage`, online vs offline, and how many you enumerated. If the enumerated count is below the dashboard total, say so and give the reason (paging cap or status filter).
- **Alerts** - bulleted list, or `No active alerts` if empty.
- Markdown table of devices: Name, Version, Last Seen, License Status.

If the first call fails with an auth or configuration error, say `LEM is not configured for this plugin instance` and stop. LEM needs `EDGE_MANAGER_URL` and `EDGE_API_TOKEN`; a project id comes from `EDGE_MANAGER_PROJECT_ID` or the `project_id` argument.

For licensing detail use `/litmus-lem-licenses`. For a fuller multi-angle audit use the `litmus-lem-audit` skill.
