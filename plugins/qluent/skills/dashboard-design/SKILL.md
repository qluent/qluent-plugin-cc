---
name: dashboard-design
description: Internal design system reference for generating insight-driven HTML dashboards from qluent analysis data
user-invocable: false
---

# Qluent Dashboard Design System

Use this reference when generating custom HTML dashboards from qluent analysis output.
The goal is insight-driven visualization — the analysis findings determine which sections
appear, not a fixed template.

## Design Tokens

```css
:root {
  --bg: #0c0e13;
  --bg-card: #13151c;
  --bg-card-hover: #181b24;
  --border: #1e2130;
  --border-subtle: rgba(255,255,255,0.04);
  --text: #e8eaed;
  --text-secondary: #8b8fa3;
  --text-muted: #555872;
  --accent: #6c5ce7;
  --accent-glow: rgba(108,92,231,0.15);
  --green: #34d399;
  --green-dim: rgba(52,211,153,0.12);
  --red: #f87171;
  --red-dim: rgba(248,113,113,0.12);
  --amber: #fbbf24;
  --amber-dim: rgba(251,191,36,0.12);
  --blue: #60a5fa;
  --blue-dim: rgba(96,165,250,0.12);
  --cyan: #22d3ee;
  --font-display: 'Instrument Serif', Georgia, serif;
  --font-body: 'DM Sans', -apple-system, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;
}
```

### Google Fonts import

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=DM+Sans:ital,opsz,wght@0,9..40,300..700;1,9..40,300..700&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
```

### Chart.js CDN

```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
```

## Topbar

Always include the Qluent logo SVG topbar. Apply light-on-dark fills:

```css
.topbar svg path[fill="#222"] { fill: #e8eaed; }
.topbar svg path[fill="#6200ee"] { fill: #6c5ce7; }
```

Use sticky positioning with backdrop blur:

```css
.topbar {
  position: sticky; top: 0; z-index: 100;
  background: rgba(12,14,19,0.85);
  backdrop-filter: blur(20px);
  border-bottom: 1px solid var(--border);
  padding: 14px 32px;
}
```

## Chart.js Defaults

```js
Chart.defaults.font.family = "'DM Sans', sans-serif";
Chart.defaults.font.size = 11;
Chart.defaults.color = '#555872';

const gridOpts = { color: 'rgba(255,255,255,0.04)', drawBorder: false };
const noGrid = { display: false };
const tooltipStyle = {
  backgroundColor: '#1a1c25', titleColor: '#e8eaed', bodyColor: '#8b8fa3',
  borderColor: '#2a2d3e', borderWidth: 1, padding: 12, cornerRadius: 8,
  titleFont: { family: "'DM Sans'" },
  bodyFont: { family: "'JetBrains Mono'", size: 11 },
};
```

## Section Architecture

Each dashboard section follows a numbered pattern:

```html
<div class="section">
  <div class="section-header">
    <span class="section-num">01</span>
    <h2 class="section-title">Headline insight</h2>
  </div>
  <p class="section-subtitle">Supporting context</p>
  <!-- Cards with charts, stats, or tables -->
</div>
```

Section titles should be **insight-driven statements** ("Restaurants collapsed, express surged")
not generic labels ("Revenue by Business Type").

## Available Components

### Hero
Use for the opening narrative. Include: eyebrow label, headline with key metric highlighted
in `<em>` (colored green/red), period, and a narrative paragraph with left border accent.

### KPI Strip
Grid of 4-6 top-level metrics. Use `var(--font-mono)` for values. Color deltas with `.up`/`.down`.

### Card
Container for charts and stats. 12px border-radius, 24px padding, `var(--bg-card)` background.

### Insight Callout
Contextual annotations below charts. Three variants:
- Default (accent purple): general insight
- `.insight-warn` (amber): warning signal
- `.insight-bad` (red): critical finding

### Stat Block
Compact metric display with label, value, delta, and optional bar track.

### Priority Table
For action items. Columns: rank, lever name, elasticity, current trend, scenario impact, type tag.
Tags: `.tag-fix` (red), `.tag-grow` (green), `.tag-watch` (amber).

### Grid Layouts
- `.grid-2`: equal two-column
- `.grid-3`: equal three-column
- `.grid-2-1`: 2/3 + 1/3

## Insight-to-Section Mapping

Use the analysis findings to decide which sections to include:

| Finding type | Section to generate |
|---|---|
| `trend` data with 3+ periods | Trend line + WoW bar chart |
| `evaluation` with Shapley contributions | Horizontal bar attribution chart |
| `root_cause.conclusion.takeaways` with `kind=mechanism` | Mechanism decomposition (e.g., Orders vs AOV) |
| `root_cause.mix_shift` present | Business type / segment comparison + mix effect waterfall |
| `root_cause.findings[].segment_findings` | Segment breakdown bars or stat blocks |
| Cross-tree comparison data | Side-by-side metric cards or dual-axis chart |
| Funnel tree with step rates | Funnel step bar chart + vertical/platform breakdown |
| `levers.top_levers` present | Priority action table with elasticity and scenario data |
| Operations/quality data | Stat block trio (on-time, late, failures) |

**Only include sections that are supported by actual data.** Do not generate placeholder
or generic sections.

## Color Conventions

- Positive change / growth: `var(--green)` / `rgba(52,211,153,0.3)`
- Negative change / decline: `var(--red)` / `rgba(248,113,113,0.3)`
- Neutral / interaction: `var(--text-muted)` / `rgba(85,88,114,0.2)`
- Accent / highlight: `var(--accent)` / `rgba(108,92,231,0.3)`
- Comparison period: `rgba(255,255,255,0.06)` with `rgba(255,255,255,0.12)` border

## Responsive

Use `@media (max-width: 768px)` to collapse grids to single column and reduce hero font size.
