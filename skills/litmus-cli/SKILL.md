---
name: litmus-cli
description: Drive Litmus Edge, Edge Manager, and Unify from the shell with the litmus-cli binary. Use for bulk or scripted work across many devices or tags, for switching between multiple edges via profiles, for live topic sampling and time-series polling on the data plane, and for the many areas with no dedicated MCP tool (Node-RED flows, device users, OPC UA config, analytics processors, integrations, marketplace images). Also use when the user names litmus-cli, asks for a command to run themselves, or wants output piped into jq or a script.
---

`litmus-cli` is a single Go binary that talks to Litmus Edge, Edge Manager, and Unify and prints JSON. Upstream positions it as the preferred interface for agentic tasks, and it reaches considerably more than the 62 MCP tools do.

Run it with Bash. Every command prints JSON to stdout, so `jq` composes naturally.

## MCP tools or the CLI?

Use **MCP tools** for single, conversational lookups. They add caching, validation, and formatting, and they need no shell.

Use **the CLI** when any of these apply:

| Situation | Why the CLI |
|---|---|
| Same operation over many devices or tags | One shell loop instead of N tool calls |
| Output needs filtering, joining, or reshaping | Pipe to `jq` |
| More than one Edge or LEM tenant | `--profile` switches; MCP is bound to one env-configured Edge |
| Live topic sampling | `le data subscribe --limit --wait` bounds the wait; `get_multiple_values_from_topic` blocks with no timeout |
| Historical query needing an InfluxQL condition | `le data poll --filter` |
| Flows, device users, OPC config, analytics, integrations, images | No dedicated MCP tool exists |
| The user wants a command to run or keep | A CLI line is reusable; a tool call is not |
| No network to the Edge | The `*-defaults` commands work offline |

Do not shell out for something a dedicated MCP tool already answers in one call. `/litmus-devices` beats `litmus-cli le devices` for a one-off question.

## Check availability first

```bash
litmus-cli --version
```

If it is missing, install it and point the user at `/litmus-cli-setup`:

```bash
./scripts/install-cli.sh          # downloads, verifies SHA256, installs to ~/.local/bin
./scripts/install-cli.sh --check  # report versions only
litmus-cli update                 # self-update once installed
litmus-cli update --check         # report without updating
```

The MCP server keeps its own private copy under `~/.cache/litmus-mcp-server/bin/` for the `litmus_sdk_*` tools. That copy is intentionally not on `PATH`, so it does not make CLI use possible from the shell. The two are independent, and their versions can differ; `/litmus-version` shows what the server resolved.

## Authentication and profiles

Settings resolve in this order, later winning:

```
profile (~/.litmus/<profile>.json)  <  .env file  <  environment  <  flags
```

Three ways to authenticate, in descending preference:

```bash
litmus-cli login                  # browser sign-in, all products
litmus-cli login le               # just Litmus Edge
```

`login` opens a local page with one card per product (`le`, `lem`, `unify`) and saves each to the profile as it succeeds. For Litmus Edge it sends the username and password once, directly to the device, to mint a dedicated OAuth API credential for the CLI; the password itself is never stored. Prefer this: it is the only path that avoids handling long-lived secrets yourself.

Inside a container, a remote shell, or a web terminal the browser cannot reach the CLI's localhost, so bind and open manually:

```bash
litmus-cli login --bind 0.0.0.0 --port 4005 --no-browser
```

On loopback the page is plain HTTP and never leaves the machine. On any other bind address it is HTTPS with a certificate generated for that login session, and the browser warns once about the unknown certificate.

Non-interactively, write a profile directly. The flags are the uppercase variable names, which is unusual enough to get wrong from memory:

```bash
litmus-cli config set \
  --EDGE_URL https://10.0.0.5 \
  --EDGE_API_CLIENT_ID abc \
  --EDGE_API_CLIENT_SECRET xyz \
  --EDGE_VALIDATE_CERTIFICATE false

litmus-cli config show            # secrets masked
```

`config set` updates only the keys you pass and preserves the rest. Never echo a secret into the transcript when a profile or environment already holds it.

For a one-off connection without saving anything:

```bash
litmus-cli --edge-url https://10.0.0.5 --client-id abc --client-secret xyz --insecure le version
```

`--insecure` skips TLS verification, which self-signed device certificates usually require. Use `--profile <name>` to target a specific saved Edge, and say which profile you used when reporting results, since the same command against a different profile is a different machine.

Missing configuration produces a clear error naming the absent keys and suggesting `login`, so treat that message as the diagnosis rather than guessing at credentials.

## Command groups

```bash
litmus-cli le   --help    # Litmus Edge device, including the 'le data' data plane
litmus-cli lem  --help    # Edge Manager
litmus-cli list [prefix]  # browse the 570+ SDK functions
litmus-cli run  <path>    # call any SDK function by dotted path
```

Curated Edge shortcuts, several of which have no MCP equivalent:

- Devices and tags: `le devices`, `le tags <deviceID> [limit] [offset]`, `le drivers`, `le system-info`, `le version`
- Digital twins: `le dt-models`, `le dt-instances`
- Marketplace: `le containers`, `le images`
- Analytics: `le analytics-groups`, `le processor-library`
- Integrations: `le providers`, `le instances`, `le provider-catalog`
- Node-RED: `le flows`
- Access and protocol: `le users`, `le opc-config`
- Offline, no connection needed: `le processor-library-defaults`, `le provider-catalog-defaults`, `le driver-cache-versions`

Edge Manager: `lem companies`, `lem projects`, `lem devices`.

**`le tags` takes a device ID, not a device name.** The MCP tool takes a name, so a name copied from `/litmus-tags` will not work here. Resolve it first:

```bash
DEV=$(litmus-cli le devices | jq -r '.[] | select(.name=="Machine3") | .id')
litmus-cli le tags "$DEV" 1000
```

Paging is positional: `le tags <deviceID> [limit] [offset]`, default 100, max 1000. The response carries `TotalCount` and `Last`; page past 1000 with `offset` rather than assuming one call covered the device.

## The data plane

`le data` reads live values from the DataHub broker (NATS, 4222) and history from the time-series DB (InfluxDB, 8086).

**These authenticate separately from the REST API.** Edge credentials alone are not enough, which is the most common surprise here:

- Broker: an access-account API key. Litmus Edge UI under System > Access Control > Tokens, or `litmus-cli run le.system.CreateAccessAccount`. Pass as `--nats-token` or `NATS_TOKEN`.
- InfluxDB: a database user. Litmus Edge UI under DataHub > DB users. Pass as `--influx-user` / `--influx-password`.

Hosts default to the `EDGE_URL` host; override with `--host`. Persist all of it with `config set`.

Live values:

```bash
litmus-cli le data subscribe 'devicehub.alias.MyDevice.*' --limit 5
litmus-cli le data subscribe '>' --limit 20 --wait 10s
```

`--limit` stops after N messages, `--wait` caps the wait (default 30s). NATS wildcards apply: `*` matches one token, `>` matches the rest, so `'>'` shows everything the broker publishes. That makes `subscribe '>'` a genuine discovery tool when a topic subject is unknown, and it is bounded, unlike the blocking MCP equivalent. If fewer than `--limit` messages arrive before `--wait`, what did arrive still prints and the shortfall is reported on stderr, so a partial result is normal rather than a failure.

History:

```bash
litmus-cli le data measurements --contains Machine
litmus-cli le data poll 'Machine3.024F0542-540E-4556-8445-13F5158A9E67' --last 15m --limit 50
litmus-cli le data poll 'Machine3.024F...' --filter "\"tag\" = 'Temperature'"
```

Measurements are one per device, named `<DeviceName>.<DeviceID>`, and a device measurement holds all of that device's tags as rows. So narrow to a single tag with `--filter`, not by guessing a per-tag measurement name. `--last` takes an InfluxDB duration, `--limit` defaults to 500 (`0` means no limit), and **timestamps are epoch milliseconds**, so convert before showing them to a user.

## Bulk patterns

This is the main reason to be here. Keep loops bounded and print progress for anything long.

```bash
# Tag counts for every device
litmus-cli le devices | jq -r '.[] | "\(.id)\t\(.name)"' | while IFS=$'\t' read -r id name; do
  n=$(litmus-cli le tags "$id" 1000 | jq '.TotalCount // (.tags | length)')
  printf '%s\t%s\n' "$name" "$n"
done

# Same question across several edges
for p in plant-a plant-b plant-c; do
  echo "== $p"
  litmus-cli --profile "$p" le devices | jq -r '.[].name'
done

# Fleet version spread from LEM
litmus-cli lem devices | jq -r '.[].version' | sort | uniq -c | sort -rn
```

Field names vary by command and version, so run one command and inspect the real JSON before writing a loop over it. Do not assume a key exists because it appeared in a different command's output.

## Writes and safety

`litmus-cli run` reaches the whole SDK, including create, update, delete, restart, and deploy against live industrial equipment, mostly with no undo. The CLI has **no approval gate** of its own; the gate that protects `litmus_sdk_write` does not exist here.

So supply it yourself. Before running any state-changing `run`:

1. Show the user the exact command line, including the full `--args` payload.
2. Say what it changes and that it cannot be undone when that is true.
3. Wait for explicit approval.
4. Run it, and report the result before doing the next one.

```bash
litmus-cli list le.devicehub          # discover the exact path and parameter names
litmus-cli run le.devicehub.ListDevices
litmus-cli run lem.GetCompanyProjects --args '{"companyName":"acme"}'
litmus-cli run le.devicehub.UpdateDevice --args-file payload.json
```

Use `--args-file` (or `-` for stdin) for large payloads rather than fighting shell quoting on a long JSON string; a mangled payload sent to a write function is exactly the failure worth avoiding. Read the current object first and show the user a diff, not just the new value.

Use only dotted paths that `litmus-cli list` actually returned. Never guess a path or a parameter name.

Treat `--insecure` as a deliberate choice for self-signed device certificates, not a default to sprinkle on failures.

## Reporting

Show the command you ran, then the synthesized result. Never paste raw JSON when a table or a count answers the question, but do keep the command visible so the user can rerun or adapt it.

Say which profile the results came from. State any bound you imposed (a loop cap, `--limit`, `--wait`, `--last`) so a partial answer is not mistaken for a complete one.
