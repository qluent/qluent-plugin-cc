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

```bash
qluent config show
```

If not configured:
- Tell the user to run `!qluent setup` to configure their API key and endpoint.

## Step 3: List available trees

```bash
qluent trees list
```

If trees are returned, qluent is ready. Report the number of available metric trees.

If no trees are found, tell the user their workspace may not have any metric trees configured yet.

## Output

Present a summary:
- Installation status
- Configuration status
- Number of available metric trees
- Ready to use: yes/no
