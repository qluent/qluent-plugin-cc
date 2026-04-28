---
description: Run standalone deterministic root cause analysis on a metric tree
argument-hint: "[tree-name] [--period 'last week' | --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD]"
allowed-tools: Bash(qluent *), Read
disable-model-invocation: true
---

# Root cause analysis

Use as a follow-up after `/qluent:investigate`, not as a starting point.
Follow the `qluent-interpretation` skill for tree resolution, window reuse,
provenance, and Shapley/confidence interpretation.

Before running RCA, `Read` the canonical interpretation Module:

```
${CLAUDE_PLUGIN_ROOT}/skills/qluent-interpretation/SKILL.md
```

## Step 1: Resolve tree and window

Use the tree id and exact current/comparison windows from the prior
`/qluent:investigate` result when available. If the user supplied a new
period or explicit windows, use those verbatim. Quantitative RCA claims
require returned `qluent rca analyze` JSON for the selected tree/window.

## Step 2: Run RCA

Natural-language periods:

```bash
qluent rca analyze <tree_id> --period "$ARGUMENTS_PERIOD" --json-output
```

Explicit windows:

```bash
qluent rca analyze <tree_id> --current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD --json-output
```

## Step 3: Rank material drivers

Use only returned RCA fields. Prefer branches that are both material and
supported by confidence/evidence. Do not exhaustively drill low-contribution
branches unless the response flags them as anomalous or strategically
important. For each top driver, capture: contribution share / attribution,
absolute delta when returned, confidence/evidence coverage, warnings or gaps,
and child nodes/dimensions available for follow-up.

## Step 4: Choose next-best drills

Turn the ranked drivers into 2-3 concrete next drills. Prefer:

- segmenting the most material supported driver by an available dimension
- checking mix vs behavior when the movement could be composition-driven
- running `/qluent:compare` for cross-tree mechanism validation
- extending or splitting the time window when confidence is low

Weak / low-confidence / immaterial results produce drill suggestions, not
action recommendations.

## Step 5: Report

- Lead with the root cause and supporting evidence.
- List top contributing nodes with attribution shares.
- Note gaps or warnings from the response.
- State the exact current and comparison windows.
- Cite provenance per the skill.
- End with ranked next-best drills and one-sentence rationale for each.
