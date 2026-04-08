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

context=$(echo "$output" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
    raw = data.get('trees', data) if isinstance(data, dict) else data
except Exception:
    sys.exit(0)

if not raw:
    sys.exit(0)

# Normalize tree dicts so field-name aliases are resolved once
EFFICIENCY_KEYWORDS = ('roas', 'efficiency', 'conversion', 'margin', 'ratio')

def norm(t):
    return {
        'id': t.get('id', t.get('tree_id', 'unknown')),
        'root': t.get('root_metric', t.get('root', '')),
        'desc': t.get('description', t.get('label', '')),
        'dims': t.get('dimensions', []),
        'children': t.get('children', t.get('child_metrics', [])),
    }

trees = [norm(t) for t in raw]
count = len(trees)

# Build tree listing with metadata
tree_lines = []
for t in trees:
    parts = [f'- **{t[\"id\"]}**']
    if t['desc']:
        parts[0] += f': {t[\"desc\"]}'
    meta = []
    if t['root']:
        meta.append(f'root metric: {t[\"root\"]}')
    if t['children']:
        child_names = [c.get('id', c.get('name', str(c))) if isinstance(c, dict) else str(c) for c in t['children'][:5]]
        meta.append('breaks into: ' + ', '.join(child_names))
    if t['dims']:
        dim_names = [d.get('name', str(d)) if isinstance(d, dict) else str(d) for d in t['dims'][:4]]
        meta.append('segments: ' + ', '.join(dim_names))
    if meta:
        parts.append('  (' + ' | '.join(meta) + ')')
    tree_lines.append(''.join(parts))

# Generate suggested analyses based on tree structure
# Capped at 4 to keep session-start output scannable
suggestions = []
first = trees[0]
first_label = first['root'] or first['id']

suggestions.append(f'\"How did {first_label} perform last week?\" — weekly health check on **{first[\"id\"]}**')

if count >= 2:
    suggestions.append(f'\"Compare {trees[0][\"id\"]} vs {trees[1][\"id\"]} last month\" — validate whether a volume or mix shift is driving changes')

for t in trees:
    if any(kw in t['root'].lower() for kw in EFFICIENCY_KEYWORDS):
        suggestions.append(f'\"Is {t[\"root\"]} trending up or down?\" — multi-period trend on **{t[\"id\"]}** to spot patterns')
        break

for t in trees:
    if t['children'] and t['id'] != first['id']:
        label = t['root'] or t['id']
        suggestions.append(f'\"Why did {label} change this month?\" — deterministic root cause analysis on **{t[\"id\"]}**')
        break

for t in trees:
    if t['dims']:
        dim_name = t['dims'][0].get('name', str(t['dims'][0])) if isinstance(t['dims'][0], dict) else str(t['dims'][0])
        suggestions.append(f'\"Which {dim_name} segments drove the biggest changes?\" — segment-level Shapley attribution on **{t[\"id\"]}**')
        break

suggestions = suggestions[:4]

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
