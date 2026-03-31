---
description: Check whether the qluent CLI is installed, configured, and ready to use
argument-hint: ''
allowed-tools: Bash(qluent *), Bash(which *), Bash(npx *), Bash(npm *), AskUserQuestion
---

# Qluent setup check

Verify that qluent is installed and configured.

## Step 1: Check installation

```bash
which qluent || npx @qluent/cli --help
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
- If browser login is not possible (e.g. remote/headless), they can run `!qluent setup` instead for interactive terminal prompts.
- Do not attempt to run `qluent login` or `qluent setup` via Bash — these are interactive commands that require the `!` prefix.

## Step 3: Verify access

```bash
qluent trees list
```

If trees are returned, qluent is fully ready. Report the number of available metric trees.

If the command fails with an auth error, the credentials may be invalid or expired. Tell the user to re-authenticate with `!qluent login`.

If no trees are found, tell the user their workspace may not have any metric trees configured yet.

## Output

Present a summary:
- Installation: installed / not installed
- Authentication: configured / not configured
- Metric trees: N available (list names)
- Ready to use: yes / no
