#!/usr/bin/env bash
# Qluent session-start hook: injects available metric trees and proactive
# analysis suggestions into context.
# Fails silently if qluent is not installed or configured.

set -euo pipefail

# Check if qluent is available
if ! command -v qluent &>/dev/null; then
  cat <<'EOF'
[Qluent] CLI is not installed. Run /qluent:setup to install and configure it.
EOF
  exit 0
fi

# Try to list trees — reports setup needed on auth/config failure
output=$(qluent trees list --json-output 2>/dev/null)
if [ $? -ne 0 ]; then
  cat <<'EOF'
[Qluent] CLI is installed but not configured. Run /qluent:setup to authenticate and connect to your project.
EOF
  exit 0
fi

# Extract tree details and generate proactive suggestions
context=$(echo "$output" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
    trees = data.get('trees', data) if isinstance(data, dict) else data
except Exception:
    sys.exit(0)

if not trees:
    sys.exit(0)

count = len(trees)

# --- Tree listing with metadata ---
tree_lines = []
for t in trees:
    tid = t.get('id', t.get('tree_id', 'unknown'))
    desc = t.get('description', t.get('label', ''))
    root = t.get('root_metric', t.get('root', ''))
    dims = t.get('dimensions', [])
    children = t.get('children', t.get('child_metrics', []))

    parts = [f'- **{tid}**']
    if desc:
        parts[0] += f': {desc}'
    meta = []
    if root:
        meta.append(f'root metric: {root}')
    if children:
        child_names = [c.get('id', c.get('name', str(c))) if isinstance(c, dict) else str(c) for c in children[:5]]
        meta.append('breaks into: ' + ', '.join(child_names))
    if dims:
        dim_names = [d.get('name', str(d)) if isinstance(d, dict) else str(d) for d in dims[:4]]
        meta.append('segments: ' + ', '.join(dim_names))
    if meta:
        parts.append('  (' + ' | '.join(meta) + ')')
    tree_lines.append(''.join(parts))

# --- Generate suggested analyses based on tree structure ---
suggestions = []

# Suggest weekly health check for any tree
first_tree = trees[0]
first_id = first_tree.get('id', first_tree.get('tree_id', 'unknown'))
first_root = first_tree.get('root_metric', first_tree.get('root', first_id))
suggestions.append(f'\"How did {first_root} perform last week?\" — weekly health check on **{first_id}**')

# If multiple trees exist, suggest comparison
if count >= 2:
    t1 = trees[0].get('id', trees[0].get('tree_id', 'unknown'))
    t2 = trees[1].get('id', trees[1].get('tree_id', 'unknown'))
    suggestions.append(f'\"Compare {t1} vs {t2} last month\" — validate whether a volume or mix shift is driving changes')

# Suggest trend analysis for a tree with a recognizable root
for t in trees:
    root = t.get('root_metric', t.get('root', '')).lower()
    tid = t.get('id', t.get('tree_id', 'unknown'))
    if any(kw in root for kw in ['roas', 'efficiency', 'conversion', 'margin', 'ratio']):
        suggestions.append(f'\"Is {root} trending up or down?\" — multi-period trend on **{tid}** to spot patterns')
        break

# Suggest root cause analysis for a tree with children
for t in trees:
    children = t.get('children', t.get('child_metrics', []))
    tid = t.get('id', t.get('tree_id', 'unknown'))
    root = t.get('root_metric', t.get('root', tid))
    if children and tid != first_id:
        suggestions.append(f'\"Why did {root} change this month?\" — deterministic root cause analysis on **{tid}**')
        break

# Segment drill-down if any tree has dimensions
for t in trees:
    dims = t.get('dimensions', [])
    tid = t.get('id', t.get('tree_id', 'unknown'))
    if dims:
        dim_name = dims[0].get('name', str(dims[0])) if isinstance(dims[0], dict) else str(dims[0])
        suggestions.append(f'\"Which {dim_name} segments drove the biggest changes?\" — segment-level Shapley attribution on **{tid}**')
        break

# Cap suggestions
suggestions = suggestions[:4]

# --- Output ---
print(f'[Qluent] {count} metric tree{\"s\" if count != 1 else \"\"} available for analysis:')
print()
for line in tree_lines:
    print(line)
print()
print('### What I can help with')
print()
print('This plugin runs **deterministic KPI analysis** — no guessing, no statistical models.')
print('Every number comes from Shapley-value decomposition of your metric trees.')
print()
print('**Capabilities:**')
print('- **Investigate** any metric movement (bundles validation, trend, evaluation, and root cause in one call)')
print('- **Root cause analysis** with Shapley attribution — mathematically exact driver decomposition')
print('- **Trend analysis** — multi-period tracking with anomaly detection')
print('- **Tree comparison** — side-by-side mechanism validation (volume vs mix vs rate shifts)')
print('- **Segment drill-down** — find which segments concentrate a movement')
print()
print('### Suggested analyses based on your trees')
print()
for s in suggestions:
    print(f'- {s}')
print()
print('Ask any business performance question, or use /qluent:investigate to start.')
" 2>/dev/null) || context=""

if [ -n "$context" ]; then
  echo "$context"
fi
