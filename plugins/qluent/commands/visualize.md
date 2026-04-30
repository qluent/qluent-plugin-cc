---
description: Shape the latest qluent analysis output into a UI RcaReportSpec, with insight-driven HTML on request
argument-hint: "[--file /path/to/json] [--simple] [--html]"
allowed-tools: Bash(*), Read, Write, Glob
---

# Visualize qluent output

Shapes the most recent qluent analysis into an outcome-shaped `RcaReportSpec`
for the Qluent UI. When deterministic RCA or elasticity output is available
the report spec is the required primary artifact. Explicit local HTML/dashboard
requests should produce an insight-driven dashboard from the analysis data.
`--simple` remains the generic renderer fallback. Follow the
`qluent-interpretation` skill for provenance and evidence labels.

## Step 0: Load the canonical interpretation protocol

Before shaping a report, `Read` the canonical interpretation Module:

```
${CLAUDE_PLUGIN_ROOT}/skills/qluent-interpretation/SKILL.md
```

## Step 1: Locate and validate the data

By default, read from `/tmp/qluent-viz-data.json`. If the user provides `--file <path>`, use
that path instead. If the file doesn't exist or is empty, tell the user to run
`/qluent:investigate` first.

If `/tmp/qluent-deep-dive-bundle.json` exists and the user asks to visualize a
deep-dive or cross-tree result, use that file instead. Deep-dive bundles must be clean
JSON with a bundle-level `trees[]` array; if validation fails, report the failing path
and re-run command instead of hand-writing replacement HTML.

**Freshness check:** Read the file and verify `current_window.date_from` is recent. If the
data looks stale (wrong tree, old dates), warn the user and suggest re-running investigate.

## Step 2: Choose report mode

**Report spec mode** (strict default for deterministic RCA/elasticity output): Produce or
request an outcome-shaped `RcaReportSpec` with `outcomeShape`, ordered `sections[]`,
`caveats[]`, and `sources[]`. Use this when the JSON contains `root_cause`, `evaluation`,
`levers`, `agent.recommended_next_steps`, `mix_shift`, segment findings, or a deep-dive
bundle with `trees[]`.

Do not hand-roll report HTML when the UI report contract can be used. Preserve the
deterministic qluent values and provenance in the spec instead of translating findings
into one-off dashboard markup.

The preferred output is a JSON-like report artifact that the UI can consume directly.
Include raw qluent values, stable section `type` values, caveats, and sources; do not
replace them with prose-only summaries or Chart.js configuration.

When a user asks for a visualization, chart, dashboard, or report after
`/qluent:investigate`, emit or request this `RcaReportSpec` first. Only switch to local
HTML after the user explicitly asks for a local HTML dashboard, browser-only demo,
`--simple`, `--html`, or the UI contract is unavailable.

**Simple mode** (`--simple` flag or no investigation context): Use the generic render
script for a quick local chart. This is a fallback for basic data or deliberate simple
mode, not the synchronized RCA report artifact.
Use a unique output path so stale `/tmp/qluent-viz.html` files do not collide with new runs:

```bash
out="/tmp/qluent-viz-$(date +%Y%m%d-%H%M%S).html"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/render-charts.sh" /tmp/qluent-viz-data.json "$out"
echo "Rendered Qluent report fallback: $out"
```

**Insight-driven HTML mode** (`--html`, explicit dashboard/local/browser request, or
unavailable UI contract): Compose custom HTML from the investigation data via the
`dashboard-design` skill and write it to a unique `/tmp/qluent-viz-<timestamp>.html`
path. This mode should be specific to the produced analysis, not the generic renderer
template. Drive every value, label, chart series, caveat, and recommendation from the
qluent JSON; do not invent, infer, or hardcode chart values from conversation context.

## Step 3: Build an outcome-shaped RcaReportSpec

Read the JSON data and map the deterministic qluent fields into an ordered report spec:

```ts
{
  outcomeShape: 'driver_concentration' | 'mix_shift' | 'elasticity_tradeoff' | 'data_quality_blocker' | 'cross_tree_bundle' | string,
  sections: [
    { type: 'root_movement', data: ... },
    { type: 'driver_decomposition', data: ... },
    { type: 'material_segment_scan', data: ... },
    { type: 'mix_shift', data: ... },
    { type: 'cross_tree_root_movement', data: ... },
    { type: 'cross_tree_hotspot_grid', data: ... },
    { type: 'cross_tree_overlap', data: ... },
    { type: 'elasticity_summary', data: ... },
    { type: 'next_drills', data: ... }
  ],
  caveats: [],
  sources: []
}
```

### Outcome shape guidance

Choose `outcomeShape` from the strongest returned evidence:

- `driver_concentration`: Shapley/RCA findings show one or a few direct contributors
  explain most of the root movement.
- `mix_shift`: `root_cause.mix_shift` or returned mix effects explain a material part
  of the movement.
- `elasticity_tradeoff`: `levers` or elasticity output shows a material sensitivity,
  tradeoff, guardrail, or scenario estimate.
- `data_quality_blocker`: qluent returns missing, stale, sparse, or low-confidence
  evidence that blocks a reliable interpretation.
- `cross_tree_bundle`: a deep-dive bundle compares multiple trees in one result and
  needs a cross-tree summary before any per-tree drill-down sections.
- Use a specific string only when the UI contract supports it or the returned qluent
  payload names an outcome shape.

### Section mapping

Build `sections[]` in the order that best tells the returned story, using only sections
backed by actual qluent fields:

1. `root_movement`: root metric, current/comparison windows, absolute and percentage
   movement, per-day normalized movement when available, tree id/label, and any
   server-provided period labels. If current and comparison windows have different day
   counts, add a caveat near the headline/root movement. Use deterministic normalized
   delta fields if returned; otherwise state that the normalized field/query is missing.
2. `driver_decomposition`: RCA driver findings, direct contributors, Shapley effects,
   materiality, confidence/evidence coverage, and supporting takeaways.
3. `material_segment_scan`: `root_cause.findings[].segment_findings` and material
   segment scans by node, dimension, segment value, contribution, and window.
4. `mix_shift`: `root_cause.mix_shift`, mix/baseline effects, segment mix changes,
   and returned interpretation.
5. `elasticity_summary`: `levers`, elasticity coefficients, scenario impacts, guardrail
   warnings, and actionability limits. Treat elasticity as directional sensitivity unless
   the returned response explicitly supports stronger causal language.
6. `next_drills`: `agent.recommended_next_steps`, unresolved gaps, validation drills,
   comparison suggestions, or tests needed before action.

For `cross_tree_bundle`, put the cross-tree sections first and reuse single-tree section
types only as subordinate drill-downs:

1. `cross_tree_root_movement`: one row per tree with root metric label, current value,
   comparison value, absolute movement, percentage movement, blocker/status, and tree id.
2. `cross_tree_hotspot_grid`: segment, dimension, tree, contribution/effect, materiality,
   and direction for returned concentrated segment or hotspot findings.
3. `cross_tree_overlap`: shared segments, repeated dimensions, correlated/tensioned tree
   movements, or an explicit "no overlap returned" state when the bundle lacks overlap.
4. `driver_decomposition`: per-tree driver details below the cross-tree summary.
5. `mix_shift`: per-tree or cross-tree mix-shift findings from returned bundle fields.
6. `next_drills`: copy-pasteable returned or derived follow-up commands, preserving tree
   ids, period, and dimensions.

### Provenance and evidence labels

Every material section preserves provenance per the `qluent-interpretation`
skill, mapped into the spec: per-section `data` carries command/result type,
tree id/label, node/segment, exact windows, materiality, and
confidence/evidence coverage. Returned caveats (gaps, low confidence, sparse
samples, missing dimensions, unsupported cuts, guardrail warnings, stale or
unequal-length windows) flow into top-level `caveats[]`. Result references
and data lineage flow into `sources[]`. Use the returned evidence labels
named in the skill exactly when present.

## Step 4: HTML fallback for local demos

Do not enter this step for normal deterministic RCA or elasticity visualization requests.
HTML is a local/dashboard artifact, not the synchronized report artifact.

For `--html` or explicit dashboard/local/browser requests, first read the dashboard
design system:

```
${CLAUDE_PLUGIN_ROOT}/skills/dashboard-design/SKILL.md
```

Then write a unique output path:

```bash
out="/tmp/qluent-viz-$(date +%Y%m%d-%H%M%S).html"
```

Compose sections using the skill's insight-to-section mapping and the chosen
`outcomeShape`. Include only sections whose values map directly from qluent JSON. If a
value needed for a chart cannot be mapped from the JSON, omit that section or state the
missing deterministic field/query instead of inventing a placeholder chart.

Suggested single-tree section order (include only those the investigation supports):

1. **Hero** — outcome-specific headline, exact current/comparison windows, root metric
   movement, and the strongest supported read.
2. **Root movement KPI strip** — current value, comparison value, absolute movement,
   percentage movement, confidence, and evidence coverage when returned.
3. **Driver decomposition** — Shapley/RCA contributors or returned takeaways, charted
   only from deterministic contribution fields.
4. **Material segment scan** — segment findings, mix shifts, or hotspot bars/tables
   when `root_cause.findings[].segment_findings` or `mix_shift` exists.
5. **Mechanism or elasticity** — mechanism takeaways, lever sensitivity, scenario
   impact, and guardrails when the bundle includes them.
6. **Insight callouts** — `.insight`, `.insight-warn`, or `.insight-bad` annotations
   next to the charts they explain.
7. **Caveats and next drills** — returned gaps, low-confidence notes, unsupported cuts,
   and copy-pasteable recommended commands.

For `--simple`, run `render-charts.sh`; this is the deliberately generic fallback:

```bash
out="/tmp/qluent-viz-$(date +%Y%m%d-%H%M%S).html"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/render-charts.sh" /tmp/qluent-viz-data.json "$out"
echo "Rendered Qluent report fallback: $out"
```

## Step 5: Open fallback HTML in browser

```bash
# macOS
open "$out"

# Linux
xdg-open "$out"
```

## Rules

- Read the data file first to verify freshness before rendering.
- Prefer an outcome-shaped `RcaReportSpec` whenever deterministic RCA or
  elasticity output is available.
- Do not hand-roll report HTML when the UI contract can be used.
- Use unique fallback HTML output paths; do not silently reuse stale dashboards.
- Use the `dashboard-design` skill for explicit HTML/dashboard output so the
  visualization follows the produced analysis, not a fixed template.
- Use `render-charts.sh` only for `--simple` generic fallback output.
- Section titles are insight statements, not generic labels.
- Only include sections backed by actual data; omit the section or state the
  missing deterministic field if values cannot be mapped from the JSON.
- Prefer fewer, well-designed sections over many sparse ones.
