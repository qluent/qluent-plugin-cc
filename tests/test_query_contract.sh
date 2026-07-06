#!/usr/bin/env bash
# Contract tests for the /qluent:query surface: ad-hoc NL queries routed
# through `qluent query`. Static prompt-contract asserts plus post-bash hook
# behavior against fixture payloads.
#
# Note: /qluent:query is not a #48-style pass-through around a single CLI
# call — the command owns a clarification loop, long-runtime UX, and the
# provenance boundary between ad-hoc SQL results and deterministic tree
# evidence, so it earns its own command surface.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/plugins/qluent/skills/qluent-interpretation/SKILL.md"
QUERY_CMD="$ROOT/plugins/qluent/commands/query.md"
VISUALIZE="$ROOT/plugins/qluent/commands/visualize.md"
ANALYST="$ROOT/plugins/qluent/agents/qluent-analyst.md"
SESSION_START="$ROOT/plugins/qluent/scripts/session-start.sh"
HOOK="$ROOT/plugins/qluent/scripts/post-bash.sh"
README="$ROOT/README.md"
PLUGIN_CLAUDE="$ROOT/plugins/qluent/CLAUDE.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file" || fail "$file should contain: $needle"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq -- "$needle" "$file"; then
    fail "$file should not contain: $needle"
  fi
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

# 1. The command exists and owns the capability guard, clarification loop,
#    and session-path tee.
[ -f "$QUERY_CMD" ] || fail "commands/query.md is missing"
assert_contains "$QUERY_CMD" 'qluent query --help'
assert_contains "$QUERY_CMD" '--thread'
assert_contains "$QUERY_CMD" 'AskUserQuestion'
assert_contains "$QUERY_CMD" '--json-output | tee /tmp/qluent-query-result.json'
# Clean-stdout rule: stderr must not leak into the saved JSON.
assert_not_contains "$QUERY_CMD" '2>&1 | tee'
# Failure-preservation rule: without pipefail the pipeline exits with tee's
# status, so a failed CLI run looks successful and leaves an invalid saved file.
assert_contains "$QUERY_CMD" 'set -o pipefail'
assert_contains "$ANALYST" 'set -o pipefail'

# 2. The skill owns the canonical routing rule and session-path declaration.
assert_contains "$SKILL" '## Ad-hoc query routing'
assert_contains "$SKILL" 'Trees win ties'
assert_contains "$SKILL" '/tmp/qluent-query-result.json'

# 3. Routing consumers point at the query path.
assert_contains "$ANALYST" 'qluent query'
assert_contains "$SESSION_START" '/qluent:query'

# 4. Docs advertise the command; visualize declares the renderer boundary.
assert_contains "$README" '/qluent:query'
assert_contains "$PLUGIN_CLAUDE" '/qluent:query'
assert_contains "$VISUALIZE" '`--simple` is unsupported for query payloads'

# 5. Hook behavior against fixture payloads.
tmpdir="$(mktemp -d)"
query_file="/tmp/qluent-query-result.json"
viz_file="/tmp/qluent-viz-data.json"

restore_tmp_files() {
  rm -f "$query_file" "$viz_file"
  if [ -f "$tmpdir/query-result.bak" ]; then
    cp "$tmpdir/query-result.bak" "$query_file"
  fi
  if [ -f "$tmpdir/viz-data.bak" ]; then
    cp "$tmpdir/viz-data.bak" "$viz_file"
  fi
  rm -rf "$tmpdir"
}

if [ -f "$query_file" ]; then
  cp "$query_file" "$tmpdir/query-result.bak"
fi
if [ -f "$viz_file" ]; then
  cp "$viz_file" "$tmpdir/viz-data.bak"
fi
trap restore_tmp_files EXIT

QUERY_TOOL_INPUT='{"command":"qluent query \"top customers by refunds\" --json-output | tee /tmp/qluent-query-result.json"}'

# 5a. Successful result: surface the thread id, links, and visualize pointer.
cat > "$query_file" <<'JSON'
{
  "status": "ok",
  "thread_id": "th_123",
  "download_url": "https://example.com/dl",
  "google_sheets_url": "https://sheets.example.com/x"
}
JSON

out=$(TOOL_INPUT="$QUERY_TOOL_INPUT" bash "$HOOK")
assert_output_contains "$out" 'Query thread: th_123'
assert_output_contains "$out" '--thread th_123'
assert_output_contains "$out" 'https://example.com/dl'
assert_output_contains "$out" '/qluent:visualize --file /tmp/qluent-query-result.json'

# 5b. Pending clarification: nudge the loop instead of the follow-up hints.
cat > "$query_file" <<'JSON'
{
  "status": "clarification_needed",
  "thread_id": "th_456",
  "clarification": {"message": "Which revenue?", "options": ["Gross", "Net"]}
}
JSON

out=$(TOOL_INPUT="$QUERY_TOOL_INPUT" bash "$HOOK")
assert_output_contains "$out" 'needs clarification'
assert_output_contains "$out" '--thread th_456'
assert_output_not_contains "$out" 'Query thread: th_456'

# 5c. No saved payload: remind about the tee.
rm -f "$query_file"
out=$(TOOL_INPUT='{"command":"qluent query \"top customers\" --json-output"}' bash "$HOOK")
assert_output_contains "$out" '| tee /tmp/qluent-query-result.json'

# 5d. Question text containing tree keywords must not trigger tree guidance.
out=$(TOOL_INPUT='{"command":"qluent query \"compare revenue trend by rca segment\" --json-output"}' bash "$HOOK")
assert_output_not_contains "$out" 'RcaReportSpec'
assert_output_not_contains "$out" '/qluent:investigate'

# 5e. Tree commands must not emit query guidance.
rm -f "$viz_file"
out=$(TOOL_INPUT='{"command":"qluent trees investigate revenue --period \"last week\" --json-output"}' bash "$HOOK")
assert_output_not_contains "$out" 'Query thread:'
assert_output_not_contains "$out" '/tmp/qluent-query-result.json'

echo "query contract tests passed"
