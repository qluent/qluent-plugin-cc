---
description: Investigate metric, KPI, or business performance changes (revenue, cost, conversion, sales, ROAS) using deterministic analysis
argument-hint: "[question or tree-id] [--period 'last week' | --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD]"
allowed-tools: Bash(qluent *), Read
---

# Investigate KPI movement

Primary entry point for metric analysis. Bundles validation, trend,
evaluation, and root cause analysis in one call.

Follow the `qluent-interpretation` skill for tree resolution, window handling,
provenance, Shapley/confidence interpretation, elasticity guardrails, and the
unsupported-cut fallback. Do not invent metric math.

## Step 0: Load the canonical interpretation protocol

Before proceeding, `Read` the canonical interpretation Module:

```
${CLAUDE_PLUGIN_ROOT}/skills/qluent-interpretation/SKILL.md
```

## Step 1: Question vs tree id

If `$ARGUMENTS` is empty, ends with `?`, contains spaces, or contains words
like `why`, `what`, `how`, `drove`, `drop`, `spike`, treat it as a question
and resolve a tree (Step 2). If it is a single token (`revenue`, `roas`,
`order_volume`), use it as the tree id and skip to Step 3.

## Step 2: Resolve a tree

Run `qluent trees list --json-output` and pick the best fit per the tree
resolution rules in the `qluent-interpretation` skill. If no tree is a clear
winner, ask the user to choose from the top candidates.

## Step 3: Resolve windows

Use `--current`/`--compare` verbatim if provided. Otherwise default to
`--period "last week"` (or whatever phrase the user gave).

## Step 4: Run the bundled investigation

Pipe through `tee` so `/qluent:visualize` is immediately available:

```bash
qluent trees investigate <tree_id> --period "<period>" --json-output 2>&1 | tee /tmp/qluent-viz-data.json
```

For explicit ranges:

```bash
qluent trees investigate <tree_id> --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD --json-output 2>&1 | tee /tmp/qluent-viz-data.json
```

## Step 5: Follow server recommendations

The response includes an `agent` section with `status`, `top_findings`,
`gaps`, and `recommended_next_steps`. The `levers` section embeds elasticity
data when available. Run the recommended follow-ups before inventing your own.

For complex cases, the server may recommend launching `trend-interpreter`,
`rca-validator`, or `segment-explorer` in parallel.

## Step 6: Summarize and suggest

- Lead with the top findings from the server response.
- State the exact current and comparison windows.
- End with 2-3 concrete follow-up suggestions tailored to the data.

For elasticity/leverage/"what if" follow-ups: read `levers` first, reuse the
exact windows, run `qluent trees levers <tree_id> --current <start>:<end>
--compare <start>:<end> --json-output` only when the embedded block is
insufficient. Apply the lever guardrails from the skill.

For unsupported segment cuts: pivot to a compatible tree with the same
windows; do not stop at the limitation.

For full-year ranges: if RCA times out, suggest quarterly breakdowns.

If the user asks a follow-up, check whether the existing data answers it
before re-running.
