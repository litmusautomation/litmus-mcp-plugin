---
description: Discover NATS topics on the Litmus Edge. Pass a substring to filter (e.g. a machine name).
---

Filter: `$ARGUMENTS`

Call `list_nats_topics`. Pass `$ARGUMENTS` as `pattern` when non-empty (case-insensitive substring match). Use `limit=200`; if the response says `has_more`, call again with `offset=next_offset` up to 600 topics total, then note the cap.

This is the discovery call to make **before** any `get_current_value_from_topic` or `get_multiple_values_from_topic`. Topic subjects are not guessable, and guessing them is the most common way those two tools fail.

Topics are merged from three sources, and each result names which reported it:

- `analytics` - the broadest registry (Litmus Edge 4.0.x and newer)
- `devicehub` - per-tag input/output topics
- `digitaltwins` - per-instance payload topics

Present a markdown table: Topic, Sources, Direction, Interval. Group by source when no filter was given and the list exceeds 30 rows.

Verified against a live Edge. Each entry has `topic`, `sources` (a list), `direction`, and `format`; devicehub entries additionally carry `interval_ms` and `owner` (the tag name). Leave Interval blank for entries without it. Note that `direction` casing is inconsistent between sources, `output` from analytics and `Output` from devicehub, so normalise it before display rather than showing both spellings.

Expect large counts. A live Edge returned **634 topics** (devicehub 584, analytics 48, digitaltwins 8), so the default `limit=200` does not cover it and an unfiltered listing is rarely what the user wants. Push a `pattern` whenever the request implies one.

The response also carries per-source status. If any source was skipped or unavailable, say which and why in one line after the table - an empty result from one component does not mean the Edge has no topics.

Users may call these "datahub subscribe topics" or "pubsub topics"; they are the same thing.

No prose beyond the table and any source-status note.
