#!/usr/bin/env bash
# Qluent session-start hook: injects available metric trees into context.
# Fails silently if qluent is not installed or configured.

set -euo pipefail

# Check if qluent is available
if ! command -v qluent &>/dev/null; then
  exit 0
fi

# Try to list trees — exits silently on auth/config failure
output=$(qluent trees list --json-output 2>/dev/null) || exit 0

# Count trees
count=$(echo "$output" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    trees = data if isinstance(data, list) else data.get('trees', [])
    print(len(trees))
except:
    print(0)
" 2>/dev/null) || count=0

if [ "$count" -eq 0 ]; then
  exit 0
fi

# Extract tree names and descriptions
tree_info=$(echo "$output" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    trees = data.get('trees', data) if isinstance(data, dict) else data
    for t in trees:
        name = t.get('id', t.get('tree_id', 'unknown'))
        desc = t.get('description', t.get('label', ''))
        if desc:
            print(f'- {name}: {desc}')
        else:
            print(f'- {name}')
except:
    pass
" 2>/dev/null)

# Output context for Claude (stdout is injected into conversation)
cat <<EOF
[Qluent] ${count} metric trees available for analysis:
${tree_info}

Use /qluent:investigate or ask a business performance question to start.
EOF
