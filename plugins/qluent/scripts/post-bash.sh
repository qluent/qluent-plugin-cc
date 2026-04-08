#!/usr/bin/env bash
# PostToolUse hook for Bash: injects contextual guidance after qluent CLI commands.
# Reminds about available skills and confirms viz data was saved.

set -euo pipefail

# Extract the command from TOOL_INPUT (JSON with a "command" field)
command=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null) || exit 0

# Only act on qluent CLI commands
[[ "$command" == *"qluent"* ]] || exit 0

# Detect which type of command was run
is_investigate=false
is_trend=false
is_rca=false
is_compare=false

[[ "$command" == *"investigate"* ]] && is_investigate=true
[[ "$command" == *"trend"* ]] && is_trend=true
[[ "$command" == *"rca"* ]] && is_rca=true
[[ "$command" == *"compare"* ]] && is_compare=true

# Only act on analysis commands (not list, validate, setup, etc.)
if ! $is_investigate && ! $is_trend && ! $is_rca && ! $is_compare; then
  exit 0
fi

# Build contextual guidance
echo ""
echo "[Qluent] Analysis complete."

# Viz data reminder
if [[ "$command" == *"--json-output"* ]]; then
  if [ -f /tmp/qluent-viz-data.json ]; then
    echo "  → Visualization data saved. Use /qluent:visualize for styled Qluent charts — do not write custom HTML."
  else
    echo "  → To enable /qluent:visualize, pipe output through: | tee /tmp/qluent-viz-data.json"
  fi
fi

# Contextual follow-up suggestions
if $is_investigate; then
  echo "  → Follow-up skills: /qluent:visualize (charts), /qluent:rca (root cause), /qluent:trend (multi-period), /qluent:compare (cross-tree)"
fi

if $is_trend || $is_rca || $is_compare; then
  echo "  → Offer /qluent:visualize to render these results as styled charts."
fi
