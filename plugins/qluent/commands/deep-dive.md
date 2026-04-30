---
description: Run a consented cross-tree deep dive and synthesize one executive narrative across all metric trees
argument-hint: "[period | --period 'last week' | YYYY-MM-DD:YYYY-MM-DD] [--yes] [--brief]"
allowed-tools: Bash(which qluent), Bash(qluent *), Bash(date *), AskUserQuestion, Read, Write
---

# Deep dive across metric trees

Use when the user wants one unified answer to "what changed across the
business?" across revenue, growth, operations, conversion funnel, and any
other configured trees.

Opt-in and potentially expensive: runs investigations across all trees in
parallel through the deterministic qluent CLI. Do not run from SessionStart
or as an implicit first step. Follow the `qluent-interpretation` skill for
provenance, window handling, and quantitative-claim rules.

## Step 0: Load the canonical interpretation protocol

Before running the deep dive, `Read` the canonical interpretation Module:

```
${CLAUDE_PLUGIN_ROOT}/skills/qluent-interpretation/SKILL.md
```

It is the single source of truth for the deterministic-query protocol, evidence labels,
elasticity guardrails, and unsupported-cut fallback. The cross-tree synthesis steps below
sit on top of that contract.

## Step 1: Check CLI availability and capability

Verify qluent is installed:

```bash
which qluent
```

If qluent is missing, stop and tell the user:

```text
qluent is not installed. Run /qluent:setup first, then retry /qluent:deep-dive.
```

Then verify the installed CLI supports the deep-dive subcommand:

```bash
qluent trees deep-dive --help
```

If the command exits non-zero or says the subcommand is unknown, stop and tell the user:

```text
This qluent CLI does not support `qluent trees deep-dive` yet. Upgrade to the release
that includes qluent-cli#40, then retry `/qluent:deep-dive`.
```

Do not fall back to running four separate `qluent trees investigate` commands; that
would change the cost profile and lose the bundled cross-tree contract.

## Step 2: Resolve the requested period

Accept any of these forms:

- `/qluent:deep-dive last week`
- `/qluent:deep-dive --period "this month"`
- `/qluent:deep-dive 2026-04-01:2026-04-28`
- `/qluent:deep-dive last week --yes`

Remove control flags such as `--yes` and `--brief` before resolving the period.

If `$ARGUMENTS` includes `--period`, use that value verbatim.
If `$ARGUMENTS` has remaining non-flag text, use that text verbatim as the period.
If no period is provided, ask the user for one with `AskUserQuestion` before continuing.

Supported examples include "last week", "this month", "last 30 days", and explicit
ISO ranges such as `YYYY-MM-DD:YYYY-MM-DD` when supported by the CLI.

## Step 3: Confirm cost and scope

Unless `$ARGUMENTS` includes `--yes`, ask for confirmation with `AskUserQuestion`
before running the deep dive:

```text
Run a cross-tree deep dive for <period>? This runs investigations across all configured
trees in parallel and may be slower or more expensive than a single-tree investigation.
```

Offer exactly two choices:

- `Run deep dive`
- `Cancel`

If the user cancels, stop without running qluent.

If `$ARGUMENTS` includes `--yes`, skip this confirmation and run autonomously.

## Step 4: Run the bundled deep-dive command

Before running the command, give one concise progress note:

```text
Running qluent cross-tree deep dive for <period>; this may take a minute because it
investigates all configured trees in parallel.
```

Run the deterministic bundled command and save the JSON bundle for this session:

```bash
qluent trees deep-dive --json-output --period "<period>" | tee /tmp/qluent-deep-dive-bundle.json
```

Keep stderr out of the saved bundle. Progress, usage text, and CLI errors must remain
on stderr so `/tmp/qluent-deep-dive-bundle.json` round-trips through `jq .` and the
renderer can validate it as clean JSON.

If qluent exits non-zero:

- Surface the CLI error plainly.
- If the error indicates an unknown command, tell the user to upgrade to the release
  containing qluent-cli#40.
- If the error indicates auth/configuration, tell the user to run `/qluent:setup`.
- Do not synthesize a report from partial shell text.

## Step 5: Parse the bundled payload

Read the returned JSON from the tool result. Treat the bundle as the only source of
quantitative truth.

Expected payload shape may evolve, so inspect fields by meaning rather than hardcoding
one exact schema. Look for:

- bundle-level period/current/comparison windows
- per-tree result objects with tree id, label, status, root movement, evaluation,
  root cause, trend, segment findings, levers, agent findings, gaps, and errors
- cross-tree findings, concentrations, correlations, shared segments, recommended
  next steps, caveats, and confidence metadata

If a tree has `error`, `status: error`, missing required evidence, low confidence, sparse
data, or skipped analysis, carry that into Caveats. Do not hide failed trees.

## Step 6: Synthesize one cross-tree narrative

Return one markdown report. Do not concatenate four tree reports.

Use this structure:

```markdown
## Headline
One short executive summary of which root metrics moved and the net business read.

## Concentration
Cross-reference segments that appear across trees. Highlight repeated countries,
channels, cohorts, products, platforms, verticals, or customer segments. Distinguish
shared segment evidence from tree-specific evidence.

## Mechanism
Explain the strongest supported mechanism across trees: volume, basket/AOV, conversion,
mix, ops quality, supply, cost, margin, or timing. Use the returned decomposition,
segment, lever, and trend fields. Be explicit when the mechanism is not resolved.

## Caveats
List errored trees, skipped cuts, stale/missing data, low confidence, sparse samples,
or unsupported segment overlaps.

## Next-best drills
Rank concrete follow-up commands across trees, not just within one tree.
```

Rules for synthesis:

- Prefer cross-tree convergence over per-tree trivia.
- If revenue and conversion move in opposite directions, explain the tension.
- If operations and conversion share a segment, call it out as an observed
  relationship unless the data explicitly supports causal language.
- If a single tree dominates the story, say so and state whether other trees
  confirm, contradict, or are inconclusive.
- Keep concise. If `--brief` is present, use shorter bullets but still include
  all five headings.

## Step 7: Render the insight-driven HTML dashboard

After delivering the markdown narrative, produce a companion HTML dashboard from
the same bundle. This is the primary visual artifact for `/qluent:deep-dive`:
the layout reflects what the bundle says, not a fixed template.

Read the dashboard design system before composing the HTML:

```
${CLAUDE_PLUGIN_ROOT}/skills/dashboard-design/SKILL.md
```

Write the dashboard to a unique path so older runs do not collide:

```
/tmp/qluent-deep-dive-$(date +%Y%m%d-%H%M%S).html
```

Compose sections using the skill's insight-to-section mapping, biased toward the
cross-tree shape of a deep-dive bundle. Drive every value, label, and chart
series from the bundle JSON; do not invent figures or fill placeholders.

Suggested cross-tree section order (include only those the bundle supports):

1. **Hero** — insight-driven headline (e.g. "Restaurants collapsed, express
   surged"), period, executive read, decisive metric in `<em>` colored per the
   skill's color conventions.
2. **KPI strip** — one card per tree with root metric label, current value,
   comparison value, absolute and percentage movement. Color deltas with
   `.up`/`.down`.
3. **Cross-tree concentration** — hotspot grid for repeated segments across
   trees, using stat blocks or a priority table from the skill.
4. **Mechanism** — strongest supported mechanism (volume, AOV, mix, conversion,
   ops quality) using mechanism decomposition or mix-effect components when the
   bundle supports them.
5. **Per-tree drill-down cards** — short cards for trees that materially moved,
   each with its top driver and a Chart.js bar/line bound to bundle series.
   Omit trees that did not move materially.
6. **Insight callouts** — `.insight`, `.insight-warn`, or `.insight-bad`
   callouts under the most important charts. These surface the takeaways from
   the markdown Headline, Concentration, and Mechanism sections beside the data.
7. **Caveats** — stat block or list mirroring the markdown Caveats section
   (errored trees, low-confidence findings, sparse data, unsupported cuts).
8. **Next-best drills** — priority table or list of the same copy-pasteable
   commands as the markdown Next-best drills.

Section titles must be insight statements, not generic labels. Only include
sections backed by actual bundle data; omit a section rather than render an
empty placeholder.

After writing the file, surface the path so the user can open it locally:

```
Wrote insight-driven dashboard: /tmp/qluent-deep-dive-<timestamp>.html
Open with `open <path>` (macOS) or `xdg-open <path>` (Linux).
```

## Next-best drill command format

Recommended next drills must be copy-pasteable and valid for this plugin/project.

Use exact tree ids, periods, and dimensions from the bundle. Prefer qluent's returned
recommended next steps when they are concrete. Use the `/qluent:investigate` slash
command for follow-up tree investigations, and the underlying `qluent` CLI subcommands
for narrower drill-downs the agents and `qluent-analyst` orchestrator already invoke:

```bash
/qluent:investigate <tree_id> --period "<period>"
qluent rca analyze <tree_id> --period "<period>" --segment-by <dimension> --json-output
qluent trees trend <tree_id> --periods 8 --grain week --json-output
qluent trees compare <tree_id_1> <tree_id_2> --period "<period>" --json-output
```

Rank next drills by expected ability to resolve the biggest open question, not by tree
order. Include why each drill is recommended in one sentence.

## Rules

- Check for qluent and the `trees deep-dive` subcommand before running.
- Confirm before running unless `--yes` is present.
- Never auto-fire from SessionStart.
- Never manually fan out to individual `qluent trees investigate` calls as a
  fallback — that loses the bundled cross-tree contract.
- Per-tree errors and low-confidence findings must appear in Caveats.
- Recommendations must be concrete `/qluent:investigate` slash commands or
  underlying `qluent` CLI subcommands — never paraphrased actions.
- Always render an insight-driven HTML dashboard via the `dashboard-design`
  skill alongside the markdown narrative. Section composition is data-driven,
  not templated; only include sections the bundle supports.
