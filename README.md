# Qluent plugin for Claude Code

Deterministic KPI analysis inside Claude Code. Investigate metric movements, run trend
analysis, and find root causes — all through slash commands.

## What You Get

- `/qluent:investigate` — bundled validation, trend, evaluation, and root cause analysis
- `/qluent:trend` — multi-period trend analysis
- `/qluent:rca` — standalone root cause analysis with Shapley attribution
- `/qluent:compare` — side-by-side metric tree comparison
- `/qluent:setup` — check that qluent is installed and configured

## Requirements

- **Qluent account** with API access
- **Node.js 18+** (for npm installation of the CLI)

## Install

Add the marketplace in Claude Code:

```bash
/plugin marketplace add qluent/qluent-plugin-cc
```

Install the plugin:

```bash
/plugin install qluent@qluent-metric-trees
```

Reload plugins:

```bash
/reload-plugins
```

Then run:

```bash
/qluent:setup
```

`/qluent:setup` will check whether the qluent CLI is installed and configured. If it's
missing and npm is available, it can install it for you.

If you prefer to install qluent yourself:

```bash
npm install -g @qluent/cli
```

Then configure:

```bash
qluent setup
```

## Usage

### Investigate a KPI movement

```bash
/qluent:investigate why did revenue drop last week?
```

```bash
/qluent:investigate revenue --period "last month"
```

### Trend analysis

```bash
/qluent:trend revenue --periods 8 --grain week
```

### Root cause analysis

```bash
/qluent:rca revenue --period "last week"
```

### Compare trees

```bash
/qluent:compare revenue orders --period "last week"
```

## How it works

This plugin wraps the [qluent CLI](https://www.npmjs.com/package/@qluent/cli), which
provides deterministic metric tree analysis. Metric trees decompose high-level KPIs into
their mathematical components, enabling precise attribution of changes using Shapley values
from cooperative game theory.

The plugin uses your local `qluent` installation and configuration. Your API key and
endpoint settings are read from `~/.qluent/config.json`.

## Typical flows

### Quick investigation

```bash
/qluent:investigate why did ROAS drop this week?
```

### Deep dive after investigation

```bash
/qluent:investigate revenue --period "last month"
/qluent:trend revenue --periods 8 --grain week
/qluent:compare revenue orders --period "last month"
```

## License

MIT
