---
description: Visualize the latest qluent analysis output as interactive HTML charts in the browser
argument-hint: "[--file /path/to/json]"
allowed-tools: Bash(*)
---

# Visualize qluent output

Renders the most recent qluent analysis as an interactive HTML dashboard with Chart.js charts.

## Step 1: Locate the data

By default, read from `/tmp/qluent-viz-data.json` (saved automatically by investigate, trend, rca, and compare commands).

If the user provides `--file <path>`, use that path instead.

If the file doesn't exist, tell the user to run `/qluent:investigate` first.

## Step 2: Generate the dashboard

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/render-charts.sh" /tmp/qluent-viz-data.json /tmp/qluent-viz.html
```

## Step 3: Open in browser

Open the generated HTML file. Use the platform-appropriate command:

```bash
# macOS
open /tmp/qluent-viz.html

# Linux
xdg-open /tmp/qluent-viz.html
```

## What gets rendered

The dashboard automatically detects which data sections are present and renders the appropriate charts:

- **Trend line + bar chart** — metric value over time with % change bars (from `trend.periods`)
- **Shapley attribution bar chart** — horizontal bars showing each node's contribution to the change (from `root_cause.top_contributors`)
- **Evidence coverage display** — confidence score and present/missing evidence types (from `root_cause.conclusion`)
- **Tree comparison grouped bars** — side-by-side current vs compare values for two trees (from `tree1`/`tree2`)

Only sections with data are shown. If no visualizable data is found, a message is displayed.
