---
description: Check whether the qluent CLI is installed, configured, and ready to use
argument-hint: ''
allowed-tools: Bash(qluent *), Bash(which *), Bash(npx *), Bash(npm *), AskUserQuestion
---

# Qluent setup check

Verify that qluent is installed and configured.

## Step 1: Check installation

Check if the CLI is globally installed (do NOT use npx — it runs temporarily without installing):

```bash
which qluent
```

If qluent is not found:
- Use `AskUserQuestion` exactly once with two options:
  - `Install qluent via npm (Recommended)`
  - `Skip for now`
- If the user chooses install, run:

```bash
npm install -g @qluent/cli
```

- Then verify:

```bash
which qluent
```

If installation fails or the user skips, stop here and report that qluent is not installed.

## Step 1b: Check the CLI version

Composed plans (`qluent plan` / `qluent catalog`) first shipped in CLI
**0.1.18**. On anything older the whole compose path silently does not exist
and every question falls through to the slower natural-language workflow —
which is exactly what "it doesn't work and it's very slow" looks like from the
outside. Report it rather than letting it go unnoticed:

```bash
qluent --version
```

Compare against the minimum declared in
`${CLAUDE_PLUGIN_ROOT}/scripts/cli-requirements.sh`
(`QLUENT_MIN_CLI_VERSION`, currently `0.1.18`).

- **At or above the minimum** — note the version and continue.
- **Below the minimum** — tell the user plainly, and continue with the rest of
  the check (the NL workflow still works):

  ```text
  qluent CLI <found> detected; composed plans need 0.1.18+.
  Run `npm install -g @qluent/cli` to upgrade.
  ```

- **`--version` fails or prints nothing recognizable** — the CLI is older than
  the flag. Recommend the same upgrade and say the version could not be read.

If the user upgrades and the version does not change, an older `qluent` is
probably shadowing the new one on `PATH`: have them check `which -a qluent`
(see qluent/qluent-cli#103).

## Step 2: Check the effective connection and capabilities

```bash
qluent status --json-output
```

Use this result rather than `qluent config`: status reflects environment
overrides as well as the saved config and verifies API access.

If `connected` is false or the command reports missing credentials:
- Tell the user to log in by running `!qluent login` in this session. This opens a browser for SSO authentication and automatically configures the API key, project, and email.
- **Always recommend `qluent login` first** — it is the preferred auth method. Only mention `qluent setup` as a fallback for headless environments without a browser.
- Do not attempt to run `qluent login` or `qluent setup` via Bash — these are interactive commands that require the `!` prefix.

## Step 3: Start with query discovery

```bash
qluent suggestions --json-output
```

Querying is the default Qluent workflow. Present the first 2–3
catalog-derived query suggestions and explain that `/qluent:query` will use
a deterministic composed plan when the catalog fully covers the question,
then fall back to the NL-to-SQL workflow when needed.

Metric trees are an advanced, optional capability. Read their availability
from the top-level `trees` array in the Step 2 status response:

- If `trees` is empty, say metric-tree
  investigation is not configured for this project. This is informational,
  not a setup warning or failure.
- If `trees` contains entries, briefly mention that
  `/qluent:investigate` is available for deterministic KPI decomposition,
  RCA, trends, and levers.

If suggestions fail with an auth error, tell the user to re-authenticate with
`!qluent login`. If the project has no loadable query catalog, explain that
questions can still fall back to `qluent query`.

## Step 4: Inject project context

For every connected project, run the session-start hook. Catalog-only
projects need its query context just as much as tree-enabled projects:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-start.sh"
```

Then offer one concrete `/qluent:query` question from the suggestions. Do not
make users configure a metric tree before they can start querying.

## Output

Present a summary:
- Installation: installed / not installed
- CLI version: <found> (minimum for composed plans: 0.1.18) — flag an upgrade
  when below it
- Connection: ready / login required
- Querying: ready (default), including catalog coverage when available
- Metric trees: N available, or "not configured (advanced, optional)"
- Suggested first query based on the project catalog
