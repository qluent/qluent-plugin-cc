#!/usr/bin/env bash
# Behavior and prompt-contract tests for #60: AnalysisRun ids are durable
# handles in Claude Code metric-tree workflows.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/plugins/qluent/skills/qluent-interpretation/SKILL.md"
INVESTIGATE="$ROOT/plugins/qluent/commands/investigate.md"
DEEP_DIVE="$ROOT/plugins/qluent/commands/deep-dive.md"
VISUALIZE="$ROOT/plugins/qluent/commands/visualize.md"
ANALYST="$ROOT/plugins/qluent/agents/qluent-analyst.md"
HOOK="$ROOT/plugins/qluent/scripts/post-bash.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file" || fail "$file should contain: $needle"
}

assert_output_contains() {
  local output="$1"
  local needle="$2"
  case "$output" in
    *"$needle"*) ;;
    *) fail "output should contain: $needle"$'\n'"Actual output:"$'\n'"$output" ;;
  esac
}

assert_output_not_contains() {
  local output="$1"
  local needle="$2"
  case "$output" in
    *"$needle"*) fail "output should not contain: $needle"$'\n'"Actual output:"$'\n'"$output" ;;
    *) ;;
  esac
}

# 1. The canonical protocol defines AnalysisRun as the handoff object and keeps
#    the legacy response behavior explicit.
assert_contains "$SKILL" '## AnalysisRun handles'
assert_contains "$SKILL" 'question -> persisted AnalysisRun -> lever/root-cause breakdown -> insights -> recommended actions'
assert_contains "$SKILL" 'Analysis run: <analysis_run_uuid>'
assert_contains "$SKILL" 'legacy response'

# 2. Callers reference/carry the run id in the workflows that consume
#    investigate output.
assert_contains "$INVESTIGATE" 'If `$ARGUMENTS` contains an existing `analysis_run_uuid`'
assert_contains "$INVESTIGATE" 'Analysis run: <analysis_run_uuid>'
assert_contains "$ANALYST" 'If the user provides an `analysis_run_uuid`'
assert_contains "$VISUALIZE" 'analysis_run_uuid?: string'
assert_contains "$DEEP_DIVE" 'optional `analysis_run_uuid`'

# 3. The hook surfaces run ids from cached investigate JSON and remains quiet
#    for older CLI/backend payloads that do not include the additive field.
tmpdir="$(mktemp -d)"
viz_file="/tmp/qluent-viz-data.json"
deep_dive_file="/tmp/qluent-deep-dive-bundle.json"

restore_tmp_files() {
  rm -f "$viz_file" "$deep_dive_file"
  if [ -f "$tmpdir/viz-data.bak" ]; then
    cp "$tmpdir/viz-data.bak" "$viz_file"
  fi
  if [ -f "$tmpdir/deep-dive.bak" ]; then
    cp "$tmpdir/deep-dive.bak" "$deep_dive_file"
  fi
  rm -rf "$tmpdir"
}

if [ -f "$viz_file" ]; then
  cp "$viz_file" "$tmpdir/viz-data.bak"
fi
if [ -f "$deep_dive_file" ]; then
  cp "$deep_dive_file" "$tmpdir/deep-dive.bak"
fi
trap restore_tmp_files EXIT

cat > "$viz_file" <<'JSON'
{
  "tree_id": "revenue",
  "analysis_run_uuid": "11111111-2222-4333-8444-555555555555",
  "current_window": {"date_from": "2026-05-01", "date_to": "2026-05-07"},
  "comparison_window": {"date_from": "2026-04-24", "date_to": "2026-04-30"}
}
JSON

out=$(TOOL_INPUT='{"command":"qluent trees investigate revenue --period \"last week\" --json-output | tee /tmp/qluent-viz-data.json"}' bash "$HOOK")
assert_output_contains "$out" 'Analysis run: 11111111-2222-4333-8444-555555555555'
assert_output_contains "$out" 'Use AnalysisRun ids as durable handles'

cat > "$viz_file" <<'JSON'
{
  "tree_id": "revenue",
  "current_window": {"date_from": "2026-05-01", "date_to": "2026-05-07"},
  "comparison_window": {"date_from": "2026-04-24", "date_to": "2026-04-30"}
}
JSON

out=$(TOOL_INPUT='{"command":"qluent trees investigate revenue --period \"last week\" --json-output | tee /tmp/qluent-viz-data.json"}' bash "$HOOK")
assert_output_not_contains "$out" 'Analysis run:'

cat > "$deep_dive_file" <<'JSON'
{
  "period": "last week",
  "results": [
    {"tree_id": "conversion", "analysis_run_uuid": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"},
    {"tree_id": "revenue", "analysis_run_uuid": "99999999-8888-4777-8666-555555555555"}
  ]
}
JSON

out=$(TOOL_INPUT='{"command":"qluent trees deep-dive --json-output --period \"last week\" | tee /tmp/qluent-deep-dive-bundle.json"}' bash "$HOOK")
assert_output_contains "$out" 'Analysis runs:'
assert_output_contains "$out" 'conversion: aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
assert_output_contains "$out" 'revenue: 99999999-8888-4777-8666-555555555555'

echo "analysis run handle tests passed"
