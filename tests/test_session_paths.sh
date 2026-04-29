#!/usr/bin/env bash
# Architectural fitness test for the canonical session-path rendezvous.
# Enforces the resolution of #46: each canonical /tmp/qluent-* path appears
# in exactly the documented allowlist of files. Any addition or removal
# requires updating this allowlist (a forcing function for "do we want a
# new consumer?" decisions).
#
# The qluent-interpretation skill is the single canonical declaration; every
# other entry in each list is a real producer, consumer, or test fixture.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/plugins/qluent/skills/qluent-interpretation/SKILL.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file" || fail "$file should contain: $needle"
}

# Find every file containing the given literal path. Returns repo-relative
# paths sorted alphabetically.
find_references() {
  local needle="$1"
  grep -rlF "$needle" \
      --include='*.md' --include='*.sh' --include='*.yml' --include='*.json' \
      "$ROOT/plugins" "$ROOT/tests" "$ROOT/README.md" 2>/dev/null \
    | while read -r f; do echo "${f#$ROOT/}"; done \
    | sort
}

# Assert the set of files referencing $path matches $allowlist exactly.
check_path() {
  local path="$1"
  shift
  local expected
  expected=$(printf '%s\n' "$@" | sort)
  local actual
  actual=$(find_references "$path")

  if [ "$actual" != "$expected" ]; then
    echo "FAIL: Allowlist drift for path '$path'" >&2
    echo "  Expected:" >&2
    printf '    %s\n' "$@" | sort >&2
    echo "  Actual:" >&2
    printf '    %s\n' $actual >&2
    echo "  If you intentionally added or removed a reference, update the" >&2
    echo "  allowlist in tests/test_session_paths.sh and the Session paths" >&2
    echo "  section in qluent-interpretation/SKILL.md." >&2
    exit 1
  fi
}

# 1. Skill has the canonical Session paths section that names each path.
assert_contains "$SKILL" '## Session paths'
assert_contains "$SKILL" '/tmp/qluent-viz-data.json'
assert_contains "$SKILL" '/tmp/qluent-deep-dive-bundle.json'
assert_contains "$SKILL" '/tmp/qluent-tree-capabilities.json'

# 2. Allowlist enforcement.
check_path '/tmp/qluent-viz-data.json' \
  'plugins/qluent/agents/qluent-analyst.md' \
  'plugins/qluent/commands/investigate.md' \
  'plugins/qluent/commands/visualize.md' \
  'plugins/qluent/scripts/post-bash.sh' \
  'plugins/qluent/scripts/render-charts.sh' \
  'plugins/qluent/skills/qluent-interpretation/SKILL.md' \
  'tests/test_renderer_contract.sh' \
  'tests/test_session_paths.sh'

check_path '/tmp/qluent-deep-dive-bundle.json' \
  'plugins/qluent/commands/deep-dive.md' \
  'plugins/qluent/scripts/post-bash.sh' \
  'plugins/qluent/skills/qluent-interpretation/SKILL.md' \
  'tests/test_session_paths.sh'

check_path '/tmp/qluent-tree-capabilities.json' \
  'plugins/qluent/agents/rca-validator.md' \
  'plugins/qluent/agents/segment-explorer.md' \
  'plugins/qluent/scripts/post-bash.sh' \
  'plugins/qluent/scripts/session-start.sh' \
  'plugins/qluent/skills/qluent-interpretation/SKILL.md' \
  'tests/test_session_paths.sh'

echo "session paths tests passed"
