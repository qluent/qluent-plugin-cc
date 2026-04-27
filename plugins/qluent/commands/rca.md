---
description: Run standalone deterministic root cause analysis on a metric tree
argument-hint: "[tree-name] [--period 'last week' | --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD]"
allowed-tools: Bash(qluent *)
disable-model-invocation: true
---

# Root cause analysis

Use this as a follow-up after `/qluent:investigate`, not as a starting point.

If `$ARGUMENTS` looks like a question rather than a tree id, run `qluent trees list --json-output`, pick the best-fitting tree from the list (match against tree label, child node labels, and declared dimensions), and re-run with that tree id. If no tree is a clear fit, ask the user to choose from the top candidates. Quantitative RCA claims require returned `qluent rca analyze` JSON for the selected tree/window.

## Step 1: Resolve tree and window deterministically

Use the tree id and exact current/comparison windows from the prior `/qluent:investigate` result when available. If the user supplied a new period or explicit windows, use those verbatim. Do not infer quantitative movement without fresh qluent JSON for the chosen tree/window.

## Step 2: Run deterministic RCA

For natural-language periods:

```bash
qluent rca analyze <tree_id> --period "$ARGUMENTS_PERIOD" --json-output
```

For explicit date windows:

```bash
qluent rca analyze <tree_id> --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD --json-output
```

## Step 3: Rank material drivers

Use only returned RCA fields to rank drivers. Prefer branches that are both material and supported by confidence/evidence fields. Do not exhaustively drill low-contribution branches unless the server response flags them as anomalous or strategically important.

For each top driver, capture:

- contribution share or attribution value
- absolute delta when returned
- confidence/evidence coverage
- warnings, gaps, or data-quality flags
- child nodes or dimensions available for a follow-up drill

## Step 4: Choose next-best drills

Turn the ranked drivers into 2-3 concrete next-best drills. Prefer:

- segmenting the most material supported driver by available dimensions
- checking mix vs behavior when the movement could be composition-driven
- running `/qluent:compare` when mechanism validation across trees would reduce uncertainty
- extending or splitting the time window when confidence is low or the movement is volatile

Weak, low-confidence, or immaterial results should produce validation/drill suggestions, not action recommendations.

## Step 5: Report the results

The response includes pre-computed conclusions, attribution shares, confidence scores, and interpretation labels. Present these to the user:

- Lead with the root cause and supporting evidence
- List the top contributing nodes with their attribution shares
- Note any gaps or warnings from the server response
- State the exact current and comparison windows
- Cite provenance for material findings: RCA result, tree id or label, node, and exact current/comparison windows
- Separate returned facts from interpretation, caveats, and recommendations
- Include caveats when materiality or confidence is insufficient
- End with ranked next-best drills and why each one is next
