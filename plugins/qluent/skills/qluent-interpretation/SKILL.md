---
name: qluent-interpretation
description: Internal reference for interpreting qluent CLI output — Shapley attribution, trend labels, RCA confidence scores
user-invocable: false
---

# Interpreting qluent results

The qluent server returns pre-interpreted analysis results. Present the server-provided labels, scores, and interpretations directly to the user.

Key principles:
- Quantitative claims must come from deterministic qluent JSON returned in the current workflow. Do not invent metric values, deltas, percentages, attribution shares, or segment rankings.
- Every material finding should cite its provenance in plain language: command/result type, tree id or label, node/segment, and current/comparison windows.
- Separate facts from interpretation, caveats, and recommendations. Facts are returned values; interpretation is the server-provided label or your synthesis from returned evidence.
- Confidence scores are evidence-coverage heuristics, not probabilities. Never describe them as likelihoods.
- Attribution values are computed server-side using Shapley values from cooperative game theory.
- Trend labels, anomaly flags, and mechanism interpretations are included in the server response.
- When a `levers` block is available, lever impacts are local linear estimates from the current operating point, not forecasts.

## Deterministic query protocol

Before making quantitative claims:

1. Resolve tree context from session tree metadata or `qluent trees list --json-output`.
2. Run the deterministic qluent command that returns the needed evidence, always with `--json-output`.
3. Use root movement from `qluent trees investigate`, `qluent rca analyze`, or another returned JSON field before explaining a change.
4. Use child decomposition, attribution, trend, comparison, lever, or segment fields only after the command has returned them.
5. Preserve result provenance in the answer: tree, node/segment, command type, and exact windows.

Never back-calculate missing values, interpolate absent segment rankings, or combine numbers from different windows as if they were one result. If the required deterministic output is missing, say what query is needed next.

Refer to the server response fields for all interpretation details.
