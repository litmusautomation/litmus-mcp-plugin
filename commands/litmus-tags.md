---
description: List tags for a Litmus Edge device with runtime state. Pass a device name, or omit for all devices.
---

Device: `$ARGUMENTS`

1. Call `get_devicehub_device_tags`. Pass `device_name` if `$ARGUMENTS` is non-empty; omit it to list tags across all devices.

   This tool is paginated. The response carries `total_count`, `has_more`, and `next_offset`. If `has_more` is true, call again with `offset=next_offset` until it is false, or until you have collected 300 tags. Do not report a partial page as if it were the full set - a device with more tags than one page silently looks smaller than it is.

2. If a device name was given, call `get_tag_status` with that `device_name` to get per-tag runtime state (`OK`, `Failed`, or `Unknown`). Join on tag name.

   If no device name was given, call `get_all_tags_status` instead. Note its default is `filter_status='not_ok'`, so it returns only problem tags - treat any tag absent from that result as `OK` rather than calling it unknown.

Present a markdown table: Device, Tag, Address, Data Type, State. Drop the Device column when a single device was requested.

Verified against a live Edge. Each tag record has `tag_name`, `id`, `address`, `data_type`, `description`, and nothing else. There is **no topic field**, so do not add a Topic column: a tag's NATS subject comes from `list_nats_topics` (or `/litmus-topics`), which reports `devicehub.alias.<DeviceName>.<TagName>` style subjects. `data_type` uses driver codes like `FLT32`, not Python-style names.

The tag-status records use capitalised keys: `ID`, `State`, `tag_name`, plus `device_name` and `device_id` on `get_all_tags_status`. Join on `tag_name`. `get_all_tags_status` echoes `filter_status` as `NOT_OK` even though you pass `not_ok`, and also returns `devices_checked`.

The paged response carries `total_count`, `has_more`, `next_offset`, and a `message` that spells out the next call, e.g. `Returned tags 0-5 of 31. Call again with offset=5 for the next page.`

After the table, one line: `N tags, M failed` using `total_count` for N, not the number of rows you printed. If you stopped paging at 300, say so explicitly.

If the device name matches nothing, say so and suggest `/litmus-devices`.

No commentary beyond the above.
