#!/usr/bin/env bash
# Architectural fitness test for the slash-command surface.
# Enforces the resolution of #48 (Option B): /qluent:trend, /qluent:rca, and
# /qluent:compare are pass-throughs and have been deleted. Agents still call
# the underlying qluent CLI subcommands directly.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_not_exists() {
  local path="$1"
  if [ -e "$path" ]; then
    fail "$path should not exist (deleted in #48)"
  fi
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

# 1. The three pass-through command files are deleted.
assert_not_exists "$ROOT/plugins/qluent/commands/trend.md"
assert_not_exists "$ROOT/plugins/qluent/commands/rca.md"
assert_not_exists "$ROOT/plugins/qluent/commands/compare.md"

# 2. README no longer advertises the deleted slash commands.
assert_not_contains "$ROOT/README.md" '/qluent:trend'
assert_not_contains "$ROOT/README.md" '/qluent:rca'
assert_not_contains "$ROOT/README.md" '/qluent:compare'

# 3. CLAUDE.md no longer lists the deleted commands or carries the warning
#    that existed only because the commands tempted the wrong workflow.
assert_not_contains "$ROOT/plugins/qluent/CLAUDE.md" '/qluent:trend'
assert_not_contains "$ROOT/plugins/qluent/CLAUDE.md" '/qluent:rca'
assert_not_contains "$ROOT/plugins/qluent/CLAUDE.md" '/qluent:compare'
assert_not_contains "$ROOT/plugins/qluent/CLAUDE.md" 'Do NOT manually chain'

# 4. Other plugin docs no longer point users at the deleted slash commands.
assert_not_contains "$ROOT/plugins/qluent/commands/deep-dive.md" '/qluent:trend'
assert_not_contains "$ROOT/plugins/qluent/commands/deep-dive.md" '/qluent:rca'
assert_not_contains "$ROOT/plugins/qluent/commands/deep-dive.md" '/qluent:compare'
assert_not_contains "$ROOT/plugins/qluent/scripts/post-bash.sh" '/qluent:trend'
assert_not_contains "$ROOT/plugins/qluent/scripts/post-bash.sh" '/qluent:rca'
assert_not_contains "$ROOT/plugins/qluent/scripts/post-bash.sh" '/qluent:compare'
assert_not_contains "$ROOT/plugins/qluent/skills/qluent-interpretation/SKILL.md" '/qluent:trend'
assert_not_contains "$ROOT/plugins/qluent/skills/qluent-interpretation/SKILL.md" '/qluent:rca'
assert_not_contains "$ROOT/plugins/qluent/skills/qluent-interpretation/SKILL.md" '/qluent:compare'

# 5. Agents still own the underlying CLI subcommand surface — that's why the
#    slash commands could be deleted without losing capability.
assert_contains "$ROOT/plugins/qluent/agents/qluent-analyst.md" 'qluent trees trend'
assert_contains "$ROOT/plugins/qluent/agents/qluent-analyst.md" 'qluent rca analyze'
assert_contains "$ROOT/plugins/qluent/agents/qluent-analyst.md" 'qluent trees compare'
assert_contains "$ROOT/plugins/qluent/agents/rca-validator.md" 'qluent trees trend'
assert_contains "$ROOT/plugins/qluent/agents/rca-validator.md" 'qluent rca analyze'
assert_contains "$ROOT/plugins/qluent/agents/rca-validator.md" 'qluent trees compare'

echo "command surface tests passed"
