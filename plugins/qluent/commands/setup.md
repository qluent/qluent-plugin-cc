---
description: Check whether the qluent CLI is installed, configured, and ready to use
argument-hint: ''
allowed-tools: Bash(qluent *), Bash(which *), Bash(npx *), Bash(npm *), AskUserQuestion
---

# Qluent setup check

Verify that qluent is installed and configured.

## Step 1: Check installation

```bash
which qluent || npx @qluent/cli --version
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
qluent --version
```

## Step 2: Check configuration

List available trees as a proxy for working configuration:

```bash
qluent trees list
```

If the command fails with an auth or config error:
- Tell the user to run `!qluent setup` to configure their API key and endpoint.

If trees are returned, qluent is ready. Report the number of available metric trees.

If no trees are found, tell the user their workspace may not have any metric trees configured yet.

## Output

Present a summary:
- Installation status
- Configuration status (based on whether tree listing succeeded)
- Number of available metric trees
- Ready to use: yes/no
