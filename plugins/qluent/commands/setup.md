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

## Step 2: Check configuration

```bash
qluent config
```

If the output shows an API key and project UUID, configuration is present.

If no config file is found or credentials are missing:
- Tell the user to log in by running `!qluent login` in this session. This opens a browser for SSO authentication and automatically configures the API key, project, and email.
- **Always recommend `qluent login` first** — it is the preferred auth method. Only mention `qluent setup` as a fallback for headless environments without a browser.
- Do not attempt to run `qluent login` or `qluent setup` via Bash — these are interactive commands that require the `!` prefix.

## Step 3: Verify access

```bash
qluent trees list
```

If trees are returned, qluent is fully ready. Report the number of available metric trees.

If the command fails with an auth error, the credentials may be invalid or expired. Tell the user to re-authenticate with `!qluent login`.

If no trees are found, tell the user their workspace may not have any metric trees configured yet.

## Step 4: Kick off exploration

If Step 3 succeeded and trees are available, run the session-start hook to inject rich tree context:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-start.sh"
```

Then proactively suggest an initial investigation based on the available trees. For example:
- If there's a revenue tree, offer to investigate recent revenue performance
- If there are multiple trees, highlight what each one can answer
- Tailor suggestions to the tree structure (dimensions → segment drill-down, children → root cause)

The goal is to get the user into analysis immediately after setup, not leave them staring at a status summary.

## Output

Present a summary:
- Installation: installed / not installed
- Authentication: configured / not configured
- Metric trees: N available (with descriptions and what each can answer)
- Suggested first question based on available trees
