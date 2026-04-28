---
description: Shape the latest qluent analysis output into a UI report spec, with HTML charts as a local fallback
argument-hint: "[--file /path/to/json] [--simple]"
allowed-tools: Bash(*), Read, Write, Glob
---

# Visualize qluent output

Shapes the most recent qluent analysis into an outcome-shaped `RcaReportSpec` for the
Qluent UI. When deterministic RCA or elasticity output is available, the report spec is
the primary artifact. Use the local HTML renderer only as a fallback for quick demos,
basic data, or when the UI report contract cannot be consumed.

## Step 1: Locate and validate the data

By default, read from `/tmp/qluent-viz-data.json`. If the user provides `--file <path>`, use
that path instead. If the file doesn't exist or is empty, tell the user to run
`/qluent:investigate` first.

**Freshness check:** Read the file and verify `current_window.date_from` is recent. If the
data looks stale (wrong tree, old dates), warn the user and suggest re-running investigate.

## Step 2: Choose report mode

**Report spec mode** (default for deterministic RCA/elasticity output): Produce or request
an outcome-shaped `RcaReportSpec` with `outcomeShape`, ordered `sections[]`, `caveats`,
and `sources`. Use this when the JSON contains `root_cause`, `evaluation`, `levers`,
`agent.recommended_next_steps`, `mix_shift`, or segment findings.

Do not hand-roll report HTML when the UI report contract can be used. Preserve the
deterministic qluent values and provenance in the spec instead of translating findings
into one-off dashboard markup.

The preferred output is a JSON-like report artifact that the UI can consume directly.
Include raw qluent values, stable section `type` values, caveats, and sources; do not
replace them with prose-only summaries or Chart.js configuration.

When a user asks for a report after `/qluent:investigate`, emit or request this
`RcaReportSpec` first. Only switch to local HTML after the user explicitly asks for a
browser-only fallback or the UI contract is unavailable.

**Simple mode** (`--simple` flag or no investigation context): Use the generic render script
for a quick chart. This is the fallback for basic data or when the user just wants something fast.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/render-charts.sh" /tmp/qluent-viz-data.json /tmp/qluent-viz.html
```

**HTML fallback mode** (local demo only): Generate a custom HTML dashboard driven by the
analysis findings when the user explicitly asks for browser-rendered charts or the UI
report contract is unavailable. Use this for `/tmp/qluent-viz.html`, not as the primary
synchronized report artifact.

## Step 3: Build an outcome-shaped RcaReportSpec

Read the JSON data and map the deterministic qluent fields into an ordered report spec:

```ts
{
  outcomeShape: 'driver_concentration' | 'mix_shift' | 'elasticity_tradeoff' | 'data_quality_blocker' | string,
  sections: [
    { type: 'root_movement', data: ... },
    { type: 'driver_decomposition', data: ... },
    { type: 'material_segment_scan', data: ... },
    { type: 'mix_shift', data: ... },
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

### Provenance and evidence labels

Every material section must preserve deterministic provenance:

- Include the qluent command/result type, tree id or label, node id/label, segment
  dimension/value when present, exact current/comparison windows, materiality, and
  confidence/evidence coverage.
- Carry caveats from returned `gaps`, low confidence, sparse samples, missing dimensions,
  unsupported cuts, guardrail warnings, stale windows, or unequal current/comparison
  period lengths into top-level `caveats[]`.
- Carry result references and data lineage into `sources[]`; do not cite unstated data.
- Use CLI/UI evidence labels exactly when present: `observed_correlation`,
  `historical_elasticity`, `model_estimate`, and `experiment_backed`.
- Separate returned facts from interpretation, caveats, and recommendations.

## Step 4: HTML fallback for local demos

Read the JSON data and determine which sections to include based on what evidence is present.
Reference the `dashboard-design` skill for the design system (tokens, components, Chart.js
config, section templates).

### Section selection logic

Scan the JSON and include sections based on available data:

1. **Hero** (always): Pull tree label, period, delta, and `agent.top_findings` into a
   narrative headline. Frame the headline as an insight ("Revenue +2.7% but the growth has
   cracks") not a label ("Revenue Analysis").

2. **KPI strip** (always): Root metric value + delta, plus top 3-4 child metrics from
   `evaluation.top_contributors` or key nodes.

3. **Trend** (if `trend.evaluations` has 3+ periods): Line chart of root value over time
   with WoW % change bars on secondary axis.

4. **Shapley attribution** (if `evaluation.nodes` has formula with contributions):
   Horizontal bar chart showing each child's effect on the parent. Focus on the most
   interesting decomposition (e.g., Orders vs AOV for a product formula, not just
   top-level gross vs incentive).

5. **Mix shift / segment breakdown** (if `root_cause.mix_shift` or `findings[].segment_findings`
   exist): Grouped bars showing current vs comparison by segment, plus a baseline vs mix
   effect decomposition chart if mix_shift data is available.

6. **Funnel steps** (if tree is a conversion funnel with step rates): Bar chart of rate
   changes per step. If segment findings show a vertical or platform concentration, add a
   horizontal bar breakdown of the worst-performing step by segment.

7. **Cross-tree comparison** (if comparison data from multiple trees is available in the
   conversation context): Side-by-side stat blocks or dual charts. Include this when the
   user ran `/qluent:compare` or the investigation recommended cross-tree validation.

8. **Operations / quality** (if operations metrics are present): Stat block trio for
   delivery quality, failure rates, or similar operational KPIs.

9. **Lever priorities** (if `levers.top_levers` exists): Priority table with columns for
   rank, lever name, elasticity, current trend, +5% scenario impact, and action type
   (FIX/GROW/INVEST tags based on whether the metric is declining, growing, or strategic).

10. **Insight callouts**: Add contextual annotations below relevant charts using the
    `.insight`, `.insight-warn`, or `.insight-bad` classes. Pull from
    `root_cause.conclusion.takeaways` and `agent.top_findings`.

### Building the HTML

Write the complete dashboard to `/tmp/qluent-viz.html`:

- Use the design tokens, fonts, and Chart.js defaults from the `dashboard-design` skill
- Include the Qluent logo SVG in the sticky topbar
- Number each section sequentially (01, 02, 03...)
- Use insight-driven section titles (statements, not labels)
- All data values should use `var(--font-mono)` font family
- Color positive deltas green, negative red
- Make it responsive with the 768px breakpoint
- Include a visible period-length caveat when current and comparison windows have
  different day counts. If normalized deltas are present in the JSON, show them; if not,
  state that normalized delta evidence was not returned.

### Data extraction patterns

```js
// Root metric
const root = data.evaluation.nodes.find(n => n.parent_id === null);

// Trend periods (from investigate bundle)
const periods = data.trend.evaluations; // array of period evaluations

// Shapley contributions for a node
const node = data.evaluation.nodes.find(n => n.id === 'product_gmv');
const effects = node.contributions; // or find in root_cause.findings[].formula_analysis.effects

// Mix shift
const mix = data.root_cause.mix_shift; // { dimension, segments[] }

// Segment findings for a node
const finding = data.root_cause.findings.find(f => f.node_id === 'net_revenue');
const segments = finding.segment_findings;

// Levers
const levers = data.levers.top_levers;
```

## Step 5: Open fallback HTML in browser

```bash
# macOS
open /tmp/qluent-viz.html

# Linux
xdg-open /tmp/qluent-viz.html
```

## Rules

- Always read the data file first to verify freshness before rendering
- Prefer an outcome-shaped `RcaReportSpec` with `outcomeShape` and ordered `sections[]`
  whenever deterministic RCA or elasticity output is available
- Do not hand-roll report HTML when the UI report contract can be used
- Preserve deterministic provenance, caveats, date windows, materiality, and evidence labels
- Preserve period comparability caveats in both `RcaReportSpec` output and HTML fallback
- Use the `dashboard-design` skill for all design decisions — do not invent new styles
- Section titles must be insight statements, not generic labels
- Only include sections backed by actual data — never generate placeholder charts
- If the conversation includes cross-tree comparison or follow-up RCA data beyond what's
  in the JSON file, incorporate that data into the dashboard by hardcoding the values
- Prefer fewer, well-designed sections over many sparse ones
