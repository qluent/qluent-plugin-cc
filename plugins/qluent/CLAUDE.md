# Qluent Metric Trees

Deterministic KPI analysis from the command line. This plugin provides slash commands
for investigating business metric movements using metric trees.

## Be proactive

**Don't wait for a perfect question.** When a user mentions metrics, KPIs, business
performance, or seems unsure what to ask, proactively:

1. **Tell them what you can do** — explain the plugin's capabilities in plain language
   (deterministic root cause analysis, Shapley attribution, trend tracking, tree comparison).
2. **Suggest specific analyses** based on the metric trees available in their project.
   Reference the session-start context for tree names, root metrics, dimensions, and
   sub-metric structure.
3. **Run a quick investigation** if the user is exploratory — show them a real result
   rather than just listing features. A live example is more useful than a capabilities list.

### Example proactive responses

- User says "I'm looking at revenue" → suggest: "I can investigate what drove revenue
  changes last week — want me to run that? I'll show you Shapley attribution for each
  sub-metric."
- User says "what should I check?" → run a quick investigate on the broadest tree for
  the latest period, summarize findings, and suggest follow-ups.
- User says "tell me about ROAS" → explain what the ROAS tree measures, run a trend
  analysis, and highlight any anomalies.

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

Use qluent commands when the user asks about:
- Why a metric changed (revenue, cost, ROAS, conversion, sales, etc.)
- What drove a KPI movement
- How business performance is trending
- Root cause analysis of metric changes
- Comparing different metric breakdowns

**Also use this plugin proactively when:**
- The user mentions metrics, KPIs, or business performance without a specific question
- The user asks what analyses are available or what they should look at
- The user seems to be exploring or getting started — show them what's possible with a live example
