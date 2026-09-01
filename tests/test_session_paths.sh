#!/usr/bin/env bash
# Architectural fitness test for the canonical session-path rendezvous.
#
# Enforces the resolution of #46 (each rendezvous file appears in exactly the
# documented allowlist of files -- a forcing function for "do we want a new
# consumer?") and of #78 (the rendezvous is scoped to one user and one Claude
# session instead of being global to the machine).
#
# Each rendezvous file is declared exactly once, in the protocol module whose
# readers use it (#102): the workspace itself and the query-path files in
# qluent-interpretation, the tree-path files in qluent-tree-protocol.
# scripts/session-paths.sh is the executable counterpart of both. Every other
# entry in each list is a real producer, consumer, or test fixture.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/plugins/qluent/skills/qluent-interpretation/SKILL.md"
TREE_SKILL="$ROOT/plugins/qluent/skills/qluent-tree-protocol/SKILL.md"
SESSION_PATHS="$ROOT/plugins/qluent/scripts/session-paths.sh"
SESSION_DIR_SCRIPT="$ROOT/plugins/qluent/scripts/session-dir.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file" || fail "$file should contain: $needle"
}

# Find every file containing the given literal. Returns repo-relative paths
# sorted alphabetically.
find_references() {
  local needle="$1"
  grep -rlF --include='*.md' --include='*.sh' --include='*.yml' --include='*.json' \
      -e "$needle" \
      "$ROOT/plugins" "$ROOT/tests" "$ROOT/README.md" 2>/dev/null \
    | while read -r f; do echo "${f#$ROOT/}"; done \
    | sort
}

# Assert the set of files referencing $name matches $allowlist exactly.
check_path() {
  local name="$1"
  shift
  local expected
  expected=$(printf '%s\n' "$@" | sort)
  local actual
  actual=$(find_references "$name")

  if [ "$actual" != "$expected" ]; then
    echo "FAIL: Allowlist drift for session file '$name'" >&2
    echo "  Expected:" >&2
    printf '    %s\n' "$@" | sort >&2
    echo "  Actual:" >&2
    printf '    %s\n' $actual >&2
    echo "  If you intentionally added or removed a reference, update the" >&2
    echo "  allowlist in tests/test_session_paths.sh and the Session paths" >&2
    echo "  section in qluent-interpretation/ or qluent-tree-protocol/." >&2
    exit 1
  fi
}

# 1. The core skill carries the workspace itself, the prelude that resolves
#    it, and the query-path files; the tree module carries the tree-path
#    files. Neither declares the other's, so nobody loads a file description
#    they will not use.
assert_contains "$SKILL" '## Session paths'
assert_contains "$SKILL" '$QLUENT_DIR'
assert_contains "$SKILL" 'scripts/session-dir.sh'
assert_contains "$SKILL" 'qluent-$UID-$CLAUDE_CODE_SESSION_ID'
assert_contains "$SKILL" '$QLUENT_DIR/query-result.json'
assert_contains "$SKILL" '$QLUENT_DIR/plan-result.json'

assert_contains "$TREE_SKILL" '$QLUENT_DIR/viz-data.json'
assert_contains "$TREE_SKILL" '$QLUENT_DIR/deep-dive-bundle.json'
assert_contains "$TREE_SKILL" '$QLUENT_DIR/tree-capabilities.json'

# 2. No fixed machine-global rendezvous path may come back (#78). This is the
#    regression guard: such a path is shared across sessions, projects and
#    users, which is exactly the bug.
stale=$(grep -rlE --include='*.md' --include='*.sh' --include='*.yml' --include='*.json' \
    -e '/tmp/qluent-[a-z-]*\.json' \
    "$ROOT/plugins" "$ROOT/tests" "$ROOT/README.md" 2>/dev/null || true)
if [ -n "$stale" ]; then
  echo "FAIL: fixed /tmp/qluent-*.json rendezvous paths are back in:" >&2
  printf '    %s\n' $stale >&2
  echo "  Use the per-session workspace instead -- see the Session paths" >&2
  echo "  section in qluent-interpretation/SKILL.md." >&2
  exit 1
fi

# 3. Allowlist enforcement, by file name within the workspace.
check_path 'viz-data.json' \
  'plugins/qluent/skills/qluent-orientation/SKILL.md' \
  'plugins/qluent/agents/qluent-analyst.md' \
  'plugins/qluent/commands/investigate.md' \
  'plugins/qluent/commands/visualize.md' \
  'plugins/qluent/scripts/session-paths.sh' \
  'plugins/qluent/skills/qluent-tree-protocol/SKILL.md' \
  'tests/test_analysis_run_handles.sh' \
  'tests/test_pre_bash_approval.sh' \
  'tests/test_renderer_contract.sh' \
  'tests/test_session_paths.sh'

check_path 'deep-dive-bundle.json' \
  'plugins/qluent/skills/qluent-orientation/SKILL.md' \
  'plugins/qluent/commands/deep-dive.md' \
  'plugins/qluent/commands/visualize.md' \
  'plugins/qluent/scripts/render-charts.sh' \
  'plugins/qluent/scripts/session-paths.sh' \
  'plugins/qluent/skills/qluent-tree-protocol/SKILL.md' \
  'tests/test_analysis_run_handles.sh' \
  'tests/test_renderer_contract.sh' \
  'tests/test_session_paths.sh'

check_path 'tree-capabilities.json' \
  'plugins/qluent/agents/rca-validator.md' \
  'plugins/qluent/agents/segment-explorer.md' \
  'plugins/qluent/scripts/session-paths.sh' \
  'plugins/qluent/skills/qluent-tree-protocol/SKILL.md' \
  'tests/test_session_paths.sh'

check_path 'query-result.json' \
  'plugins/qluent/agents/qluent-analyst.md' \
  'plugins/qluent/commands/query.md' \
  'plugins/qluent/commands/visualize.md' \
  'plugins/qluent/scripts/session-paths.sh' \
  'plugins/qluent/skills/qluent-interpretation/SKILL.md' \
  'tests/test_pre_bash_approval.sh' \
  'tests/test_query_contract.sh' \
  'tests/test_session_paths.sh'

# The compose paths narrowed in #77: /qluent:query and qluent-analyst no
# longer restate the catalog fetch or the plan run, so they no longer name the
# input files. They still read the *result* when presenting an answer.
check_path 'catalog.json' \
  'plugins/qluent/scripts/session-paths.sh' \
  'plugins/qluent/skills/compose-authoring/SKILL.md' \
  'plugins/qluent/skills/qluent-interpretation/SKILL.md' \
  'tests/test_pre_bash_approval.sh' \
  'tests/test_session_paths.sh'

check_path 'plan.json' \
  'plugins/qluent/scripts/session-paths.sh' \
  'plugins/qluent/skills/compose-authoring/SKILL.md' \
  'plugins/qluent/skills/qluent-interpretation/SKILL.md' \
  'tests/test_pre_bash_approval.sh' \
  'tests/test_session_paths.sh'

check_path 'plan-result.json' \
  'plugins/qluent/agents/qluent-analyst.md' \
  'plugins/qluent/commands/query.md' \
  'plugins/qluent/commands/visualize.md' \
  'plugins/qluent/scripts/session-paths.sh' \
  'plugins/qluent/skills/compose-authoring/SKILL.md' \
  'plugins/qluent/skills/qluent-interpretation/SKILL.md' \
  'tests/test_pre_bash_approval.sh' \
  'tests/test_query_contract.sh' \
  'tests/test_session_paths.sh'

# 4. The workspace itself: created 0700, distinct per session, and refused
#    when it belongs to someone else.
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

dir_a=$(TMPDIR="$scratch" CLAUDE_CODE_SESSION_ID=session-a bash "$SESSION_DIR_SCRIPT")
dir_b=$(TMPDIR="$scratch" CLAUDE_CODE_SESSION_ID=session-b bash "$SESSION_DIR_SCRIPT")

[ "$dir_a" != "$dir_b" ] || fail "two sessions must not share one workspace directory"
[ -d "$dir_a" ] || fail "session-dir.sh did not create $dir_a"
perms=$(ls -ld "$dir_a" | cut -c1-10)
[ "$perms" = "drwx------" ] || fail "workspace should be 0700, got $perms"

# The same session id resolves to the same directory from an independent call.
dir_a_again=$(TMPDIR="$scratch" CLAUDE_CODE_SESSION_ID=session-a bash "$SESSION_DIR_SCRIPT")
[ "$dir_a_again" = "$dir_a" ] || fail "the workspace must be stable within a session"

# An unset session id must still be scoped to this user, never to a bare
# /tmp/qluent path shared with everyone.
dir_unset=$(TMPDIR="$scratch" bash -c 'unset CLAUDE_CODE_SESSION_ID; exec bash "$0"' "$SESSION_DIR_SCRIPT")
case "$dir_unset" in
  "$scratch"/qluent-*) ;;
  *) fail "unset session id resolved to an unexpected workspace: $dir_unset" ;;
esac
assert_contains "$SESSION_PATHS" 'UID'

# A directory owned by another user is refused rather than reused. Only
# meaningful where this test can hand a directory to a different uid.
foreign="$scratch/foreign"
mkdir -p "$foreign/qluent-${UID:-0}-session-c"
if chown -R 12345 "$foreign/qluent-${UID:-0}-session-c" 2>/dev/null; then
  if TMPDIR="$foreign" CLAUDE_CODE_SESSION_ID=session-c bash "$SESSION_DIR_SCRIPT" >/dev/null 2>&1; then
    fail "session-dir.sh must refuse a workspace owned by another user"
  fi
else
  echo "  (skipped foreign-ownership case: cannot chown in this environment)"
fi

echo "session paths tests passed"
