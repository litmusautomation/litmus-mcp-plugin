---
description: Show recent system events from Litmus Edge. Optionally pass a count (default 20).
---

Args: `$ARGUMENTS`

1. Call `get_system_events`. If args contain a number, pass it as the limit; otherwise default to 20.
2. Present as a markdown table with columns: Time, Severity, Source, Message.
3. After the table, add one line noting how many of the events are warnings or errors.
