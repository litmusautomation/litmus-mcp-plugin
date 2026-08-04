---
name: litmus-sdk-fallback
description: Reach Litmus operations the 62 dedicated MCP tools do not cover, via the litmus_sdk_discover / litmus_sdk_read / litmus_sdk_write fallback over the full ~550-function SDK. Use when a requested Litmus operation has no dedicated tool - updating device connection properties, enabling or restarting devices, integrations, flows, OPC, Unify, user management - or when the user asks about the Litmus SDK, litmus-cli, or a specific Litmus function or endpoint.
---

The dedicated tools cover common read paths and a handful of writes. Everything else in Litmus lives behind three fallback tools that dispatch to the `litmus-cli` binary over the full SDK surface (~550 functions).

Do not tell the user an operation is impossible or that the server is read-only because no dedicated tool exists. Check the catalog first. Conversely, do not reach here when a dedicated tool covers the request: dedicated tools add caching, validation, and response formatting that the raw path lacks.

## The escalation ladder

1. **Dedicated MCP tool** when one covers it.
2. **These three fallback tools** for a single uncovered operation, in-conversation.
3. **`litmus-cli` directly in the shell** for bulk work, multiple edges, the data plane, `jq` pipelines, or anything the user wants as a reusable command. See the `litmus-cli` skill.
4. **Raw API** only for what none of the above reach.

Steps 2 and 3 hit the same binary and the same function catalog, so they are equivalent in reach and differ only in ergonomics. Pick by the shape of the work: one lookup mid-conversation is step 2, the same operation across forty devices is step 3, because it collapses into one shell loop instead of forty tool calls.

Step 3 also reaches things step 2 cannot express: the curated `le` and `lem` command groups, the `le data` plane with bounded live sampling, `--profile` switching between edges, and offline commands needing no connection.

One difference matters more than the others. **The CLI has no approval gate.** The protection described below is enforced by the MCP server, not by the binary, so when you drop to a shell you carry that discipline yourself.

## The three tools

- **`litmus_sdk_discover`** - browse the catalog. Optional `prefix` narrows it (`le.devicehub`, `le.integrations`, `lem.Get`). Read-only and free; use it liberally.
- **`litmus_sdk_read`** - invoke one read-only function. Accepts only functions whose **last path segment** starts with `Get`, `List`, `Browse`, `Describe`, `Read`, `Search`, `Find`, `Query`, or `Count`. Anything else is rejected.
- **`litmus_sdk_write`** - invoke one state-changing function. Requires `user_approved=true`. Rejects read-only functions, so the two are strictly partitioned.

## Package layout

Litmus Edge packages sit under the `le.` prefix:

`le.devicehub`, `le.analytics`, `le.digitaltwins`, `le.flows`, `le.integrations`, `le.marketplace`, `le.opc`, `le.system`

`lem.*` (Edge Manager) and `unify.*` are top-level. `unify.*` is listed only when the connection carries `UNS_URL`, `UNS_USERNAME`, and `UNS_PASSWORD`, since it cannot authenticate without them - its absence means credentials are missing, not that Unify is unavailable.

## Always discover before calling

Call `litmus_sdk_discover` and use the dotted paths and parameter names it returns, exactly. Never guess a path or a parameter name, and never adapt one from documentation, an older SDK version, or another function's signature. Guessed paths fail, and a plausible-looking guess wastes a turn while looking like a real capability gap.

If discovery returns nothing for a prefix, widen it (`le.` instead of `le.integrations`) before concluding the operation does not exist.

## Reads

Call `litmus_sdk_read` with `function` and an `args` object keyed by the parameter names discovery reported. Run these freely; they change nothing.

If a read is rejected as not read-only, the function is a write despite how it reads in English. Route it through the write path rather than trying to force it.

## Writes: the approval gate

`litmus_sdk_write` fails unless `user_approved=true`, and that gate exists because the catalog includes create, update, delete, restart, and deploy operations against live industrial equipment, mostly with no undo.

Required sequence, every time:

1. Show the user the **exact** dotted function path and the **complete** argument object you intend to send.
2. State plainly what it will change, and that it cannot be undone when that is true.
3. Wait for explicit approval in the conversation.
4. Only then call with `user_approved=true`.

Never set `user_approved=true` preemptively, in anticipation, or because the user approved a *similar* call earlier. Approval is per call, per argument set. Batching several writes under one approval defeats the gate; if you need three writes, show all three and get agreement on all three, then call them one at a time and report each result before continuing.

For writes that modify an existing object, `litmus_sdk_read` the current state first and show the user the diff rather than just the new payload. "Set pollingInterval to 500" is easy to approve; it is much easier to approve correctly when the user can see it is currently 100.

If the user declines, stop and say what remains unchanged. Do not look for another route to the same effect.

## When the CLI is missing

These three tools run through the `litmus-cli` binary. The server resolves it from `LITMUS_CLI_PATH`, then `PATH`, then downloads the pinned release (checksum-verified) into `~/.cache/litmus-mcp-server/bin/` on first use.

If a call fails saying the binary is unavailable, the machine running the MCP server most likely has no outbound access to GitHub. Run `/litmus-version` to see the resolved path and version. The fix is `./scripts/install-cli.sh` (downloads and checksum-verifies a `cli-v*` release), or install it manually and set `LITMUS_CLI_PATH`. This is a server-host problem, not an Edge problem, and not a credentials problem.

`/litmus-version` also shows when the running CLI differs from the pinned release, which happens when an older copy earlier on `PATH` wins.

Note that the server's private copy under `~/.cache/litmus-mcp-server/bin/` is not on `PATH`, so its presence does not mean the user can run `litmus-cli` in a shell. `/litmus-cli-setup` handles that separately.

## Output

Report the function called, the arguments, and the result. Say explicitly that it came from the SDK fallback rather than a dedicated tool, and name the dedicated tool if one turns out to cover it after all - that is worth knowing for next time.

For discovery, do not paste the whole catalog. Show the handful of functions that plausibly match, with parameters, and say how many others were returned.
