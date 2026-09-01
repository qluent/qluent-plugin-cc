---
name: qluent-interpretation
description: Canonical core protocol for driving qluent — query-first routing between trees, composed plans and NL queries, provenance labels, grounding rules, and the session workspace. Loaded by every qluent command and agent; the metric-tree half lives in the qluent-tree-protocol skill.
user-invocable: true
---

# Qluent interpretation protocol

The qluent server is deterministic. It returns pre-interpreted analysis (root
movement, Shapley attribution, trend labels, mechanism interpretations,
confidence scores, elasticity tables). Your job is to drive it correctly and
present what it returns — not to recompute, infer, or paraphrase the math.

This skill is the core every qluent workflow needs: which engine answers a
question, how to label and ground what comes back, and where results land on
disk. The metric-tree half — tree resolution, window reuse, AnalysisRun
handles, Shapley, elasticity guardrails, the unsupported-cut fallback, and
report precedence — lives in the `qluent-tree-protocol` skill, loaded by
`/qluent:investigate`, `/qluent:deep-dive`, `/qluent:visualize` and the tree
agents. Plan authoring and composition safety live in the `compose-authoring`
skill. A question the query workflow answers needs neither of those.

Both skills are the single source of truth for their half of the protocol.
Commands and agents should reference them by name rather than restating the
rules.

## Query-first routing

**Query is the default workflow. Metric trees are the advanced workflow for
explicit deterministic KPI analysis. Within queries, composed plans beat the
NL fallback whenever catalog coverage is complete.**

Route to a metric tree (`/qluent:investigate`, `qluent-analyst` tree workflow)
when the user explicitly asks for deterministic movement analysis, RCA,
drivers, trend classification, mix-shift, or sensitivity/levers AND the
question maps to a configured tree's root metric, child node, or declared
dimension in the session catalog.

Keep the default query workflow when ANY of these hold:

1. **General metric question** — the user asks for a value, aggregation,
   breakdown, ranking, comparison, or change without requesting deterministic
   tree attribution.
2. **Row/entity level** — the question needs individual records or entities
   (specific orders, customers, transactions; "list", "show me",
   "top N <records>", "which <entities>").
3. **No tree coverage** — the metric, dimension, or filter is not declared by
   any tree in the catalog, and the unsupported-cut companion-tree fallback
   cannot cover it either.
4. **SQL-shaped ask** — the question is an arbitrary lookup, count, join, or
   filter combination rather than a movement explanation ("how many X where
   Y", "average Z per W last month").
5. **Explicit raw-data ask** — the user wants a table, an export, a
   spreadsheet, or the SQL itself.

For those questions, prefer a **composed plan** (`qluent plan`, protocol in
the `compose-authoring` skill) whenever the CLI supports it and the project's
query catalog (`qluent catalog`) covers the question's bases, metrics and
dimensions: composed plans are deterministic and catalog-checked. Use the NL
`qluent query` only when the catalog lacks the vocabulary, the shape exceeds
the plan node algebra, or the CLI/backend predates the compose surface.

Do not require a tree before answering a data question. Fall through to a
composed plan, then the NL query. Once the user explicitly chooses an
investigation or asks for tree-specific attribution, keep that workflow
deterministic and never re-derive its numbers with a query.

Provenance labels differ by engine:

- **Composed plan** results compile deterministically from the closed-world
  catalog: label them "composed query (deterministic)" and cite the returned
  `sql`. They are still not tree evidence — never blend them into Shapley
  attribution or other tree-derived claims.
- **NL query** results are produced by LLM-generated SQL: label them "ad-hoc
  query" (with the returned SQL as the citation) and verify the returned
  `sql` matches the user's intent before presenting numbers. Run with
  `qluent query "<question>" --json-output`, check `status`
  (`ok` / `clarification_needed` / `error`), and answer clarifications or ask
  follow-ups by re-running with `--thread <thread_id>` from the previous
  response.
- **Tree** results are deterministic evidence and carry the labels and
  guardrails in the `qluent-tree-protocol` skill.

## Quantitative claims

Every metric value, delta, and ranked recommendation must be grounded in
deterministic qluent JSON returned during the current workflow.
Always use `--json-output`.

- Do not invent, back-calculate, interpolate, or combine metric math outside
  the returned qluent fields.
- Never parse tool-result temp files or write ad-hoc scripts against prior
  bash output.
- Do not rerun both JSON and non-JSON versions of the same command unless JSON
  is genuinely insufficient.

For every material finding, cite provenance in plain language: result type,
tree id or label, node/segment, exact current/comparison windows. Separate
returned facts from interpretation, caveats, and recommendations.

If a required field is missing, run the deterministic follow-up query or state
the missing query — do not fill the gap from prose.

## Session paths

A handful of JSON files form the rendezvous between qluent producers and
consumers within a session. The workspace itself and the query-path files are
declared here; the investigation, deep-dive and tree-catalog files are declared
in the `qluent-tree-protocol` skill, so the query path does not carry them.
Each file is declared exactly once, in the module whose readers use it, and
every producer, consumer, test fixture, and the `qluent-orientation` skill
surface references it by the same name. The set of files allowed to mention
each one is pinned by `tests/test_session_paths.sh` — adding a new consumer
requires updating that allowlist on purpose.

### The session workspace, `$QLUENT_DIR`

They all live in one directory, private to this user and this Claude session:

```
${TMPDIR:-/tmp}/qluent-$UID-$CLAUDE_CODE_SESSION_ID
```

`scripts/session-start.sh` creates it 0700 and announces the resolved path in
the session banner. **Every Bash call that touches one of these files starts
with the prelude that resolves it:**

```bash
QLUENT_DIR=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-dir.sh") || exit 1
```

`session-dir.sh` creates the directory, refuses a directory owned by someone
else, and exits non-zero with a reason rather than printing a path it could
not make safe — so `|| exit 1` is load-bearing, not decoration. A `$QLUENT_DIR`
reference in a command that did not run the prelude is a bug: the variable is
empty and the path resolves to the filesystem root.

Never rendezvous on a fixed `/tmp/qluent-*.json` path. Those were global to
the machine, so a second session against a different project overwrote the
first session's catalog — after which plans were authored against the wrong
project's vocabulary — and a file owned by another user could be neither
removed nor replaced under `/tmp`'s sticky bit, which the old code did not
check before announcing the catalog as cached. Scoping by uid and session id
removes both failure modes; `scripts/session-paths.sh` is the one declaration
of the naming scheme, shared by the hooks.

The directory is disposable. Nothing in it needs to survive the session: the
durable handles are the `thread_id` inside a query result and the
`analysis_run_uuid` inside an investigation, not these files.

### `$QLUENT_DIR/query-result.json` — latest ad-hoc query result
- **Producer:** `/qluent:query` (and `qluent-analyst` when it falls back to
  `qluent query`) tee the latest query JSON to this path; each clarification
  round or follow-up overwrites it.
- **Consumers:** `scripts/post-bash.sh` surfaces the thread id, pending
  clarifications, and download links; `/qluent:visualize --file` reads it for
  ad-hoc tabular charts (insight-driven HTML only — the `RcaReportSpec` and
  `--simple` renderer paths do not apply to query payloads).
- **Schema:** the `qluent.query.v1` contract — `status`, `answer`, `sql`,
  `columns`, `data` (≤1000 inline rows), `row_count`, `truncated`,
  `download_url`, `google_sheets_url`, `thread_id`, optional `clarification`
  `{message, options}`.
- **Freshness:** holds only the most recent round; the `thread_id` inside it
  is the durable handle for continuing the conversation, not this file.

### `$QLUENT_DIR/catalog.json` — session query catalog
- **Producer:** `scripts/session-start.sh` writes it at session start when the
  CLI/backend support composed plans; otherwise the session's first catalog
  fetch, issued by the `compose-authoring` skill — the single owner of that
  invocation — on behalf of `/qluent:query` or an agent.
- **Consumers:** plan authoring reads the vocabulary (`catalog.*`) and the
  QueryPlan JSON schema (`plan_schema`) from it instead of re-fetching.
- **Schema:** the `qluent.catalog.v1` contract — `catalog` (bases, metrics,
  relationships, derived_dimensions, and the three alias maps) and
  `plan_schema`, which sits beside `catalog` rather than inside it. Each base
  carries date and scope metadata (`date_column`,
  `default_date_lookback_days`, `scope_keys`, …) alongside its `columns`; the
  `compose-authoring` skill's projection keeps all of it, because that
  metadata decides which column a plan's date window lands on.

### `$QLUENT_DIR/plan.json` / `$QLUENT_DIR/plan-result.json` — composed plan round
- **Producer:** plan authoring per the `compose-authoring` skill writes the
  QueryPlan document to `$QLUENT_DIR/plan.json` and redirects the `qluent plan`
  result to `$QLUENT_DIR/plan-result.json`; each repair round overwrites both.
  That skill owns the exact invocations — no other file restates them.
- **Consumers:** the repair loop reads `status`/`error`;
  `/qluent:visualize --file` reads the result for tabular charts the same way
  it reads query results.
- **Schema:** the `qluent.plan.v1` contract — `status`
  (`ok` / `plan_invalid` / `error`), `sql`, `columns`, `data`, `row_count`,
  `grain`, `metrics` (per-metric `kind` + `summable`), `plan_summary`.
