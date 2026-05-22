---
name: litmus-lem-audit
description: Run a fleet-wide health audit on a Litmus Edge Manager (LEM) project covering license status, version spread, active alerts, and overall device counts. Use when the user asks about LEM fleet health, "what's the state of my LEM project", or wants a multi-angle status report on edges registered in LEM.
---

When the user asks for a LEM fleet audit, fleet health summary, or a multi-angle look at their LEM project, run this sequence using the litmus MCP tools. Skip steps the user clearly doesn't care about.

## Prerequisites

This skill requires LEM to be configured (`EDGE_MANAGER_URL` and `EDGE_API_TOKEN` env vars). If the first tool call returns an auth error, stop and tell the user LEM isn't configured for this plugin instance.

## Sequence

1. **Project sanity.** Call `lem_deployment_info` to confirm the LEM tenant is reachable and capture the LEM version and build.

2. **Usage snapshot.** Call `lem_dashboard_usage` to capture device counts (total/online/offline), license usage, and deployment stats.

3. **Active alerts.** Call `lem_get_project_alerts`. These are the things needing immediate attention (offline edges, license issues, deployment failures).

4. **License risk.** Call `lem_get_expired_licenses` for the already-expired list. Call `lem_get_license_expiry` with `days=30` for the upcoming expirations.

5. **Version spread.** Call `lem_list_device_versions` to see the distribution of Litmus Edge versions across the fleet. Old versions on production edges are a frequent root cause for bugs reported as fleet issues.

6. **Device groups (optional).** Call `lem_list_device_groups` if the fleet is large enough to benefit from per-group framing. Skip on small fleets.

## Output

Present findings as four short sections. No raw tool dumps -- synthesize numbers and call out anomalies:

- **Headline**: One sentence with total device count and how many are online.
- **Needs attention**: Active alerts, expired licenses, and licenses expiring within 30 days, as one combined bulleted list. If empty, say so explicitly.
- **Version spread**: One line per distinct version with a count (`v3.7.0: 12 edges` style). Flag any version more than two minor versions behind the latest.
- **Recommendation**: One or two concrete next steps based on what's actually problematic. If everything is healthy, say "no action needed".

Do not list every edge by name unless the user explicitly asks. The audit is fleet-shape, not per-device drill-in.
