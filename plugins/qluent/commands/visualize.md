---
description: Visualize the latest qluent analysis output as interactive HTML charts in the browser
argument-hint: "[--file /path/to/json] [--simple]"
allowed-tools: Bash(*), Read, Write, Glob
---

# Visualize qluent output

Generates an insight-driven HTML dashboard from the most recent qluent analysis. The dashboard
is tailored to the specific findings — the analysis determines which charts appear, not a
fixed template.

## Step 1: Locate and validate the data

By default, read from `/tmp/qluent-viz-data.json`. If the user provides `--file <path>`, use
that path instead. If the file doesn't exist or is empty, tell the user to run
`/qluent:investigate` first.

**Freshness check:** Read the file and verify `current_window.date_from` is recent. If the
data looks stale (wrong tree, old dates), warn the user and suggest re-running investigate.

## Step 2: Choose rendering mode

**Simple mode** (`--simple` flag or no investigation context): Use the generic render script
for a quick chart. This is the fallback for basic data or when the user just wants something fast.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/render-charts.sh" /tmp/qluent-viz-data.json /tmp/qluent-viz.html
```

**Insight mode** (default when investigation data is rich): Generate a custom HTML dashboard
driven by the analysis findings. Use this when the JSON contains `agent.top_findings`,
`root_cause.conclusion.takeaways`, `mix_shift`, segment data, or cross-tree comparisons.

## Step 3: Generate insight-driven dashboard

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

## Step 4: Open in browser

```bash
# macOS
open /tmp/qluent-viz.html

# Linux
xdg-open /tmp/qluent-viz.html
```

## Rules

- Always read the data file first to verify freshness before rendering
- Use the `dashboard-design` skill for all design decisions — do not invent new styles
- Section titles must be insight statements, not generic labels
- Only include sections backed by actual data — never generate placeholder charts
- If the conversation includes cross-tree comparison or follow-up RCA data beyond what's
  in the JSON file, incorporate that data into the dashboard by hardcoding the values
- Prefer fewer, well-designed sections over many sparse ones
