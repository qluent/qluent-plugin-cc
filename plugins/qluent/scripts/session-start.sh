#!/usr/bin/env bash
# Qluent session-start hook: injects available metric tree metadata into context.
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

# Extract tree metadata for context injection
context=$(echo "$output" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
    raw = data.get('trees', data) if isinstance(data, dict) else data
except Exception:
    sys.exit(0)

if not raw:
    sys.exit(0)

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

print(f'[Qluent] {count} metric tree{\"s\" if count != 1 else \"\"} available for analysis:')
print()
for t in trees:
    line = f'- **{t[\"id\"]}**'
    if t['desc']:
        line += f': {t[\"desc\"]}'
    meta = []
    if t['root']:
        meta.append(f'root metric: {t[\"root\"]}')
    if t['children']:
        names = [c.get('id', c.get('name', str(c))) if isinstance(c, dict) else str(c) for c in t['children'][:5]]
        meta.append('breaks into: ' + ', '.join(names))
    if t['dims']:
        names = [d.get('name', str(d)) if isinstance(d, dict) else str(d) for d in t['dims'][:4]]
        meta.append('segments: ' + ', '.join(names))
    if meta:
        line += '  (' + ' | '.join(meta) + ')'
    print(line)
print()
print('Ask a business performance question or use /qluent:investigate to start.')
" 2>/dev/null) || context=""

if [ -n "$context" ]; then
  echo "$context"
fi
