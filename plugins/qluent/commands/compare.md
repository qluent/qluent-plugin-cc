---
description: Compare two metric trees side-by-side to validate the mechanism behind a change
argument-hint: "[tree1] [tree2] [--period 'last week' | --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD]"
allowed-tools: Bash(qluent *)
disable-model-invocation: true
---

# Compare metric trees

Use as a follow-up after `/qluent:investigate`, not as a starting point.
Resolve tree ids per the `qluent-interpretation` skill if `$ARGUMENTS` looks
like a question rather than two tree ids.

Natural-language periods:

```bash
qluent trees compare <tree1> <tree2> --period "$ARGUMENTS_PERIOD" --json-output
```

Explicit windows:

```bash
qluent trees compare <tree1> <tree2> --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD --json-output
```

## Interpret

The response includes pre-computed mechanism interpretations. Present them
and suggest further drill-down if the mechanism is unclear.
