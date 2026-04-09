---
description: Run standalone deterministic root cause analysis on a metric tree
argument-hint: "[tree-name] [--period 'last week' | --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD]"
allowed-tools: Bash(qluent *)
disable-model-invocation: true
---

# Root cause analysis

Use this as a follow-up after `/qluent:investigate`, not as a starting point.

## Step 1: Validate the tree

```bash
qluent trees validate <tree_id> --json-output
```

Check that leaf nodes project all declared dimensions. If dimensions are missing, note this as a gap — segment-level RCA will be limited.

## Step 2: Run deterministic RCA

For natural-language periods:

```bash
qluent rca analyze <tree_id> --period "$ARGUMENTS_PERIOD" --json-output
```

For explicit date windows:

```bash
qluent rca analyze <tree_id> --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD --json-output
```

## Step 3: Report the results

Focus on `conclusion.takeaways` and the top driver nodes.

- Lead with the root cause and supporting evidence
- List the top contributing nodes with their Shapley attribution shares
- If nodes include `elasticity` values, highlight high-elasticity nodes as key levers for future improvement
- Note any gaps (missing dimensions, unresolved branches)
- Suggest `/qluent:compare` if mechanism validation would help

### Shapley attribution

Each child's contribution to the parent's delta is computed using Shapley values from cooperative game theory.

- **Contributions sum to the parent delta** — they fully explain the change
- **A share > 100%** means this child drove MORE change than the total, offset by others
- **A negative share** means this child moved against the overall trend

### RCA confidence

`conclusion.confidence_score` is an evidence-coverage heuristic, NOT a probability. Never describe `80%` as "80% likely to be true." Describe it as an evidence coverage score.
