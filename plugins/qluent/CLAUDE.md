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

## Commands

- `/qluent:investigate` — Primary entry point. Bundles validation, trend, evaluation, and RCA in one call.
- `/qluent:trend` — Multi-period trend analysis. Use as a follow-up.
- `/qluent:rca` — Standalone root cause analysis. Use as a follow-up.
- `/qluent:compare` — Side-by-side tree comparison. Use as a follow-up.
- `/qluent:visualize` — Render the latest analysis as interactive HTML charts in the browser.
- `/qluent:setup` — Check installation and configuration.

**IMPORTANT: Always start with `/qluent:investigate`.** Do NOT manually chain `trend`,
`rca`, or `compare` as your first step. The `investigate` command bundles all of these
into a single call. Running individual commands is slower and misses agent-level analysis.

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
- **`trend-interpreter`** (sonnet) — Analyzes multi-period trends for anomalies, seasonal patterns, and inflection points.
- **`rca-validator`** (opus) — Cross-references RCA findings against trend data to confirm or refute top drivers.
- **`segment-explorer`** (sonnet) — Drills into top Shapley contributors to find which segments concentrate the movement.

The specialized agents (trend-interpreter, rca-validator, segment-explorer) are launched
in parallel by the investigate command or qluent-analyst for complex, broad, or low-confidence cases.

## Visualization

**Always use `/qluent:visualize` for charts.** Never write custom HTML, CSS, or Chart.js code. The plugin includes a styled dashboard renderer (`render-charts.sh`) with the Qluent design system — custom HTML will look wrong and miss brand styling.

All qluent analysis commands should pipe through `tee` to auto-save visualization data:

```bash
qluent trees investigate ... --json-output 2>&1 | tee /tmp/qluent-viz-data.json
```

This makes `/qluent:visualize` immediately available after any analysis.

## Use built-in skills, don't improvise

This plugin provides purpose-built skills for common workflows. **Always use them instead of improvising.**

- Charts or dashboards → `/qluent:visualize` (never write custom HTML)
- Analysis → `/qluent:investigate` (never manually chain CLI commands as a first step)
- Follow-ups → `/qluent:trend`, `/qluent:rca`, `/qluent:compare`, or `qluent trees levers` (not ad-hoc scripts)

The PostToolUse hook will remind you about available skills after qluent commands complete. Follow those reminders.

## When to use this plugin

Any question about metric movements, KPI changes, business performance, or root cause
analysis. Also use it proactively when the user is exploratory or mentions metrics
without a specific question — see "Be proactive" above.
