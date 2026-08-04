---
description: Show recent Litmus Edge system events. Pass a count, a severity (INFO/WARN/ALERT/ERROR), or both.
---

Args: `$ARGUMENTS`

Parse `$ARGUMENTS` loosely: a bare number is a `limit`, a recognized severity word is a `severity`, and anything else is a `component` filter. Empty args means limit 20, no filters.

1. Call `get_system_events` with the parsed `limit` (default 20, max 1000), plus `severity` and/or `component` when given.

   Valid `severity` values are exactly `INFO`, `WARN`, `ALERT`, `ERROR`. `from_timestamp` and `to_timestamp` are Unix epoch **seconds** and default to the last hour, so widen them explicitly if the user asks for a longer window.

2. Present a markdown table: Time, Severity, Component, Message. Render timestamps as local time, not raw epoch.

3. After the table, one line with the count per severity present (e.g. `3 ERROR, 5 WARN, 12 INFO`).

If the result is empty, say the window was clean and name the window you actually queried, since the default is only one hour and a quiet hour is not a quiet day. For a broader health picture including memory and storage, point at `/litmus-health`.
