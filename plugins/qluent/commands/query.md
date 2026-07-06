---
description: Ask an ad-hoc natural-language data question answered via SQL over the warehouse (row-level, entity lookups, cuts outside the metric trees)
argument-hint: "<question> [--thread <id>]"
allowed-tools: Bash(which qluent), Bash(qluent *), Bash(jq *), AskUserQuestion, Read
---

# Ad-hoc natural-language query

Use when the user asks a data question the metric trees cannot answer:
row-level or entity lookups, arbitrary aggregations or filters, or explicit
raw-data requests. The question is answered by the qluent backend's LLM query
workflow (natural language -> generated SQL -> warehouse execution), so the
result is not deterministic tree evidence — follow the `qluent-interpretation`
skill's ad-hoc query routing and provenance rules throughout.

## Step 0: Load the canonical interpretation protocol

Before anything else, `Read` the canonical interpretation module:

```
${CLAUDE_PLUGIN_ROOT}/skills/qluent-interpretation/SKILL.md
```

Its "Ad-hoc query routing" section owns the tree-vs-query decision rule and
the provenance rules for presenting query results.

## Step 1: Check CLI availability and capability

Verify qluent is installed:

```bash
which qluent
```

If qluent is missing, stop and tell the user:

```text
qluent is not installed. Run /qluent:setup first, then retry /qluent:query.
```

Then verify the installed CLI supports the query subcommand:

```bash
qluent query --help
```

If the command exits non-zero or says the subcommand is unknown, stop and tell
the user:

```text
This qluent CLI does not support `qluent query` yet. Upgrade to the release
that includes the query command (qluent-cli#92), then retry `/qluent:query`.
```

Do not fall back to guessing tree commands or writing SQL yourself.

## Step 2: Routing check

Apply the skill's ad-hoc query routing rule to `$ARGUMENTS` (minus any
`--thread <id>` flag). If the question is actually a KPI movement /
"why did X change" question that maps to a configured tree in the session
catalog, redirect to `/qluent:investigate` instead of running an ad-hoc query,
and say why in one sentence.

## Step 3: Run the query

Warn the user once before the first run:

```text
Ad-hoc queries run a full NL->SQL->warehouse workflow and can take several minutes.
```

Run with a long Bash timeout (600000 ms) and save the JSON for this session:

```bash
set -o pipefail
qluent query "<question>" --json-output | tee /tmp/qluent-query-result.json
```

`pipefail` preserves qluent's exit status through the tee — without it a
failed CLI run exits 0 (tee's status) and leaves an empty or invalid saved
file that downstream steps would silently consume.

If the user passed `--thread <id>` (or this is a follow-up / clarification
answer), add `--thread <thread_id>`. Keep stderr out of the saved file:
progress and CLI errors must stay on stderr so the file round-trips through
`jq .` as clean JSON. Each round overwrites the file; the `thread_id` in the
payload is the durable handle.

If qluent exits non-zero:

- Surface the CLI error plainly.
- If the error indicates auth/configuration, tell the user to run `/qluent:setup`.
- If the stream was interrupted, suggest re-running the same command.
- Do not synthesize an answer from partial shell text.

## Step 4: Clarification loop

Check the saved payload's `status` with `jq`. If it is `clarification_needed`,
present the clarification `message` and its `options` to the user with
`AskUserQuestion` (the user can always answer free-text), then re-run:

```bash
set -o pipefail
qluent query "<the user's answer>" --thread <thread_id> --json-output | tee /tmp/qluent-query-result.json
```

Cap the loop at 3 rounds; after that, report the open ambiguity to the user
instead of looping further.

## Step 5: Present the result

Extract fields from the saved file with `jq` rather than dumping the full
payload (it can hold up to 1000 rows) into the conversation:

```bash
jq '{status, answer, sql, columns, row_count, truncated, thread_id, download_url, google_sheets_url}' /tmp/qluent-query-result.json
jq '.data[:20]' /tmp/qluent-query-result.json
```

The payload shape may evolve with the CLI, so inspect fields by meaning rather
than hardcoding one exact schema. Compose the reply:

- Lead with the `answer`.
- Render a compact markdown table of the first ~20 rows, noting
  "showing N of M rows" when `truncated` or `row_count` exceeds what you show.
- Show the returned `sql` in a code block and check it matches the user's
  intent before presenting numbers; flag mismatches instead of papering over
  them.
- Always surface `Query thread: <thread_id>` plus the `download_url` /
  `google_sheets_url` links when present.
- Label provenance per the skill: these numbers come from an ad-hoc query
  (the SQL above), not from a deterministic tree investigation.

## Rules

- Check for qluent and the `query` subcommand before running.
- Follow the `qluent-interpretation` skill for routing, provenance labeling,
  and the boundary between ad-hoc results and tree-derived attribution.
- Follow-ups on the same result reuse `--thread <thread_id>`.
- For charts over the result, offer
  `/qluent:visualize --file /tmp/qluent-query-result.json`
  (insight-driven HTML; the `--simple` renderer does not support query
  payloads).
- Never write or edit SQL yourself; the backend owns SQL generation. Re-ask
  through `qluent query` instead.
