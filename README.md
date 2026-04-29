# Qluent plugin for Claude Code

Deterministic KPI analysis inside Claude Code. Ask why a metric changed and get
an answer backed by Shapley attribution — not vibes.

## Getting Started

Install the CLI and log in:

```bash
npm install -g @qluent/cli
qluent login
```

Then add the plugin in Claude Code:

```
/plugin marketplace add qluent/qluent-plugin-cc
/reload-plugins
```

You're ready to ask questions.

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
| `/qluent:deep-dive` | Cross-tree executive narrative across all configured metric trees |
| `/qluent:investigate` | Full analysis: validation, trend, evaluation, and RCA |
| `/qluent:trend` | Multi-period trend analysis |
| `/qluent:rca` | Root cause analysis with Shapley attribution |
| `/qluent:compare` | Side-by-side metric tree comparison |
| `/qluent:setup` | Check installation and configuration |

Start with `/qluent:investigate` for a specific metric tree. Use
`/qluent:deep-dive` when you need one executive read across the whole business.
The other commands are for follow-up drill-downs.

```bash
/qluent:deep-dive last week
/qluent:deep-dive --period "this month" --yes
/qluent:deep-dive 2026-04-01:2026-04-28
/qluent:investigate why did revenue drop last week?
/qluent:trend revenue --periods 8 --grain week
/qluent:compare revenue orders --period "last month"
```

## Cross-tree deep dives

`/qluent:deep-dive [period]` calls:

```bash
qluent trees deep-dive --json-output --period "<period>"
```

The CLI runs investigations across all configured trees in parallel and returns one
bundled JSON payload. Claude then synthesizes the bundle into a single narrative with:

- **Headline** — which root metrics moved
- **Concentration** — segments that show up across trees
- **Mechanism** — whether the movement looks like volume, basket, conversion, mix,
  operational quality, cost, margin, or timing
- **Caveats** — errored trees, skipped cuts, low confidence, or sparse data
- **Next-best drills** — ranked, copy-pasteable `/qluent:*` follow-up commands

Because this can run several investigations at once, the command confirms before
execution. Use `--yes` for autonomous mode after you have decided the cost is acceptable:

```bash
/qluent:deep-dive "last week" --yes
```

Requires a qluent CLI release that includes `qluent trees deep-dive` from
`qluent-cli#40`. Older CLIs are detected and the command exits with an upgrade warning
instead of falling back to separate tree investigations.

## License

MIT

## Contributing

### Cutting a release

The plugin version is tracked in two manifest files:

- `.claude-plugin/marketplace.json` (both `metadata.version` and the
  `plugins[].version` for the `qluent` entry)
- `plugins/qluent/.claude-plugin/plugin.json`

The marketplace cache key includes the version string, so the version field
**must** be bumped for clients to pick up new commits — leaving it unchanged
makes `/plugin marketplace update` short-circuit with "already at latest".

To bump every manifest at once:

```bash
node scripts/bump-version.mjs 0.3.2
```

To verify all manifests share the same version (CI runs this on every PR):

```bash
node scripts/bump-version.mjs --check
# or pin an expected value:
node scripts/bump-version.mjs --check 0.3.2
```

Open a release PR with the bump commit, merge to `main`, and clients will pull
the new version on their next `/plugin marketplace update qluent-metric-trees`.
