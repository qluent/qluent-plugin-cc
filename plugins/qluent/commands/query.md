---
description: Ask a business or data question — the default Qluent workflow; the backend builds and runs the query, you review the plan it returns and explain the answer
argument-hint: "<question> [--thread <id>]"
allowed-tools: Bash(which qluent), Bash(qluent *), Bash(jq *), mcp__qluent__qluent_compose_catalog, mcp__qluent__qluent_compose_query, AskUserQuestion, Read, Write
---

# Query (default workflow; review the plan the backend returns)

Use for general business and data questions, including aggregations,
breakdowns, rankings, row-level or entity lookups, arbitrary filters, and
explicit raw-data requests.

`qluent query` answers all of them. The backend resolves real values, drafts
the query, compiles it, runs it, and returns the answer, the SQL, the rows and
the plan that produced them. Your job is the analysis the backend cannot do
for you: check that the returned plan answers the question actually asked,
combine results safely, and explain the numbers. You do not author the query.

Follow the `qluent-interpretation` skill's routing and provenance rules
throughout.

## Step 0: Load the canonical protocols

Load both protocol modules **in a single message** — two parallel `Read`
calls, not two round trips:

```
${CLAUDE_PLUGIN_ROOT}/skills/qluent-interpretation/SKILL.md
${CLAUDE_PLUGIN_ROOT}/skills/compose-authoring/SKILL.md
```

The first owns the tree-vs-query decision rule ("Query-first routing"), the
provenance rules for presenting results, and the session workspace. The second
owns the plan node vocabulary you need to *edit* a returned plan, the
composition-safety rules (`grain`, `metrics[*].summable`), and the repair loop
for an edited plan that comes back invalid.

Do **not** load `qluent-tree-protocol`. Tree resolution, Shapley, elasticity
guardrails, window reuse and the companion-tree fallback belong to the
investigation workflow; a question this command answers never reaches them, and
loading them here costs roughly 3k tokens per session for material that goes
unused. If the routing check in Step 1 sends the question to
`/qluent:investigate`, that command loads the tree protocol itself.

## Step 1: Routing check

Apply the skill's query-first routing rule to `$ARGUMENTS` (minus any
`--thread <id>` flag). Only redirect when the user explicitly asks for
advanced deterministic KPI movement analysis (for example RCA, drivers,
trend classification, or levers) and the session catalog contains a matching
tree. General questions about a metric's value, breakdown, ranking, or change
remain here.

## Step 2: Run the query

Warn the user once before the first run:

```text
Queries run a full planning-and-execution workflow and can take several minutes.
```

Run with a long Bash timeout (600000 ms) and save the JSON for this session:

```bash
QLUENT_DIR=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-dir.sh") || exit 1
set -o pipefail
umask 077
question=$(command cat <<'QLUENT_QUERY'
<question>
QLUENT_QUERY
)
rm -f "$QLUENT_DIR/query-result.json"
qluent query "$question" --json-output | tee "$QLUENT_DIR/query-result.json"
```

This shape is load-bearing, not style:

- The quoted heredoc keeps the user-controlled question text inert — pasted
  directly inside quotes, `$(...)`, backticks, or embedded quotes in the
  question would execute or break the command. `command cat` bypasses any
  shell alias on `cat`.
- `pipefail` preserves qluent's exit status through the tee — without it a
  failed CLI run exits 0 (tee's status) and leaves an invalid saved file that
  downstream steps would silently consume.
- `umask 077` + `rm -f` recreate the saved file private to the current user
  each round (results can contain warehouse rows and SQL) and clobber any
  stale file or symlink already at the fixed path.

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

## Step 3: Clarification loop

Check the saved payload's `status` with `jq`. If it is `clarification_needed`,
present the clarification `message` and its `options` to the user with
`AskUserQuestion` (the user can always answer free-text), then re-run:

```bash
QLUENT_DIR=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-dir.sh") || exit 1
set -o pipefail
umask 077
answer=$(command cat <<'QLUENT_ANSWER'
<the user's answer>
QLUENT_ANSWER
)
rm -f "$QLUENT_DIR/query-result.json"
qluent query "$answer" --thread <thread_id> --json-output | tee "$QLUENT_DIR/query-result.json"
```

(The answer text is user-controlled too — same quoted-heredoc rule as Step 2.
The `<thread_id>` comes from the previous qluent response, so plain
substitution is fine there.)

Cap the loop at 3 rounds; after that, report the open ambiguity to the user
instead of looping further.

## Step 4: Review the returned plan

Read the plan and the SQL out of the saved payload before you read the rows to
the user. This is a short checklist because everything the old authoring rules
tried to prevent is now visible in what came back — a window on the wrong
column is in the `WHERE` clause, an invented filter value is a filter sitting
next to a zero-row result:

1. **Which column did the date window land on?** The compiled SQL names it.
   `params.date_range` filters the source base's date column, which is not
   always the date the question means (a customer table dated by registration
   answers "revenue in Q4" with revenue from customers who *registered* in
   Q4). Say which column carried the window when you present the answer.
2. **Did any filter return zero rows?** A filter next to an empty or
   suspiciously small result is a value that did not match. Do not present it
   as "no activity" without checking.
3. **Does the plan answer the question actually asked?** Scope, grain, and
   period, against the user's words — not against a plausible neighbouring
   question.

Wrong on any of those: edit the plan document — a field change, not a rewrite —
and re-run it through the compose path the `compose-authoring` skill
prescribes. That skill owns the node vocabulary, the invocation, and the repair
loop when an edited plan comes back `plan_invalid`; do not restate them here.
Cap the edits at 3 rounds, then say what you could not resolve.

Right: explain the numbers.

Two rules survive every engine change, because they are analysis rather than
extraction:

- **Never add results together unless `metrics[*].summable` says you can.**
  Averages, ratios and distinct counts are not addable; recompute them from
  their summable parts, or get them from one query at the right grain. Align
  results only on their `grain`. The `compose-authoring` skill has the detail.
- **A query result is not tree evidence.** Never blend it into Shapley
  attribution or other tree-derived claims.

If the payload carries no plan at all — a CLI or backend that predates the
returned-plan surface — say so once and review what you do have: the SQL
against the user's intent, per the presentation rules below. A missing plan
weakens the review; it does not license presenting an unchecked number.

## Step 5: Present the result

Extract fields from the saved file with `jq` rather than dumping the full
payload (it can hold up to 1000 rows) into the conversation:

```bash
QLUENT_DIR=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-dir.sh") || exit 1
jq '{status, answer, sql, plan, columns, row_count, grain, metrics, truncated, thread_id, download_url, google_sheets_url}' "$QLUENT_DIR/query-result.json"
jq '.data[:20]' "$QLUENT_DIR/query-result.json"
```

For a plan you edited and re-ran over the MCP tools, read those same fields off
the tool result directly — there is no file to open. For one re-run over the
CLI, the result is at `$QLUENT_DIR/plan-result.json` and carries the same
fields.

The payload shape may evolve with the CLI, so inspect fields by meaning rather
than hardcoding one exact schema. Compose the reply:

- Lead with the direct answer to the question.
- Render a compact markdown table of the first ~20 rows, noting
  "showing N of M rows" when `truncated` or `row_count` exceeds what you show.
- Show the returned `sql` in a code block, and name the column the date window
  landed on.
- Surface `Query thread: <thread_id>` plus the `download_url` /
  `google_sheets_url` links when present.
- Respect `grain` and `metrics[*].summable` before doing any arithmetic across
  results.
- Label provenance per the skill: "ad-hoc query" for a `qluent query` result,
  "composed query (deterministic)" for a plan you edited and ran yourself
  through the compose path — neither is deterministic tree evidence.

## Rules

- The backend builds the query; you review it. Never write or edit SQL
  yourself, and never author a plan from scratch here — edit the returned one,
  or re-ask through `qluent query`.
- Follow the `qluent-interpretation` skill for routing, provenance labeling,
  and the boundary between query results and tree-derived attribution; the
  `compose-authoring` skill owns the node vocabulary, the compose invocation,
  and composition safety.
- Follow-ups reuse `--thread <thread_id>`; a correction to the returned plan
  modifies the plan document and re-runs it through the compose path.
- For charts over the result, offer
  `/qluent:visualize --file $QLUENT_DIR/query-result.json` (or
  `--file $QLUENT_DIR/plan-result.json`)
  (insight-driven HTML; the `--simple` renderer does not support query
  payloads).
