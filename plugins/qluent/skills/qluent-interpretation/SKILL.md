---
name: qluent-interpretation
description: Internal reference for interpreting qluent CLI output — Shapley attribution, trend labels, RCA confidence scores
user-invocable: false
---

# Interpreting qluent results

The qluent server returns pre-interpreted analysis results. Present the server-provided labels, scores, and interpretations directly to the user.

Key principles:
- Confidence scores are evidence-coverage heuristics, not probabilities. Never describe them as likelihoods.
- Attribution values are computed server-side using Shapley values from cooperative game theory.
- Trend labels, anomaly flags, and mechanism interpretations are included in the server response.
- When a `levers` block is available, lever impacts are local linear estimates from the current operating point, not forecasts.

Refer to the server response fields for all interpretation details.
