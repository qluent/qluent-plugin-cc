# Qluent Metric Trees

Deterministic KPI analysis from the command line. This plugin provides slash commands
for investigating business metric movements using metric trees.

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

## Agent

The `qluent:qluent-analyst` agent handles KPI questions autonomously. It runs the full
investigate -> follow-up -> synthesize workflow without manual intervention. Use it
proactively when the user asks about metric movements.

## When to use this plugin

Use qluent commands when the user asks about:
- Why a metric changed (revenue, cost, ROAS, conversion, sales, etc.)
- What drove a KPI movement
- How business performance is trending
- Root cause analysis of metric changes
- Comparing different metric breakdowns
