# Qluent plugin for Claude Code

Deterministic KPI analysis inside Claude Code. Ask why a metric changed and get
an answer backed by Shapley attribution — not vibes.

## Getting Started

Install the plugin in Claude Code:

```
/install qluent/qluent-plugin-cc
```

Then run setup — it installs the CLI, opens your browser to log in, and
shows your available metric trees:

```
/qluent:setup
```

That's it. You're ready to ask questions.

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
