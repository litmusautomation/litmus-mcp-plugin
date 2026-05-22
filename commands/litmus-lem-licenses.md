---
description: Show expired and expiring-soon Litmus Edge licenses in your LEM project.
---

Args (optional days threshold): `$ARGUMENTS`

1. Call `lem_get_expired_licenses` to list edges with already-expired licenses.
2. Call `lem_get_license_expiry` with a days threshold (default 30 if args is empty, otherwise use args as the integer day count). This lists edges whose license expires within that window.
3. Output two short markdown sections:
   - **Expired** -- table of expired edges (Name, Expired On).
   - **Expiring within N days** -- table of soon-to-expire edges (Name, Expires On, Days Left).

If both lists are empty, output a single line: "All edge licenses are current."
