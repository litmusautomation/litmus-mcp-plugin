---
description: Resource and event health snapshot for the active Litmus Edge (memory, storage, CPU, event severity counts).
---

1. Call `get_system_event_stats`. One call returns the event store size, last-hour event counts by severity, memory and storage usage with percentages, and CPU count.
2. Call `get_all_tags_status`. Its default `filter_status='not_ok'` means the response is already just the actionable tags.

Output four short lines, no tables:

- **Resources**: memory used/total with percent, storage used/total with percent, CPU count. Flag anything above 85 percent.
- **Events (last hour)**: counts by severity, and the event store size.

Response shape, verified against a live Edge: `{event_store: {size}, recent_events_1h: {total, by_severity}, memory: {memTotal, memUsed, memAvailable, swapTotal, swapUsed}, storage: {totalSize, dataSize, dataFree}, cpu_count, health: {memory_used_pct, data_storage_used_pct}}`. Memory and storage values are kilobytes, so convert before display. `by_severity` is `{}` when `total` is 0, which is a quiet hour and not an error.

**Do not trust `health.data_storage_used_pct`.** It is computed wrongly upstream and can be negative: a live Edge reported `-95.1` for `totalSize 42001116, dataSize 13869980, dataFree 27066176`. Compute storage yourself from the raw fields, `dataSize / totalSize`, which gives about 33 percent for those numbers, and say which basis you used. `health.memory_used_pct` matches `memUsed / memTotal` and is fine to use directly.

When any field is unavailable the tool still returns `success: true` and substitutes per-field error keys instead (`memory_error`, `storage_error`, `cpu_error`, `event_store_error`, `recent_events_error`). So check for those explicitly: a `success: true` response can still carry no usable numbers at all. Report which parts failed rather than showing blanks.
- **Tags**: how many tags are `Failed` or `Unknown`, naming up to five affected devices. If none, say `all tags OK`.
- **Verdict**: one sentence. Healthy, or the single most pressing problem.

This is the resource and error-rate view. It deliberately does not check device connectivity - use `/litmus-devices` for that, or the `litmus-troubleshoot` skill to chase a specific device.

If any severity count is elevated, suggest `/litmus-events ERROR` to read the actual messages rather than guessing from counts.
