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

## Elasticity and lever guardrails

Elasticity output is directional decision support, not causal proof. Treat it as a measured association from the returned sample window unless the server response explicitly includes causal validation.

When interpreting `levers`, `elasticity`, scenario, or impact fields:

- Label the evidence type: elasticity estimate, Shapley attribution, trend corroboration, segment concentration, or server-provided causal validation.
- State the exact sample windows used and the dimensions or cuts included in the returned result.
- Report the server-provided confidence, materiality, data-quality warnings, and guardrail metrics before recommending any lever change.
- Distinguish correlation and sensitivity from causality. Do not write that a lever "caused" root KPI movement unless a returned field explicitly supports causal language.
- Treat low confidence, immaterial effects, sparse windows, volatile segments, or guardrail warnings as reasons to suggest the next drill or test, not an action plan.
- For scenario rows such as +1%, +5%, or +10%, say they are local linear estimates from the current operating point and may not hold outside the observed range.

Recommendations require all of these conditions:

- The lever effect is material in the returned result, not just directionally interesting.
- Confidence or evidence coverage is sufficient according to the server response.
- Guardrail metrics do not show an offsetting risk or unresolved data-quality warning.
- The recommendation is scoped to the returned sample window and segment/dimension context.

If those conditions are not met, recommend the next best drill instead. Examples include extending the window, validating the same lever across another segment, running `/qluent:compare`, or asking for an experiment/instrumentation check.

Acceptable phrasing:

- "The returned elasticity table shows a directional association: in 2026-04-13:2026-04-19 vs 2026-04-06:2026-04-12, conversion rate has the largest local sensitivity, with sufficient evidence coverage and no guardrail warning. Treat the +5% row as a local estimate, not a forecast."
- "This is weak evidence for action. The lever is directionally positive, but the returned confidence is low and the segment sample is sparse, so the next step is to drill by channel before changing spend."
- "The RCA attributes most of the movement to average order value, while the elasticity estimate says conversion rate is the larger local lever. That is a mechanism hypothesis, not proof that changing conversion caused the prior movement."

Unacceptable phrasing:

- "Increase conversion by 5% and revenue will rise by the scenario amount."
- "The elasticity proves conversion caused the revenue drop."
- "This lever is the best action" when confidence, materiality, guardrails, or sample windows are missing.

Refer to the server response fields for all interpretation details.
