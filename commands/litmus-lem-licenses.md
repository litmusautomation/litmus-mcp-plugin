---
description: Show expired and expiring-soon Litmus Edge licenses in your LEM project.
---

Optional days threshold: `$ARGUMENTS`

1. Call `lem_get_expired_licenses` for edges already past expiry.
2. Call `lem_get_license_expiry` with `expiry_days` set from `$ARGUMENTS`, or 30 when empty. `expiry_days` is required, so there is no valid call without it.

Output two sections:

- **Expired** - table: Name, Expired On, Days Ago.
- **Expiring within N days** - table: Name, Expires On, Days Left, sorted soonest first.

An edge can appear in both lists depending on how the window is computed. If one does, keep it only in **Expired**.

If both lists are empty, output one line: `All edge licenses are current within N days.` naming the window you checked, so the answer is not mistaken for an unbounded all-clear.

If the first call fails with an auth or configuration error, say `LEM is not configured for this plugin instance` and stop. LEM needs `EDGE_MANAGER_URL` and `EDGE_API_TOKEN`, plus a project id from `EDGE_MANAGER_PROJECT_ID` or the `project_id` argument.
