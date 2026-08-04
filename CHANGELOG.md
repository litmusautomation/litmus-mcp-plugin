# Changelog

All notable changes to the Litmus MCP plugin are recorded here.

Versions track the plugin, not the MCP server it vendors. The vendored server
version is pinned separately in `pyproject.toml` and reported by
`get_mcp_server_info`.

## 0.2.0

### Fixed

The vendored MCP server source in `src/` had fallen roughly 2,000 lines behind
upstream. Because the plugin ships a copy of the server rather than depending on
it, the drift was silent: the plugin kept launching while quietly missing tools
and fixes.

- Resynced `src/` to upstream litmus-mcp-server v1.4.1.
- Restored `list_nats_topics` and `get_mcp_server_info`, which were missing
  entirely.
- Removed `get_device_logs`, a tool the plugin shipped that does not exist
  upstream.
- Restored the checksum-verified `litmus-cli` self-install in
  `sdk_cli_tools.py`. Without it, `litmus_sdk_discover`, `litmus_sdk_read`, and
  `litmus_sdk_write` failed with "binary not found", so the entire SDK fallback
  path of roughly 550 functions was unreachable from the plugin.
- Corrected dependency pins. `mcp[cli]` was `>=1.17.0` against an upstream floor
  of `>=1.28.1,<2`, and `litmussdk` was 2.6.0 against 2.7.5. Added `starlette`
  and `urllib3`, which `src/` imports directly; dropped `aiofiles` and
  `pydantic`, which it does not.
- `scripts/install-deps.sh` hard-failed on machines where `uv` provides Python
  3.12+ but no versioned `python3.1x` is on `PATH`, which is common because uv
  keeps its toolchains in its own data dir. It now falls back to
  `uv python find`, and uses `uv` for venv creation when present. A cold install
  went from failing outright to about two seconds.
- Added `static/icon.png` so the server advertises its brand icon on
  initialize, and a root `pyproject.toml` pin record so it reports version
  1.4.1 instead of null.

Prompt-side corrections, all found by checking commands and skills against the
real tool schemas:

- `/litmus-network` called `get_network_interface_info` expecting a list of
  interfaces. It returns a single interface, defaulting to `eth0`. The command
  now enumerates first.
- `litmus-lem-audit` called `lem_get_license_expiry` with `days`, where the
  required parameter is `expiry_days`, so the call always failed. It also used
  `lem_list_device_versions` to derive version spread, but that returns the
  project's version catalog rather than a per-device distribution.
- `/litmus-lem-fleet` ignored that `lem_list_devices` defaults to `limit=10`,
  so any fleet larger than ten was reported as ten.
- `/litmus-tags` ignored `has_more` and `next_offset` on
  `get_devicehub_device_tags`, silently truncating.
- `/litmus-devices` presented `get_devicehub_devices` output as liveness, but
  that tool returns configuration only. Liveness needs
  `get_device_connection_status`.
- `litmus-troubleshoot` read NATS topics without calling `list_nats_topics`
  first, which is guessing at subjects that are not derivable from device names.
- The `litmus-expert` agent claimed the server was read-only for LEM writes and
  directed users to the Python SDK, when `litmus_sdk_write` covers exactly that
  behind an approval gate.
- Tool and resource counts corrected throughout to 62 tools and 19 resources.

### Added

- `scripts/check-source-drift.sh`, which compares file contents, the pinned
  version, and the actual tool-name lists against upstream. Comparison is
  content-based rather than mtime-based, so a fresh CI clone does not report
  permanent false drift.
- `.github/workflows/audit.yml`, running offline consistency checks on push and
  pull request: every tool name referenced by `commands/`, `skills/`, and
  `agents/` exists in the vendored `src/`, both plugin manifests are valid JSON
  with matching versions, and every documented `litmus-cli` command exists in
  the binary (soft-gated, since that step fetches one).

  The source comparison deliberately stays out of CI. The vendored tree is a
  pin, so being behind upstream is the normal state between syncs rather than a
  build failure, and a job that went red on every upstream merge would train
  people to ignore it. `check-source-drift.sh` is the first step of the release
  checklist instead.
- `litmus-cli` as a first-class path rather than something reachable only
  through MCP tool dispatch, which exposes just `list` and `run`:
  - `skills/litmus-cli`, covering connection profiles and multi-edge work, the
    `le data` plane, bulk `jq` patterns, and the write discipline the binary
    does not enforce on its own.
  - `scripts/install-cli.sh`, which downloads a release asset and verifies it
    against the release `SHA256SUMS` rather than piping a remote script into a
    shell.
  - `/litmus-cli-setup` and `/litmus-watch`.
- New skills: `litmus-verify-dataflow` (traces a data point from tag to topic to
  measurement and reports which hop fails), `litmus-onboard-device` (device
  creation is only step two of six), `litmus-sdk-fallback` (reaching uncovered
  operations, including the write approval gate).
- New commands: `/litmus-health`, `/litmus-topics`, `/litmus-twins`,
  `/litmus-sdk`, `/litmus-version`.

Commands went from 9 to 16 and skills from 2 to 6.

### Changed

- `scripts/sync-from-server.sh` no longer excludes `server.py`. It was excluded
  to protect a local `StdioRequestContext` patch that is now upstream, so there
  is no local fork left to preserve. The script also writes the upstream
  version, ref, and commit into `pyproject.toml` as a pin record.

### Fixed after live validation

Verified against a live Litmus Edge 4.0.14 sandbox with 10 devices, 222 tags, and
634 NATS topics. Reading tool schemas caught argument bugs; only running the
tools caught these response-shape bugs, all of which would have produced empty
or invented table columns:

- `/litmus-devices` asked for an Enabled column. `get_devicehub_devices` returns
  only `name`, `id`, `driver`, `description`, `metadata`, `properties`. There is
  no enabled flag.
- `/litmus-tags` asked for a Topic column. `get_devicehub_device_tags` returns
  `tag_name`, `id`, `address`, `data_type`, `description`. Topics come from
  `list_nats_topics`.
- `/litmus-drivers` asked for a Version column. Driver records carry only `name`
  and `id`. The catalog is also 153 entries on a stock Edge, so the command now
  groups by protocol family instead of dumping it.
- `/litmus-network` asked for MAC, Link, and Speed. The response has none of
  them, despite the tool description advertising all three. It returns
  `{name, idx, type, wan, inet: {address, gateway, mtu, type}, inet6}`.
  Firewall rules key on `policy`, not `action`.
- `/litmus-containers` promised resource usage. The response is raw Docker shape
  with no CPU or memory stats.
- `/litmus-twins` assumed an instance count on the model record. Model and
  instance fields are capitalised (`ID`, `Name`, `ModelID`, `Topic`), and the
  count has to be derived by grouping instances on `ModelID`.
- `/litmus-topics` and `/litmus-sdk` corrected for real shapes: topic entries
  also carry `direction`, `format`, `interval_ms`, and `owner`, with
  inconsistent `direction` casing between sources; `litmus_sdk_discover` returns
  `functions` as one newline-delimited string, not a list.

`litmus-onboard-device` was validated by creating, configuring, and deleting a
throwaway Generator device on the live Edge. It corrected the workflow itself:

- **Removed the enable step, which does not exist.** DeviceHub devices in 4.0.14
  have no `Enabled` field, the SDK catalog exposes no device enable or disable
  function, and a tag reached `State: OK` seconds after creation with nothing
  enabled. The skill previously told you to enable via the SDK fallback, which
  would have sent the reader looking for a function that is not there.
- A freshly created device returns `Properties: []`, so there are no driver
  defaults to inherit and setting connection properties is mandatory, not a
  tidy-up. `create_devicehub_device` also returns a `next_steps` field.
- Documented the real device object shape and the fact that `Properties` is a
  list of `{Key, Value}` pairs, not an object, unlike `create_devicehub_tag`'s
  `properties` argument, which is an object. Named `le.devicehub.UpdateDevice`
  as the confirmed function.
- Corrected verification expectations: immediately after a tag reaches `OK`,
  `list_nats_topics` returns zero matching topics and connection status is
  `no_data` with `last_seen: null`. Both lag the first poll cycles, and the
  skill previously implied `stale`, which cannot be true for a device that has
  never published.
- Added teardown, since there is no delete-device tool:
  `delete_devicehub_tag` per tag then `le.devicehub.DeleteDeviceByName` via
  `litmus_sdk_write`. Both verified.

The approval-gated write path (`litmus_sdk_write` with `user_approved=true`) is
confirmed working against a live Edge, as is `create_devicehub_tag` with a
driver register type and a `properties` override.

Two upstream defects found and worked around rather than hidden:

- `get_system_event_stats` reports `health.data_storage_used_pct` as a negative
  number. A live Edge returned `-95.1` for `totalSize 42001116, dataSize
  13869980, dataFree 27066176`, where the answer is about 33 percent. The
  affected commands now compute it from the raw fields. The same tool returns
  `success: true` while substituting per-field `*_error` keys, so a successful
  response can contain no usable numbers.
- All three live-value tools (`get_current_value_of_devicehub_tag`,
  `get_current_value_from_topic`, `get_multiple_values_from_topic`) fail on an
  Edge with a self-signed certificate. The NATS client attempts TLS regardless
  of `NATS_TLS=false` and then rejects the certificate, while every REST call in
  the same tool succeeds. `VALIDATE_CERTIFICATE=false` does not reach the broker
  connection. `litmus-troubleshoot` and `litmus-verify-dataflow` now name this
  explicitly so it is not misdiagnosed as a dead device, and route to
  `litmus-cli le data subscribe --nats-no-tls`, which is verified working
  against the same Edge.

### Known limitations

- Codex loads the MCP server and skills only. Its plugin manifest schema
  documents no `commands` or `agents` fields, so the 16 slash commands and the
  `litmus-expert` agent are available in Claude Code but not in Codex.
- Source drift against upstream is not checked automatically. Run
  `./scripts/check-source-drift.sh ../litmus-mcp-server` before tagging.
- Live-value tools do not work against an Edge with a self-signed certificate,
  because broker TLS cannot be disabled through the MCP server. Use
  `litmus-cli le data subscribe --nats-no-tls` until that is fixed upstream.
- The read-only tools backing every command, plus the device create, update,
  tag-create, tag-delete and device-delete paths, have been exercised against a
  live Edge 4.0.14. Still unrun: `run_docker_container_on_litmusedge`,
  `start_packet_capture` and `stop_packet_capture`, the digital twin creators,
  and every LEM tool. So `litmus-lem-audit` remains unvalidated end to end.

## 0.1.0

Initial release. MCP server for Claude Code and Codex, with 9 slash commands,
2 skills, and the `litmus-expert` agent.
