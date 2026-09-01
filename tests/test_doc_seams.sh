#!/usr/bin/env bash
# Architectural fitness test for the README / qluent-orientation / qluent-interpretation
# skill seams. Enforces the resolution of #49: each document has one audience
# and one job, with no overlap.
#
#   README.md                          → users: install, quickstart, commands, release.
#   .../skills/qluent-orientation/     → agents: proactive guidance + pointers.
#   .../skills/qluent-interpretation/  → protocol: rules, conventions, algorithms.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT/README.md"
ORIENTATION="$ROOT/plugins/qluent/skills/qluent-orientation/SKILL.md"

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
    fail "$file should not contain (this concern lives in a different doc by audience): $needle"
  fi
}

# 1. README owns user onboarding.
assert_contains "$README" 'npm install -g @qluent/cli'
assert_contains "$README" '/plugin marketplace add qluent/qluent-plugin-cc'

# 2. README does not own the cross-tree deep-dive narrative shape — that lives
#    in commands/deep-dive.md as the workflow contract for the model.
assert_not_contains "$README" 'Concentration** — segments that show up'
assert_not_contains "$README" 'Mechanism** — whether the movement'
assert_not_contains "$README" 'Next-best drills** — ranked'

# 3. the orientation skill owns agent orientation and references the skill.
assert_contains "$ORIENTATION" 'qluent-interpretation'

# 4. the orientation skill does not own user onboarding.
assert_not_contains "$ORIENTATION" 'npm install'
assert_not_contains "$ORIENTATION" 'qluent login'

# 5. the orientation skill does not own the visualization precedence rule (the skill's
#    Visualization section owns it).
assert_not_contains "$ORIENTATION" 'Do not hand-roll HTML/CSS/Chart.js'
assert_not_contains "$ORIENTATION" 'Local HTML is a fallback only on'

# 6. the orientation skill does not own deep-dive synthesis instructions (the deep-dive
#    command and the skill own those).
assert_not_contains "$ORIENTATION" 'Synthesize the bundle into one narrative'
assert_not_contains "$ORIENTATION" 'never split into per-tree reports'

echo "doc seams tests passed"
