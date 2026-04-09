---
name: qluent-interpretation
description: Internal reference for interpreting qluent CLI output — Shapley attribution, trend labels, RCA confidence scores
user-invocable: false
---

# Interpreting qluent results

## Shapley-value attribution (Top contributors)

Each child's contribution to the parent's delta is computed using Shapley values from cooperative game theory. This answers: "how much of the parent's change is attributable to each child?"

Key properties:
- **Contributions sum to the parent delta** — they fully explain the change
- **A share > 100%** means this child drove MORE change than the total, offset by others
- **A negative share** means this child moved against the overall trend
- This is NOT a simple percentage breakdown — it accounts for formula interactions (e.g., in ROAS = revenue / spend, both numerator and denominator are attributed correctly)

## Trend labels

- **accelerating**: positive and growing faster
- **decelerating**: positive but slowing down
- **recovering**: was negative, now positive
- **declining**: was positive, now negative
- **volatile**: direction changes frequently
- **stable**: changes within +/-2%

## RCA confidence

`conclusion.confidence` and `conclusion.confidence_score` are NOT probabilities. They are evidence-coverage heuristics.

- `confidence_type = evidence_coverage_heuristic` means the score reflects how much deterministic evidence is available
- Higher scores mean broader coverage across driver, time-slice, segment/mix-shift, and mechanism evidence
- Warnings and unresolved branches reduce the score
- Use `evidence_types_present`, `evidence_types_missing`, and `confidence_factors` to explain why the score is high, medium, or low
- Never describe `80%` as "80% likely to be true." Describe it as an evidence or coverage score

## Sensitivity and elasticity

Evaluation nodes now include `sensitivity` and `elasticity` fields (when available from the backend).

**Sensitivity** (`sensitivity`) = d(root)/d(node). The partial derivative of the root metric with respect to this node. Answers: "if this node increases by 1 unit, the root changes by this many units."

**Elasticity** (`elasticity`, shown as `ε` in CLI output) = (sensitivity * node_value) / root_value. Answers: "a 1% change in this node causes this % change in the root."

Interpreting elasticity:
- **ε > 1** (elastic): the root is more than proportionally sensitive to this node — high-leverage driver
- **ε = 1** (unit-elastic): proportional relationship — common for multiplicative formulas like `revenue = orders * aov`
- **ε < 1** (inelastic): the root is less sensitive to this node — changes here have muted impact
- **ε = n/a**: root value is zero, elasticity is undefined

Use elasticity to prioritize which sub-metrics to focus on. A node with high elasticity is a bigger lever for improving the root metric than one with low elasticity, regardless of their current absolute values.

Elasticity complements Shapley attribution: Shapley explains *what caused* a past change, elasticity indicates *what would matter most* for future changes.

When a structured `levers` block is available:
- `recommended_direction = increase` means raising that node improves the root KPI
- `recommended_direction = decrease` means reducing that node improves the root KPI
- `scenario_impacts[].estimated_root_delta_ratio` is the implied root percent change
- `scenario_impacts[].estimated_root_delta_value` is the implied absolute root change using the current-period root value
- These are local linear estimates from the current operating point, not forecasts or causal guarantees

## Synthesis pattern

Combine evidence across steps: trend observation (direction + anomaly) + Shapley attribution (which sub-metric drove it) + mechanism validation (volume vs mix shift via `/qluent:compare`) + elasticity (which levers matter most going forward) = conclusion with actionable takeaway.
