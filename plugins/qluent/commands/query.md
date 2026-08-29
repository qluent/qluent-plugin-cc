---
description: Ask a business or data question — the default Qluent workflow, answered by a deterministic composed QueryPlan when the catalog covers it, else via LLM-generated SQL
argument-hint: "<question> [--thread <id>]"
allowed-tools: Bash(which qluent), Bash(qluent *), Bash(jq *), AskUserQuestion, Read, Write
---

# Query (default workflow; composed plan first, NL fallback)

Use for general business and data questions, including aggregations,
breakdowns, rankings, row-level or entity lookups, arbitrary filters, and
explicit raw-data requests. Two engines answer these, tried in order:

1. **Composed plan** (`qluent plan`) — you author a typed QueryPlan against
   the project's query catalog; the backend compiles it deterministically.
   Preferred whenever the catalog covers the question.
2. **NL query** (`qluent query`) — the backend's LLM workflow (natural
   language -> generated SQL -> execution); non-deterministic. The fallback.

Follow the `qluent-interpretation` skill's routing and provenance rules
throughout.

## Step 0: Load the canonical protocols

Load both protocol modules **in a single message** — two parallel `Read`
calls, not two round trips:

```
${CLAUDE_PLUGIN_ROOT}/skills/qluent-interpretation/SKILL.md
${CLAUDE_PLUGIN_ROOT}/skills/compose-authoring/SKILL.md
```

The first owns the tree-vs-plan-vs-query decision rule ("Query-first routing")
and the provenance rules for presenting results; the second owns plan
authoring. Load them together rather than waiting to see whether the compose
path is available — it usually is, and a second sequential read costs more
than the occasional wasted one.

## Step 1: Read capability off the session banner — do not re-probe

`scripts/session-start.sh` already ran this session. It checked the CLI
version, probed `qluent plan`, and cached the catalog. Re-probing costs a tool
call, several seconds, and a permission prompt to learn something already in
your context. Read the answer off the banner instead:

| Session banner said | What to do |
|---|---|
| `Query catalog available: N bases, M metrics` | Compose path is on. Continue. |
| `qluent CLI <v> detected; composed plans need …` | NL only — skip Step 3, and pass the upgrade advice on if the user asks why it is slow. |
| `query_catalog that fails to load` | NL only — skip Step 3. |
| `Metric trees are not configured` (and nothing about a catalog) | NL only — skip Step 3. |
| `CLI is not installed` | Stop: *"qluent is not installed. Run `/qluent:setup` first, then retry `/qluent:query`."* |
| `CLI is installed but not configured` | Stop: *"Run `/qluent:setup` to authenticate."* |

Only if there is **no** qluent banner in this session at all — the hook did
not run — probe once, in a single call:

```bash
which qluent && qluent --version && qluent plan --help
```

Read it the same way: no qluent, stop and point at `/qluent:setup`; `qluent
plan` missing or a version below the minimum in
`${CLAUDE_PLUGIN_ROOT}/scripts/cli-requirements.sh`, skip Step 3 and answer
via the NL query. Never stop for a missing compose path, and never fall back
to guessing tree commands or writing SQL yourself.

## Step 2: Routing check

Apply the skill's query-first routing rule to `$ARGUMENTS` (minus any
`--thread <id>` flag). Only redirect when the user explicitly asks for
advanced deterministic KPI movement analysis (for example RCA, drivers,
trend classification, or levers) and the session catalog contains a matching
tree. General questions about a metric's value, breakdown, ranking, or change
remain on the query workflow.

## Step 3: Try a composed plan first

Skip this step when Step 1 said the compose path is unavailable, or when this
is a follow-up on an existing NL-query thread (`--thread <id>` given).

Run the compose path exactly as the `compose-authoring` skill prescribes it.
The skill owns every command in this step — the catalog fetch and its
projection, the coverage decision, plan authoring, the `qluent plan`
invocation, and the `plan_invalid` repair loop. Follow it there; do not
restate or re-derive those commands here, and do not substitute a variant of
your own.

This command owns only what happens to the outcome:

- `status: "ok"` — present per Step 6 (composed-plan variant). Done; skip
  Steps 4-5.
- `status: "plan_invalid"` after the skill's repair rounds, or a catalog that
  genuinely lacks the vocabulary — fall through to Step 4 and say which
  vocabulary was missing.
- Project has no query catalog, or any other hard error — fall through to
  Step 4.

## Step 4: Run the NL query

Warn the user once before the first run:

```text
Ad-hoc queries run a full NL->SQL->warehouse workflow and can take several minutes.
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

## Step 5: Clarification loop (NL query only)

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

(The answer text is user-controlled too — same quoted-heredoc rule as Step 4.
The `<thread_id>` comes from the previous qluent response, so plain
substitution is fine there.)

Cap the loop at 3 rounds; after that, report the open ambiguity to the user
instead of looping further.

## Step 6: Present the result

Extract fields from the saved file with `jq` rather than dumping the full
payload (it can hold up to 1000 rows) into the conversation.

For an NL-query result:

```bash
QLUENT_DIR=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-dir.sh") || exit 1
jq '{status, answer, sql, columns, row_count, truncated, thread_id, download_url, google_sheets_url}' "$QLUENT_DIR/query-result.json"
jq '.data[:20]' "$QLUENT_DIR/query-result.json"
```

For a composed-plan result:

```bash
QLUENT_DIR=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-dir.sh") || exit 1
jq '{status, sql, columns, row_count, grain, metrics, plan_summary}' "$QLUENT_DIR/plan-result.json"
jq '.data[:20]' "$QLUENT_DIR/plan-result.json"
```

The payload shape may evolve with the CLI, so inspect fields by meaning rather
than hardcoding one exact schema. Compose the reply:

- Lead with the direct answer to the question (NL results carry an `answer`;
  for plan results state it from the rows yourself).
- Render a compact markdown table of the first ~20 rows, noting
  "showing N of M rows" when `truncated` or `row_count` exceeds what you show.
- Show the returned `sql` in a code block. For NL results, check it matches
  the user's intent before presenting numbers; flag mismatches instead of
  papering over them. (A plan result's SQL is compiled from your plan — no
  intent check needed, but show it for transparency.)
- NL results: always surface `Query thread: <thread_id>` plus the
  `download_url` / `google_sheets_url` links when present.
- Plan results: respect `grain` and `metrics[*].summable` before doing any
  arithmetic across results (see the `compose-authoring` skill).
- Label provenance per the skill: "composed query (deterministic)" for plan
  results, "ad-hoc query" for NL results — neither is deterministic tree
  evidence.

## Rules

- Take CLI availability and compose capability from the session banner; probe
  only when no banner ran. Prefer the composed plan whenever the catalog
  covers the question.
- Follow the `qluent-interpretation` skill for routing, provenance labeling,
  and the boundary between ad-hoc results and tree-derived attribution; the
  `compose-authoring` skill owns plan authoring and repair.
- Follow-ups on an NL result reuse `--thread <thread_id>`; follow-ups on a
  plan result modify the plan document and re-run `qluent plan`.
- For charts over the result, offer
  `/qluent:visualize --file $QLUENT_DIR/query-result.json` (or
  `--file $QLUENT_DIR/plan-result.json`)
  (insight-driven HTML; the `--simple` renderer does not support query
  payloads).
- Never write or edit SQL yourself; the backend owns SQL generation. Author
  plans, or re-ask through `qluent query`.
