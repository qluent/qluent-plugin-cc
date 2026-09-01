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
PLUGIN_ORIENTATION="$ROOT/plugins/qluent/skills/qluent-orientation/SKILL.md"

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
# #76: capability comes off the session banner, which session-start.sh already
# established. A re-probe costs a call, several seconds and a permission
# prompt to learn something already in context -- so the command must read the
# banner, and probe only when no banner ran.
assert_contains "$QUERY_CMD" 'do not re-probe'
assert_contains "$QUERY_CMD" 'Query catalog available'
assert_contains "$QUERY_CMD" 'no** qluent banner in this session at all'
assert_contains "$QUERY_CMD" 'qluent --version || true'
assert_contains "$QUERY_CMD" 'qluent plan --help'
assert_not_contains "$QUERY_CMD" 'qluent --version && qluent plan --help'
assert_contains "$QUERY_CMD" '--thread'
assert_contains "$QUERY_CMD" 'AskUserQuestion'
assert_contains "$QUERY_CMD" '--json-output | tee "$QLUENT_DIR/query-result.json"'
# Clean-stdout rule: stderr must not leak into the saved JSON.
assert_not_contains "$QUERY_CMD" '2>&1 | tee'
# Failure-preservation rule: without pipefail the pipeline exits with tee's
# status, so a failed CLI run looks successful and leaves an invalid saved file.
assert_contains "$QUERY_CMD" 'set -o pipefail'
assert_contains "$ANALYST" 'set -o pipefail'
# Injection-safety rule: user-controlled question/answer text must pass through
# a quoted heredoc, never be pasted directly into the command line.
assert_contains "$QUERY_CMD" "<<'QLUENT_QUERY'"
assert_contains "$QUERY_CMD" "<<'QLUENT_ANSWER'"
assert_contains "$QUERY_CMD" 'qluent query "$question"'
assert_not_contains "$QUERY_CMD" 'qluent query "<question>"'
assert_contains "$ANALYST" "<<'QLUENT_QUERY'"
assert_not_contains "$ANALYST" 'qluent query "<question>"'
# Private-file rule: recreate the saved result 0600 and clobber stale files.
assert_contains "$QUERY_CMD" 'umask 077'
# #78: a $QLUENT_DIR reference without the resolving prelude expands to the
# filesystem root, so the two must always travel together.
assert_contains "$QUERY_CMD" 'scripts/session-dir.sh'
assert_contains "$ANALYST" 'scripts/session-dir.sh'
assert_contains "$QUERY_CMD" 'rm -f "$QLUENT_DIR/query-result.json"'
assert_contains "$ANALYST" 'umask 077'

# 1b. Both protocol modules load in one message rather than two sequential
#     reads (#76). The pointers themselves are the #32 seam, pinned by
#     tests/test_protocol_locality.sh.
assert_contains "$QUERY_CMD" '**in a single message**'
assert_contains "$QUERY_CMD" 'skills/compose-authoring/SKILL.md'

# 2. The skill owns the canonical routing rule and session-path declaration.
assert_contains "$SKILL" '## Query-first routing'
assert_contains "$SKILL" 'Query is the default workflow'
assert_contains "$SKILL" '$QLUENT_DIR/query-result.json'

# 3. Routing consumers point at the query path.
assert_contains "$ANALYST" 'qluent query'
assert_contains "$ANALYST" '  - compose-authoring'
assert_contains "$ANALYST" 'qluent plan --help'
assert_contains "$ANALYST" '$QLUENT_DIR/plan-result.json'
assert_contains "$ANALYST" 'composed query (deterministic)'
# #77: the compose invocations live in the compose-authoring skill only. Both
# compose-path callers defer to it instead of carrying their own copy;
# tests/test_protocol_locality.sh pins the allowlist.
assert_not_contains "$ANALYST" 'qluent catalog --json-output'
assert_not_contains "$QUERY_CMD" 'qluent catalog --json-output'
assert_not_contains "$QUERY_CMD" 'qluent plan --file'
assert_contains "$QUERY_CMD" 'compose-authoring'
assert_contains "$SESSION_START" '/qluent:query'

# 3b. The catalog projection must stay lossless (#73). `map_values({columns})`
#     kept 1 of the 9 fields the backend emits per base, hiding `date_column`
#     and `default_date_lookback_days` from the plan author — the vocabulary
#     that decides which column `params.date_range` filters. `plan_schema`
#     sits beside `catalog`, so a `.catalog.*`-only filter never reaches it.
COMPOSE_SKILL="$ROOT/plugins/qluent/skills/compose-authoring/SKILL.md"
assert_not_contains "$COMPOSE_SKILL" 'map_values({columns})'
for projected in \
  'bases: .catalog.bases' \
  'metrics: .catalog.metrics' \
  'relationships: .catalog.relationships' \
  'derived_dimensions: .catalog.derived_dimensions' \
  'column_aliases: .catalog.column_aliases' \
  'value_aliases: .catalog.value_aliases' \
  'derived_dimension_aliases: .catalog.derived_dimension_aliases' \
  'plan_schema: .plan_schema'
do
  assert_contains "$COMPOSE_SKILL" "$projected"
done
# The metadata the projection exists to preserve is named in the vocabulary
# list, so an author knows to look for it.
assert_contains "$COMPOSE_SKILL" 'date_column'
assert_contains "$COMPOSE_SKILL" 'default_date_lookback_days'
assert_contains "$COMPOSE_SKILL" 'scope_keys'

# 3c. Date windows must be conditional on the base's date_column (#74). The
#     old rule was unconditional -- "date windows go in params.date_range,
#     never in a filter_by" -- which compiles a correct-looking plan against
#     the wrong column whenever date_column is not the date the question
#     means, with no error to notice.
assert_not_contains "$COMPOSE_SKILL" 'never in a `filter_by`'
assert_contains "$COMPOSE_SKILL" '## Date windows: check the column first'
assert_contains "$COMPOSE_SKILL" 'not the date the question means'
assert_contains "$COMPOSE_SKILL" 'Omitting `params.date_range` is not the safe alternative'
assert_contains "$COMPOSE_SKILL" 'Omitting the range never means "all data"'
assert_contains "$COMPOSE_SKILL" 'full possible'
assert_contains "$COMPOSE_SKILL" 'prefer a catalog base whose `date_column` is the intended'
assert_contains "$COMPOSE_SKILL" 'If you cannot prove'

# 4. Docs advertise the command; visualize declares the renderer boundary.
assert_contains "$README" '/qluent:query'
assert_contains "$PLUGIN_ORIENTATION" '/qluent:query'
assert_contains "$VISUALIZE" '$QLUENT_DIR/plan-result.json'
assert_contains "$VISUALIZE" 'composed query (deterministic)'
assert_contains "$VISUALIZE" '`--simple` is unsupported for query payloads'

# 5. Hook behavior against fixture payloads.
# The rendezvous is scoped to $TMPDIR and the session id (#78), so pointing
# both at a scratch directory isolates these fixtures from any real session.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export TMPDIR="$tmpdir"
export CLAUDE_CODE_SESSION_ID="test-query-contract"
# shellcheck source=../plugins/qluent/scripts/session-paths.sh
. "$ROOT/plugins/qluent/scripts/session-paths.sh"
qluent_ensure_session_dir || fail "could not create the test session directory"

query_file="$QLUENT_QUERY_RESULT_FILE"
viz_file="$QLUENT_VIZ_DATA_FILE"
catalog_file="$QLUENT_CATALOG_FILE"

# 5a. A failed catalog probe must invalidate a cache from an earlier project.
mkdir -p "$tmpdir/bin"
cat > "$tmpdir/bin/qluent" <<'SH'
#!/usr/bin/env bash
if [ "$1 $2 $3" = "trees list --json-output" ]; then
  printf '{"trees":[]}'
  exit 0
fi
if [ "$1 $2" = "plan --help" ]; then
  exit 0
fi
if [ "$1 $2" = "catalog --json-output" ]; then
  echo 'QUERY_CATALOG_INVALID' >&2
  exit 1
fi
exit 1
SH
chmod +x "$tmpdir/bin/qluent"
printf '{"catalog":{"bases":{"stale_project":{}}}}' > "$catalog_file"
PATH="$tmpdir/bin:$PATH" bash "$SESSION_START" >/dev/null
[ ! -e "$catalog_file" ] || fail "session start should remove a stale catalog when the current project catalog fails"

QUERY_TOOL_INPUT='{"command":"qluent query \"top customers by refunds\" --json-output | tee $QLUENT_DIR/query-result.json"}'

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
assert_output_contains "$out" "/qluent:visualize --file $query_file"

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
assert_output_contains "$out" "| tee $query_file"

# 5d. Question text containing tree keywords must not trigger tree guidance.
out=$(TOOL_INPUT='{"command":"qluent query \"compare revenue trend by rca segment\" --json-output"}' bash "$HOOK")
assert_output_not_contains "$out" 'RcaReportSpec'
assert_output_not_contains "$out" '/qluent:investigate'

# 5e. Tree commands must not emit query guidance.
rm -f "$viz_file"
out=$(TOOL_INPUT='{"command":"qluent trees investigate revenue --period \"last week\" --json-output"}' bash "$HOOK")
assert_output_not_contains "$out" 'Query thread:'
assert_output_not_contains "$out" "$query_file"

echo "query contract tests passed"
