# Qluent Metric Trees

Deterministic KPI analysis from the command line. This plugin provides slash
commands for investigating business metric movements using metric trees.

## Be proactive

When the user mentions metrics, KPIs, business performance, or seems unsure
what to ask, offer to help. The session-start hook injects the available trees
with their root metrics, sub-metric breakdowns, and segment dimensions — use
that to tailor suggestions.

**Capabilities to surface:**
- **Investigate** any metric movement — bundles validation, trend, evaluation, and RCA in one call
- **Root cause analysis** with Shapley attribution
- **Trend analysis** — multi-period tracking with anomaly detection
- **Tree comparison** — side-by-side mechanism validation
- **Cross-tree deep dive** — one consented executive narrative across all trees
- **Segment drill-down** — find which segments concentrate a movement
- **Sensitivity / lever impact** — elasticity coefficients and scenario estimates

**Match suggestions to tree structure:** trees with children → RCA; trees with
dimensions → segment drill-down; multiple trees → comparison; any tree → trend
or weekly health check.

**Show, don't tell**: when in doubt, run `/qluent:investigate` on the broadest
tree for the latest period and present real findings.

**First-run orientation**: after login or plugin reload, name the connected
project (if the CLI reports it), list available tree ids, summarize what each
is useful for, and offer one concrete first investigation. Use `qluent whoami`,
`qluent status`, `qluent suggestions` only when available; do not probe
made-up commands. Fall back to `qluent trees list --json-output`.

**Business-language routing hints:**
- sales, revenue, GMV, AOV, basket, incentives → `revenue`
- growth, users, frequency, acquisition, reactivation → `growth`
- delivery, late, failed, courier, ops quality → `operations`
- conversion, checkout, cart, traffic, payment → `conversion_funnel`

## Commands

- `/qluent:investigate` — Primary entry point. Bundles validation, trend, evaluation, and RCA.
- `/qluent:deep-dive` — Opt-in cross-tree executive read. Confirms cost.
- `/qluent:trend` — Multi-period trend analysis. Follow-up.
- `/qluent:rca` — Standalone root cause analysis. Follow-up.
- `/qluent:compare` — Side-by-side tree comparison. Follow-up.
- `/qluent:visualize` — Render the latest analysis as an `RcaReportSpec` (primary) or styled HTML (fallback).
- `/qluent:setup` — Check installation and configuration.

**Start with `/qluent:investigate` for single-tree questions and
`/qluent:deep-dive` only when the user explicitly wants a cross-business view.**
Do NOT manually chain `trend`, `rca`, `compare`, or separate investigations as
your first step — the bundled commands preserve deterministic server analysis
and cost consent.

## Protocol — see the qluent-interpretation skill

All metric values, deltas, decompositions, segment rankings, elasticity
estimates, and ranked recommendations must be grounded in deterministic qluent
JSON. Tree resolution, window reuse, provenance citation, Shapley/confidence
interpretation, elasticity guardrails, and the segment-cut fallback rule live
in the `qluent-interpretation` skill. Read it before driving the CLI; do not
restate or paraphrase its rules elsewhere.

## Visualization

For charts and RCA reports, use `/qluent:visualize`. It produces an
outcome-shaped `RcaReportSpec` with ordered `sections[]`, `caveats[]`, and
`sources[]`. Do not hand-roll HTML/CSS/Chart.js when the UI contract can be
used. Local HTML is a fallback only on `--simple`/`--html` or when the UI
contract is unavailable; use `render-charts.sh` for that path.

All qluent analysis commands pipe through `tee /tmp/qluent-viz-data.json` so
`/qluent:visualize` is immediately available.

## Cross-tree deep dives

`/qluent:deep-dive [period]` runs `qluent trees deep-dive --json-output --period`
(qluent-cli#40+). It is opt-in and confirms cost unless `--yes` is passed.
Synthesize the bundle into one narrative — never split into per-tree reports.

## Agents

- **`qluent-analyst`** — Orchestrator. Handles KPI questions autonomously and
  proactive guidance for exploratory users.
- **`trend-interpreter`** (sonnet) — Multi-period anomalies and inflection points.
- **`rca-validator`** (opus) — Cross-references RCA findings against trend data.
- **`segment-explorer`** (sonnet) — Drills into top Shapley contributors.

The specialized agents are launched in parallel by `investigate` or
`qluent-analyst` for complex, broad, or low-confidence cases.

## Hooks

The PostToolUse hook reminds you about available skills after qluent commands
complete and surfaces compatible fallback trees when a requested cut is
unsupported. Follow its suggestions.

## When to use this plugin

Any question about metric movements, KPI changes, business performance, or
root cause analysis — including proactively when the user is exploratory.
