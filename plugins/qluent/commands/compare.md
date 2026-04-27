---
description: Compare two metric trees side-by-side to validate the mechanism behind a change
argument-hint: "[tree1] [tree2] [--period 'last week' | --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD]"
allowed-tools: Bash(qluent *)
disable-model-invocation: true
---

# Compare metric trees

Use this as a follow-up after `/qluent:investigate`, not as a starting point.

If `$ARGUMENTS` looks like a question rather than two tree ids, run `qluent trees list --json-output`, pick the two most relevant trees from the list (match against tree label, child node labels, and declared dimensions), and re-run with those tree ids.

Run a side-by-side comparison of two trees for the same period.

For natural-language periods:

```bash
qluent trees compare <tree1> <tree2> --period "$ARGUMENTS_PERIOD" --json-output
```

For explicit date windows:

```bash
qluent trees compare <tree1> <tree2> --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD --json-output
```

## Interpret the results

The response includes pre-computed mechanism interpretations comparing the two trees. Present these to the user and suggest further drill-down if the mechanism is unclear.
