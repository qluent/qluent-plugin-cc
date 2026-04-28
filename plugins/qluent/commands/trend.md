---
description: Run multi-period trend analysis for a metric tree
argument-hint: "[tree-name] [--periods 4] [--grain week|month] [--as-of YYYY-MM-DD]"
allowed-tools: Bash(qluent *), Read
disable-model-invocation: true
---

# Trend analysis

Use as a follow-up after `/qluent:investigate`, not as a starting point.

Before running trend analysis, `Read` the canonical interpretation Module so
the deterministic-query protocol, trend label semantics, and anomaly-flag
handling are in context:

```
${CLAUDE_PLUGIN_ROOT}/skills/qluent-interpretation/SKILL.md
```

Resolve the tree id per the `qluent-interpretation` skill if `$ARGUMENTS`
looks like a question. Then run:

```bash
qluent trees trend <tree_id> --periods <N> --grain <grain> --json-output
```

Defaults: `periods=4`, `grain=week`. Use `grain=month` for longer ranges. Pin
the reference date with `--as-of YYYY-MM-DD`.

## Interpret

The response includes pre-computed trend labels and anomaly flags. Present
them and suggest drilling into anomalous periods with `/qluent:investigate`
or `/qluent:rca`.
