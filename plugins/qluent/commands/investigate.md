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

## Step 2: Follow server recommendations

The response includes an `agent` section with `status`, `top_findings`, `gaps`, and `recommended_next_steps`. The `levers` section contains embedded elasticity/lever data when available. Follow the server's recommendations to determine what to do next — run the suggested follow-up commands before inventing your own.

For complex cases, the server may recommend launching specialized agents (`trend-interpreter`, `rca-validator`, `segment-explorer`) in parallel.

## Step 3: Summarize and suggest next steps

- Lead with the top findings from the server response
- Report the exact current and comparison windows used
- End with 2-3 concrete follow-up suggestions tailored to what the data shows

## Rules

- Always use `--json-output` when driving the workflow
- Prefer the embedded `levers` block before rerunning commands for impact questions
- For full-year date ranges, if RCA times out, suggest quarterly breakdowns
- If the user asks a follow-up, check if the existing data answers it before re-running
- Never parse tool-result temp files or write ad-hoc scripts against prior bash output
- Do not rerun both JSON and non-JSON versions of the same qluent command unless JSON is genuinely insufficient
