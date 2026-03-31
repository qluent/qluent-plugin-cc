---
description: Run multi-period trend analysis for a metric tree
argument-hint: "[tree-name] [--periods 4] [--grain week|month] [--as-of YYYY-MM-DD]"
allowed-tools: Bash(qluent *)
disable-model-invocation: true
---

# Trend analysis

Use this as a follow-up after `/qluent:investigate`, not as a starting point.

Parse the arguments from `$ARGUMENTS` and run:

```bash
qluent trees trend <tree_id> --periods <N> --grain <grain> --json-output
```

Defaults if not provided: periods=4, grain=week. Use grain=month for longer-range analysis.

To pin the reference date, add `--as-of YYYY-MM-DD`.

## Interpret the results

For each period, report: value, absolute change, percentage change, and trend label.

Trend labels:
- **accelerating**: positive and growing faster
- **decelerating**: positive but slowing down
- **recovering**: was negative, now positive
- **declining**: was positive, now negative
- **volatile**: direction changes frequently
- **stable**: changes within +/-2%

Highlight the anomalous period and suggest drilling into it with `/qluent:investigate` or `/qluent:rca`.
