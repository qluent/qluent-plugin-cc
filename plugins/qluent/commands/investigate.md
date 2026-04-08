---
description: Investigate metric, KPI, or business performance changes (revenue, cost, conversion, sales, ROAS) using deterministic analysis
argument-hint: "[question or tree-name] [--period 'last week' | --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD]"
allowed-tools: Bash(qluent *)
---

# Investigate KPI movement

This is the primary entry point for all metric analysis. It bundles validation, trend, evaluation, and root cause analysis into a single call.

## Step 1: Run the investigation

Always pipe qluent output through `tee` to save visualization data. This makes `/qluent:visualize` immediately available.

If the user asked a natural-language question:

```bash
qluent trees investigate --question "$ARGUMENTS" --json-output 2>&1 | tee /tmp/qluent-viz-data.json
```

If the user named a specific tree and/or date windows, construct the command explicitly:

```bash
qluent trees investigate <tree_id> --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD --json-output 2>&1 | tee /tmp/qluent-viz-data.json
```

For natural-language periods:

```bash
qluent trees investigate <tree_id> --period "last week" --json-output 2>&1 | tee /tmp/qluent-viz-data.json
```

## Step 2: Parse the JSON response

Read the investigation bundle in this order:

1. `agent.status` — determines what to do next
2. `agent.top_findings` — fastest summary
3. `agent.gaps` — what evidence is missing
4. `agent.recommended_next_steps` — follow these before inventing your own drill-down
5. `evaluation`, `trend`, `root_cause` — detailed evidence

## Step 3: Act on agent.status

- **`resolved`**: Continue to Step 4 (broad-range enrichment) if the time range is quarter+, otherwise go to Step 6 (summarize).
- **`needs_tree_selection`**: Inspect `match.top_candidates`, pick the strongest tree (or ask the user), and re-run with the explicit tree_id.
- **`needs_more_data`** or **`partially_resolved`**: Run the first relevant command from `agent.recommended_next_steps`. Do NOT invent your own drill-down until you've exhausted the recommended steps.

## Step 4: Broad-range enrichment (mandatory for quarter+)

When the investigation spans a quarter or more, **always** run these in parallel alongside or after the primary investigation. Do not skip this step or ask the user first — just do it.

1. **Companion trees**: Run `qluent trees list --json-output` (if not already known) and investigate the most relevant companion trees. For example, if you investigated `revenue`, also investigate `order_volume` and `net_revenue` to decompose volume vs value vs margin.

   ```bash
   # Run in parallel
   qluent trees investigate <companion_tree_1> --current <same windows> --json-output
   qluent trees compare <primary_tree> <companion_tree> --current <same windows> --compare <same windows> --json-output
   ```

2. **Monthly trend**: Run a monthly trend on the primary tree covering the full range to show seasonality and identify which months drove the annual change.

   ```bash
   qluent trees trend <tree_id> --periods 12 --grain month --as-of <end_date> --json-output
   ```

3. **Cross-reference**: Use the companion tree data to determine the mechanism — did growth come from volume, basket size, mix shift, or rate changes?

## Step 5: Parallel agent deep-dive (when warranted)

For complex investigations, launch specialized agents in parallel using the Agent tool:

- **`trend-interpreter`** (sonnet): Analyze multi-period trends to identify patterns, anomalies, and seasonal effects
- **`rca-validator`** (opus): Cross-reference RCA findings against trend data to filter out data artifacts
- **`segment-explorer`** (sonnet): Drill into top Shapley contributors to find which segments concentrate the movement

Use this step when:
- The user explicitly asks for a deeper analysis
- RCA confidence is low and validation would help
- Multiple competing drivers need independent verification

## Step 6: Summarize and suggest next steps

- Lead with the top findings
- Verify against `root_cause.conclusion.takeaways` and supporting evidence
- If agents were used, synthesize their outputs into a cohesive narrative
- Always report the exact current and comparison windows used

**Always end with proactive suggestions.** Based on the data you found, suggest 2-3 concrete follow-ups the user could explore. Tailor these to what the data actually shows — don't offer generic options. Examples:

- If one category or channel underperformed: "Want me to break down Bottoms by month to find where the gap opened?"
- If volume vs value tells an interesting story: "Revenue grew on flat orders — want a channel-by-channel AOV analysis?"
- If seasonality is visible: "The Jul–Sep soft spot stands out — want me to compare that quarter against the prior year?"
- If there's rich multi-tree or trend data: "I can visualize this as an interactive dashboard — want me to build that?" (Use `/qluent:visualize`)

Don't just ask "want me to dig deeper?" — name the specific analysis and why it's interesting based on what you found.

## Rules

- Always use `--json-output` when driving the workflow
- For full-year date ranges, if RCA times out, suggest quarterly breakdowns
- If the user asks a follow-up, check if the existing data answers it before re-running
