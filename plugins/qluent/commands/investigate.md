---
description: Investigate metric, KPI, or business performance changes (revenue, cost, conversion, sales, ROAS) using deterministic analysis
argument-hint: "[question or tree-id] [--period 'last week' | --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD]"
allowed-tools: Bash(qluent *), Read
---

# Investigate KPI movement

This is the primary entry point for all metric analysis. It bundles validation, trend, evaluation, and root cause analysis into a single call.

The qluent server is deterministic — it does NOT match natural-language questions to trees. YOU pick which tree to analyze when the user asks a question, by listing trees and matching against their metadata.

## Step 0: Load the canonical interpretation protocol

Before proceeding, `Read` the canonical interpretation Module:

```
${CLAUDE_PLUGIN_ROOT}/skills/qluent-interpretation/SKILL.md
```

It is the single source of truth for the deterministic-query protocol, evidence labels, elasticity guardrails, and the unsupported-cut fallback rule. The summary below is a contract reminder; the skill is normative.

## Deterministic query contract

- Resolve tree context before analysis. Do not let natural language stand in for a tree id.
- Run deterministic qluent JSON before making quantitative claims.
- Use the returned root movement before explaining a change.
- Use returned child decomposition, attribution, trend, comparison, lever, or segment fields before naming drivers or rankings.
- Keep provenance for material findings: command/result type, tree id or label, node/segment, and exact current/comparison windows.
- Separate facts, interpretation, caveats, and recommendations in the answer.
- Do not invent, back-calculate, or estimate metric math that is not present in the returned qluent JSON.

## Step 1: Decide whether `$ARGUMENTS` is a tree id or a question

If `$ARGUMENTS` is empty, ends with `?`, contains spaces, or contains words like `why`, `what`, `how`, `drove`, `drop`, `spike`, treat it as a **question** and go to Step 2.

If `$ARGUMENTS` is a single token (e.g. `revenue`, `order_volume`, `roas`), treat it as a **tree id** and skip to Step 3.

## Step 2: List the available trees and pick the best fit

Run:

```bash
qluent trees list --json-output
```

Read each tree's `id`, `label`, `description`, declared `dimensions`, and the labels of its child nodes. Match the user's question against this metadata. Bias toward:

- nouns in the question that match a tree label (e.g. "revenue" → revenue tree)
- verbs/concepts that match a child node label (e.g. "spend efficiency" → a roas-style node)
- dimensions named in the question (e.g. "by country" → tree that declares `country`)

If no tree is a clear winner, ask the user with `AskUserQuestion`, listing the top 2–3 candidates with their labels and descriptions. Do NOT guess silently.

## Step 3: Resolve the time windows

If the user provided `--current` / `--compare`, use those verbatim. Otherwise default to `--period "last week"` (or whatever period phrase the user gave).

## Step 4: Run the bundled investigation with an explicit tree id

Always pipe qluent output through `tee` to save visualization data. This makes `/qluent:visualize` immediately available.

```bash
qluent trees investigate <tree_id> --period "<period>" --json-output 2>&1 | tee /tmp/qluent-viz-data.json
```

For explicit date ranges:

```bash
qluent trees investigate <tree_id> --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD --json-output 2>&1 | tee /tmp/qluent-viz-data.json
```

## Step 5: Follow server recommendations

The response includes an `agent` section with `status`, `top_findings`, `gaps`, and `recommended_next_steps`. The `levers` section contains embedded elasticity/lever data when available. Follow the server's recommendations to determine what to do next — run the suggested follow-up commands before inventing your own.

For complex cases, the server may recommend launching specialized agents (`trend-interpreter`, `rca-validator`, `segment-explorer`) in parallel.

## Step 6: Summarize and suggest next steps

If the user is asking about elasticity, leverage, scenario impact, or "what if":

- Read `levers` first before running anything else.
- Reuse the exact current/comparison windows from the investigation bundle.
- If you need a deeper scenario table, run:

```bash
qluent trees levers <tree_id> --current <start>:<end> --compare <start>:<end> --json-output
```

- Treat the result as a local linear estimate from the current operating point, not a forecast.

If the user asks for a segment or breakdown that the current tree does not support:

- Reuse the exact current/comparison windows from the investigation bundle.
- Check the session tree context or run `qluent trees list --json-output` to find a compatible tree that exposes the missing dimension.
- Re-run the investigation or RCA on that fallback tree with the same windows.
- Synthesize both views instead of stopping: current tree for KPI-specific explanation, fallback tree for the requested segmentation.

- Lead with the top findings from the server response
- Report the exact current and comparison windows used
- End with 2-3 concrete follow-up suggestions tailored to what the data shows

## Rules

- Always pass an explicit `<tree_id>` to `investigate`, chosen client-side via Step 2 (`qluent trees list --json-output`).
- Always use `--json-output` when driving the workflow.
- Require deterministic query output before every quantitative claim.
- Cite result provenance for material findings.
- Prefer the embedded `levers` block before rerunning commands for impact questions.
- For full-year date ranges, if RCA times out, suggest quarterly breakdowns.
- If the user asks a follow-up, check if the existing data answers it before re-running.
- Never parse tool-result temp files or write ad-hoc scripts against prior bash output.
- Do not rerun both JSON and non-JSON versions of the same qluent command unless JSON is genuinely insufficient.
- If the requested cut is unsupported on the current tree, pivot to the closest compatible tree rather than handing control back.
