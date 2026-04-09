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

The response includes pre-computed trend labels and anomaly flags for each period. Present these to the user and suggest drilling into anomalous periods with `/qluent:investigate` or `/qluent:rca`.
