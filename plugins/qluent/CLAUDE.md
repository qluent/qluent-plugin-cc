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
- `/qluent:setup` — Check installation and configuration.

**IMPORTANT: Always start with `/qluent:investigate`.** Do NOT manually chain `trend`,
`rca`, or `compare` as your first step. The `investigate` command bundles all of these
into a single call. Running individual commands is slower and misses agent-level analysis.

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

## When to use this plugin

Any question about metric movements, KPI changes, business performance, or root cause
analysis. Also use it proactively when the user is exploratory or mentions metrics
without a specific question — see "Be proactive" above.
