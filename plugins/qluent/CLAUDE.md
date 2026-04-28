# Qluent Metric Trees

Deterministic KPI analysis from the command line. This plugin provides slash commands
for investigating business metric movements using metric trees.

## Be proactive

**Don't wait for a perfect question.** When a user mentions metrics, KPIs, business
performance, or seems unsure what to ask, proactively offer to help. The session-start
hook injects available trees with their root metrics, sub-metric breakdowns, and
segment dimensions — use that context to tailor suggestions.

**Capabilities** (use these to explain what you can do):
- **Investigate** any metric movement — bundles validation, trend, evaluation, and root cause in one call
- **Root cause analysis** with Shapley attribution — mathematically exact driver decomposition
- **Trend analysis** — multi-period tracking with anomaly detection
- **Tree comparison** — side-by-side mechanism validation (volume vs mix vs rate shifts)
- **Cross-tree deep dive** — one consented executive narrative across all configured trees
- **Segment drill-down** — find which segments concentrate a movement
- **Sensitivity analysis** — elasticity coefficients showing which sub-metrics are the biggest levers for the root KPI
- **Lever impact analysis** — scenario-style estimates for how +1%, +5%, or +10% changes in a sub-metric would move the root KPI

**Match suggestions to tree structure:**
- Trees with children/sub-metrics → suggest root cause analysis
- Trees with dimensions → suggest segment drill-down
- Multiple trees → suggest comparison
- Any tree → suggest trend analysis or a weekly health check

**When in doubt, show don't tell** — run a quick `/qluent:investigate` on the broadest
tree for the latest period and present real findings rather than listing features.

**First-run orientation:** after login or plugin reload, orient the user from available
tree metadata. Name the connected project if the CLI reports it, list the available tree
ids, summarize what each tree is useful for, and offer one concrete first investigation.
Use `qluent whoami`, `qluent status`, and `qluent suggestions` only when those commands
are available. Do not probe made-up commands such as `qluent projects list`; if a command
is unsupported, fall back to `qluent trees list --json-output` and the session-start
tree context.

**Business-language routing hints:**
- sales, revenue, GMV, AOV, basket, incentives -> `revenue`
- growth, users, frequency, acquisition, reactivation -> `growth`
- delivery, late, failed, courier, ops quality -> `operations`
- conversion, checkout, cart, traffic, payment -> `conversion_funnel`

When the user asks what they can do, turn available tree metadata into project-specific
suggestions and end with a specific command, such as `/qluent:investigate revenue last month`.

## Commands

- `/qluent:investigate` — Primary entry point. Bundles validation, trend, evaluation, and RCA in one call.
- `/qluent:deep-dive` — Opt-in cross-tree executive read. Confirms cost, then runs `qluent trees deep-dive --json-output --period`.
- `/qluent:trend` — Multi-period trend analysis. Use as a follow-up.
- `/qluent:rca` — Standalone root cause analysis. Use as a follow-up.
- `/qluent:compare` — Side-by-side tree comparison. Use as a follow-up.
- `/qluent:visualize` — Render the latest analysis as interactive HTML charts in the browser.
- `/qluent:setup` — Check installation and configuration.

**IMPORTANT: Start with `/qluent:investigate` for single-tree questions and
`/qluent:deep-dive` only when the user explicitly wants a cross-business view.** Do NOT
manually chain `trend`, `rca`, `compare`, or separate investigations as your first step.
The bundled commands preserve deterministic server analysis and cost consent.

## Deterministic tree-query protocol

All metric values, deltas, decompositions, segment rankings, elasticity estimates, and recommendations based on numbers must be grounded in deterministic qluent JSON.

- Resolve tree context before querying. If the user asks a question, use session tree context or `qluent trees list --json-output` and pass an explicit tree id.
- Query root movement before explaining what changed.
- Query child decomposition before naming drivers.
- Drill into material drivers only after returned attribution or server recommendations identify them.
- Do not invent, back-calculate, interpolate, or combine metric math outside the returned qluent fields.
- Distinguish returned facts, interpretation, caveats, and recommendations.
- Cite provenance for material findings: result type, tree id or label, node/segment, and exact current/comparison windows.
- If evidence is missing, run the deterministic follow-up query or state the missing query instead of filling the gap.

For elasticity, leverage, impact, scenario, or "what if" follow-ups:
- Read the structured `investigate` JSON first, especially `levers`, `evaluation`, and `agent.recommended_next_steps`
- Reuse the exact current/comparison windows from the last investigation
- If the embedded `levers` block is not enough, run `qluent trees levers <tree_id> --current <same>:<same> --compare <same>:<same> --json-output`
- Label elasticity evidence as directional sensitivity unless the response explicitly supports causal language
- Recommend lever changes only when materiality, confidence/evidence coverage, and guardrail metrics are sufficient in the returned result
- When evidence is weak, suggest the next drill, comparison, or validation test instead of an action plan
- Never parse tool-result temp files or write ad-hoc scripts against prior bash output
- Do not rerun both JSON and non-JSON versions of the same qluent command unless JSON is genuinely insufficient

For unsupported segment cuts or breakdown requests:
- If the chosen tree does not expose the requested dimension, do not stop at that limitation
- Reuse the exact current/comparison windows and pivot to the closest tree that lists the missing dimension
- Use the original tree for KPI-specific reasoning and the fallback tree for the requested segmentation
- If no single tree supports every requested cut, combine the closest compatible views and state the boundary explicitly

## Supported periods

"last week", "this week", "last month", "this month", "last quarter",
"yesterday", "last 30 days", "week over week", "month over month", or explicit ISO dates
(YYYY-MM-DD:YYYY-MM-DD).

## Agents

- **`qluent-analyst`** — Orchestrator agent. Handles KPI questions autonomously: investigate, follow up, synthesize. **Also handles proactive guidance** — when users are exploratory or ask what's available, it runs a lightweight analysis and suggests follow-ups tailored to the configured trees.
- **`trend-interpreter`** (sonnet) — Multi-grain trend synthesis. Runs week+month trend in one pass and returns a single verdict (one-off, sustained, pre-existing drift, aggregation artifact) instead of two trend reports to reconcile.
- **`rca-validator`** (opus) — RCA triangulation. Cross-references each top driver against trend continuity AND a companion-tree compare for the same windows in one pass, returning one verdict per driver (confirmed / partial / contradicted / inconclusive).
- **`segment-explorer`** (sonnet) — Segment drill-down with automatic companion-tree pivot. When the requested cut is unsupported on the current tree, finds the closest compatible companion via the cached tree catalog, runs the segmentation there, and synthesizes both views in one call.

The specialized agents are launched in parallel by the investigate command or qluent-analyst
for complex, broad, or low-confidence cases. Each one collapses two or three deterministic
queries into a single triangulated answer, so the orchestrator's context stays narrow while
the verdict is fully grounded.

## Visualization and reporting

**Always use `/qluent:visualize` for charts and RCA reports.** When deterministic
RCA or elasticity JSON is available, shape it into the UI `RcaReportSpec` contract
first: set `outcomeShape`, populate ordered `sections[]`, and preserve `caveats[]`
and `sources[]`. Do not hand-roll report HTML when the UI report contract can be used.

Map qluent JSON into report sections consistently:
- root movement → `root_movement`
- RCA driver findings and direct contributors → `driver_decomposition`
- `segment_findings` → `material_segment_scan`
- `mix_shift` → `mix_shift`
- elasticity/levers → `elasticity_summary`
- `agent.recommended_next_steps` → `next_drills`

Preserve deterministic provenance, exact date windows, materiality, caveats, and
CLI/UI evidence labels: `observed_correlation`, `historical_elasticity`,
`model_estimate`, and `experiment_backed`.

Only use local HTML when the user explicitly asks for a local/browser demo, passes
`--simple` or `--html`, or the UI report contract is unavailable. Prefer the styled
dashboard renderer (`render-charts.sh`) for those fallback cases. Never write custom
HTML, CSS, or Chart.js code by hand for normal deterministic RCA or elasticity reports.
If values cannot be mapped from the qluent JSON or explicit user input, omit the section
or state the missing deterministic field/query instead of inventing a chart.

After a successful investigation, offer outcome-shaped report follow-ups when the data
supports them: an RCA report for driver decomposition, a mix-shift report when segment
or mix effects are present, or an elasticity report for a selected lever/outcome. Use
custom HTML only as an explicit local fallback when the UI report contract is unavailable.

All qluent analysis commands should pipe through `tee` to auto-save visualization data:

```bash
qluent trees investigate ... --json-output 2>&1 | tee /tmp/qluent-viz-data.json
```

This makes `/qluent:visualize` immediately available after any analysis.

## Cross-tree deep dives

Use `/qluent:deep-dive [period]` when the user asks what changed across the business,
requests an executive overview, or wants revenue, growth, operations, and funnel context
stitched together. It is opt-in only and must confirm before running unless the user
passes `--yes`.

The command depends on `qluent trees deep-dive` from qluent-cli#40. If the installed CLI
does not expose that subcommand, warn and exit instead of manually fanning out to
individual tree investigations.

Synthesize the returned bundle into one narrative:
- Headline: which root metrics moved
- Concentration: segments that repeat across trees
- Mechanism: volume vs basket vs conversion vs ops, backed by returned decomposition
- Caveats: errored trees, low confidence, sparse data, skipped cuts
- Next-best drills: ranked concrete `/qluent:*` commands across trees

## Use built-in skills, don't improvise

This plugin provides purpose-built skills for common workflows. **Always use them instead of improvising.**

- Charts or RCA reports → `/qluent:visualize` (prefer `RcaReportSpec`; never write custom HTML)
- Analysis → `/qluent:investigate` (never manually chain CLI commands as a first step)
- Cross-business executive read → `/qluent:deep-dive` (confirm cost; never auto-fire)
- Follow-ups → `/qluent:trend`, `/qluent:rca`, `/qluent:compare`, or `qluent trees levers` (not ad-hoc scripts)

The PostToolUse hook will remind you about available skills after qluent commands complete. Follow those reminders.

## When to use this plugin

Any question about metric movements, KPI changes, business performance, or root cause
analysis. Also use it proactively when the user is exploratory or mentions metrics
without a specific question — see "Be proactive" above.
