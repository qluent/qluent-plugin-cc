# Qluent plugin for Claude Code

Deterministic KPI analysis inside Claude Code. Ask why a metric changed and get
an answer backed by Shapley attribution — not vibes.

## Requirements

- **Qluent account** — [sign up at qluent.com](https://qluent.com)
- **Node.js 18+** (for CLI installation)

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

`/qluent:setup` will check whether the Qluent CLI is installed and ready. If
it's missing and npm is available, it can install it for you.

If the CLI is installed but you're not logged in yet, run:

```bash
!qluent login
```

This opens your browser for SSO login. No API key needed.

After install, you should see the slash commands listed below and the
`qluent:qluent-analyst` agent in `/agents`.

## Usage

Just ask a question — the built-in agent handles the rest:

```
Why did revenue drop last week?
What's driving the ROAS change this month?
How is conversion trending?
```

Or use slash commands directly:

| Command | What it does |
|---|---|
| `/qluent:investigate` | Full analysis: validation, trend, evaluation, and RCA |
| `/qluent:trend` | Multi-period trend analysis |
| `/qluent:rca` | Root cause analysis with Shapley attribution |
| `/qluent:compare` | Side-by-side metric tree comparison |
| `/qluent:setup` | Check installation and configuration |

Start with `/qluent:investigate`. The other commands are for follow-up drill-downs.

```bash
/qluent:investigate why did revenue drop last week?
/qluent:trend revenue --periods 8 --grain week
/qluent:compare revenue orders --period "last month"
```

## License

MIT
