---
description: Sample live values from a Litmus Edge DataHub topic via litmus-cli, with a bounded wait. Pass a topic (NATS wildcards allowed) and optionally a count.
---

Args: `$ARGUMENTS` (topic, optional message count)

Samples live values off the DataHub broker using `litmus-cli le data subscribe`. Preferred over the MCP `get_multiple_values_from_topic` tool here because `--wait` bounds the wait: the MCP tool blocks until every requested message arrives, so on a silent topic it stalls instead of failing fast.

Requires `litmus-cli` on `PATH` (`/litmus-cli-setup`) and a broker access-account API key as `NATS_TOKEN`, since the data plane authenticates separately from the REST API. If the token is missing the error will say so; do not misreport that as a dead topic.

1. Parse `$ARGUMENTS`: first token is the topic, a trailing number is the message count (default 10).

2. If no topic was given, discover first rather than guessing. Either `list_nats_topics` (MCP), or the CLI's own wildcard sweep, which shows everything the broker is publishing:

   ```bash
   litmus-cli le data subscribe '>' --limit 20 --wait 10s
   ```

3. Sample the topic. Quote it: `*` and `>` are both NATS wildcards and shell globs.

   ```bash
   litmus-cli le data subscribe 'devicehub.alias.Machine3.Temperature' --limit 10 --wait 30s
   ```

   `*` matches one token, `>` matches the rest. Raise `--wait` for slow-polling tags; a tag on a 60s interval will not deliver 10 messages in 30s.

4. Present a markdown table of the samples: Time, Value, and any quality field present. Convert timestamps to readable local time. After it, one line with the observed value range and the interval between messages, which is what tells the user whether the tag is polling as configured.

If fewer messages arrive than requested, the CLI still prints what it got and reports the shortfall on stderr. Show the partial data and say how many of how many arrived. That is a normal outcome, not an error.

A frozen value across every sample is worth calling out explicitly: a stuck sensor publishes plausible data indefinitely, so identical readings are a finding rather than a healthy result.

For historical values instead of live ones, use `litmus-cli le data poll` or the `litmus-verify-dataflow` skill. Live and historical are different layers and neither substitutes for the other.
