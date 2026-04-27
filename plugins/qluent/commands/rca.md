---
description: Run standalone deterministic root cause analysis on a metric tree
argument-hint: "[tree-name] [--period 'last week' | --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD]"
allowed-tools: Bash(qluent *)
disable-model-invocation: true
---

# Root cause analysis

Use this as a follow-up after `/qluent:investigate`, not as a starting point.

If `$ARGUMENTS` looks like a question rather than a tree id, run `qluent trees list --json-output`, pick the best-fitting tree from the list, and re-run with that tree id. Quantitative RCA claims require returned `qluent rca analyze` JSON for the selected tree/window.

## Step 1: Run deterministic RCA

For natural-language periods:

```bash
qluent rca analyze <tree_id> --period "$ARGUMENTS_PERIOD" --json-output
```

For explicit date windows:

```bash
qluent rca analyze <tree_id> --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD --json-output
```

## Step 2: Report the results

The response includes pre-computed conclusions, attribution shares, confidence scores, and interpretation labels. Present these to the user:

- Lead with the root cause and supporting evidence
- List the top contributing nodes with their attribution shares
- Note any gaps or warnings from the server response
- Cite provenance for material findings: RCA result, tree id or label, node, and exact current/comparison windows
- Separate returned facts from interpretation, caveats, and recommendations
- Suggest `/qluent:compare` if mechanism validation would help
