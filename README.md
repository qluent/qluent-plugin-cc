# Qluent plugin for Claude Code

Business querying and deterministic KPI analysis inside Claude Code. Start
with the connected catalog; add metric trees when you need governed RCA.

## Getting Started

Install the CLI and log in:

```bash
npm install -g @qluent/cli
qluent login
```

Requires **qluent CLI 0.1.18 or newer** — that release added `qluent plan`
and `qluent catalog`, which the plugin's deterministic composed-plan path is
built on. On an older CLI every question falls back to the slower
natural-language workflow; `/qluent:setup` reports the installed version and
says so.

The plugin also registers qluent's MCP server (`qluent mcp serve`), so
deterministic composed queries run as typed tools rather than shell commands
— no permission prompt per step, and no temp files. It needs the same CLI
version as above; when the server is unavailable the plugin falls back to
driving the CLI.

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
| `/qluent:query` | Default workflow for business and data questions; deterministic composed plan when catalog-covered, NL-to-SQL fallback otherwise |
| `/qluent:deep-dive` | Cross-tree executive narrative across all configured metric trees |
| `/qluent:investigate` | Advanced deterministic analysis: validation, trend, evaluation, and RCA |
| `/qluent:visualize` | Shape the latest analysis into an `RcaReportSpec` (or local HTML fallback) |
| `/qluent:setup` | Check installation and configuration |

Start with `/qluent:query` for general business and data questions. Use
`/qluent:investigate` when you explicitly need governed KPI decomposition,
attribution, trend, or lever evidence from a configured tree. Use
`/qluent:deep-dive` when you need one executive read across the whole business.
`/qluent:investigate` already bundles trend, RCA, and segment data; the qluent
agents run any deeper follow-ups directly against the qluent CLI when the
bundled response calls for them.

```bash
/qluent:deep-dive last week
/qluent:deep-dive --period "this month" --yes
/qluent:deep-dive 2026-04-01:2026-04-28
/qluent:investigate why did revenue drop last week?
```

## Cross-tree deep dives

`/qluent:deep-dive [period]` runs investigations across every configured tree
in parallel and returns one bundled narrative. It confirms cost before
running unless you pass `--yes`:

```bash
/qluent:deep-dive "last week" --yes
```

Requires a qluent CLI release that includes `qluent trees deep-dive` from
`qluent-cli#40`. See `/qluent:deep-dive` for the full workflow contract,
including the synthesis shape and per-tree caveat handling.

## Query-first workflow

`/qluent:query <question>` is the default entry point. It first uses the
project catalog to compose a deterministic QueryPlan when coverage is
complete, then falls back to the backend's natural-language-to-SQL workflow.
The fallback can take a few minutes and may ask a clarifying question.
Metric trees remain available as the advanced workflow for governed movement
analysis and RCA. Follow-ups on NL queries continue via the returned thread:

```bash
/qluent:query which restaurants had the most failed deliveries last week?
/qluent:query and how many of those were repeat customers? --thread <thread_id>
```

Requires a qluent CLI release that includes `qluent query` from
`qluent-cli#92`.

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
