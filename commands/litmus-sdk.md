---
description: Search the full Litmus SDK / litmus-cli function catalog (~550 functions) for operations the dedicated tools don't cover.
---

Query or dotted prefix: `$ARGUMENTS`

The 62 dedicated MCP tools cover the common paths. Behind them, `litmus_sdk_discover` exposes the entire Litmus SDK surface, which is where anything unusual lives: integrations, flows, OPC, Unify, user management, device connection-property updates, restarts, deployments.

1. Call `litmus_sdk_discover`. If `$ARGUMENTS` looks like a dotted path (`le.integrations`, `lem.Get`), pass it as `prefix`. If it is a plain-English query, call with no prefix or with the most likely top-level package, then filter the returned catalog yourself.

   Package layout: Litmus Edge packages sit under `le.` (`le.devicehub`, `le.analytics`, `le.digitaltwins`, `le.flows`, `le.integrations`, `le.marketplace`, `le.opc`, `le.system`). `lem.*` and `unify.*` are top-level. `unify.*` appears only when the connection carries `UNS_URL`, `UNS_USERNAME`, and `UNS_PASSWORD`.

2. Present the matching functions as a markdown table: Function (full dotted path), Parameters, Read or Write.

   The response is `{success, prefix, functions}` where `functions` is a single **newline-delimited string**, not a list. Entries look like `  le.devicehub.ListDeviceTags(deviceID, limit, offset)`, indented under a package header line. Parse it into rows rather than printing the raw block.

   Classify as Read when the last path segment starts with `Get`, `List`, `Browse`, `Describe`, `Read`, `Search`, `Find`, `Query`, or `Count`. Everything else is Write. This is the server's own split: `litmus_sdk_read` rejects anything outside that prefix list, and `litmus_sdk_write` rejects anything inside it.

3. If exactly one function clearly answers the request and it is a Read, offer to run it via `litmus_sdk_read`. Do not run it unprompted.

4. Never call `litmus_sdk_write` from this command. Writes require showing the user the exact function and arguments, getting explicit approval, and only then passing `user_approved=true`. The `litmus-sdk-fallback` skill covers that flow.

Always check whether a dedicated tool already covers the request before reaching here - dedicated tools add caching, validation, and formatting that the raw SDK path does not.

Use only dotted paths this tool actually returned. Guessed paths fail, and a plausible-looking guess is the main way this goes wrong.
