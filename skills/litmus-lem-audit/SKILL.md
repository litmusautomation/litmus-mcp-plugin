---
name: litmus-lem-audit
description: Fleet-wide health audit of a Litmus Edge Manager (LEM) project - active alerts, license risk, version spread, online/offline counts. Use when the user asks about LEM fleet health, the state of their LEM project, which edges are offline or out of date, license renewal exposure, or wants a multi-angle status report on edges registered in LEM.
---

This audits the fleet from the **cloud side**. LEM reports what edges tell it, so a device LEM calls online is one that checked in recently, not one whose data pipeline is healthy. For that, drill into a single edge with `litmus-troubleshoot` or the LEM bridge tools.

All LEM tools here are read-only. Nothing in this skill changes state.

## Prerequisites

LEM needs `EDGE_MANAGER_URL` and `EDGE_API_TOKEN`, plus a project id from `EDGE_MANAGER_PROJECT_ID` or an explicit `project_id` argument.

Start with `lem_deployment_info`. It needs no project id, so it separates "LEM is not configured or unreachable" from "the project id is wrong" - two failures that otherwise look identical. If it fails, stop and say LEM is not configured for this plugin instance. If it succeeds but project-scoped calls fail, the credentials are fine and the project id is the problem. Capture the LEM version and build while you are here.

## Sequence

1. **Usage snapshot.** `lem_dashboard_usage` - device counts (total, online, offline), license usage, deployment stats. This is the authoritative total; treat it as the denominator for everything else.

2. **Active alerts.** `lem_get_project_alerts` - offline edges, license problems, deployment failures. This is what needs attention right now, so lead the report with it.

3. **License risk.** `lem_get_expired_licenses` for already-lapsed edges, then `lem_get_license_expiry` with `expiry_days=30` for upcoming ones. The parameter is `expiry_days` and it is **required** - there is no default, so a call without it fails. Widen the window if the user names a different horizon.

4. **Enumerate the fleet.** `lem_list_devices`.

   Mind the defaults. `limit` is **10** and `page` is zero-indexed, so a single default call returns at most ten edges and makes any real fleet look tiny. Pass `limit=100` and increment `page` until a page returns fewer records than the limit, or until you reach 300 devices - then say you capped.

   It also defaults to `status='ACTIVE'`, which hides decommissioned and pending edges. State which status you enumerated. If your enumerated count is below the `lem_dashboard_usage` total, reconcile the gap explicitly: it is either the paging cap or the status filter, and saying which keeps the numbers honest.

5. **Version spread.** Derive this from the per-device records in step 4 by counting distinct versions.

   Do **not** use `lem_list_device_versions` for this. It lists the versions *registered or tracked in the project*, which is a catalog, not a per-device distribution. It will happily report versions no edge is running, and omit nothing useful about how many edges sit on each. Call it only to answer "which versions does this project know about".

6. **Device groups (optional).** `lem_list_device_groups` when the fleet is large enough that per-group framing helps. These are organizational project-level groupings, **not** driver tags. Skip on small fleets.

7. **Company context (optional).** Only when the user asks across projects or tenants: `lem_list_companies` gives per-company counts of projects, devices, and models, then `lem_list_company_projects` drills down. Note that `lem_get_company_details` takes the company short `name` field, not `real_name`.

## Output

Four short sections. Synthesize; no raw tool dumps.

- **Headline** - one sentence: total devices, how many online, and the LEM version. If your enumeration did not reach the dashboard total, say so here.
- **Needs attention** - one combined bulleted list of active alerts, expired licenses, and licenses expiring within the window. Order by severity. If genuinely empty, say so explicitly.
- **Version spread** - one line per distinct version with a count (`v3.7.0: 12 edges`). Flag anything more than two minor versions behind the newest version present in the fleet. Version skew is a frequent root cause of problems the user reports as fleet-wide faults.
- **Recommendation** - one or two concrete next steps driven by what is actually broken. If everything is healthy, say no action needed rather than inventing work.

Do not list every edge by name unless asked. This is fleet shape, not a per-device inventory. Do name the specific edges behind any flagged item, since an alert without a target is not actionable.
