#!/usr/bin/env bash
set -euo pipefail

# Locks in the contract that /qluent:deep-dive renders an insight-driven HTML
# dashboard via the dashboard-design skill alongside the markdown narrative.
# This test guards the prompt structure — not the rendered HTML, which Claude
# composes at runtime from the deterministic bundle.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEEP_DIVE="$ROOT/plugins/qluent/commands/deep-dive.md"
SKILL="$ROOT/plugins/qluent/skills/dashboard-design/SKILL.md"

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

# 1. The dashboard-design skill referenced by deep-dive.md must actually exist.
[[ -f "$SKILL" ]] || fail "missing skill referenced by deep-dive.md: $SKILL"

# 2. deep-dive.md frontmatter must allow Write so the model can save the HTML,
#    and date so the timestamped output path can be resolved.
assert_contains "$DEEP_DIVE" \
  'allowed-tools: Bash(which qluent), Bash(qluent *), Bash(date *), AskUserQuestion, Read, Write'

# 3. deep-dive.md must include the insight-driven HTML rendering step and link
#    it to the dashboard-design skill.
assert_contains "$DEEP_DIVE" '## Step 7: Render the insight-driven HTML dashboard'
assert_contains "$DEEP_DIVE" \
  '${CLAUDE_PLUGIN_ROOT}/skills/dashboard-design/SKILL.md'

# 4. The HTML output must use a unique timestamped path so older runs do not
#    collide. Mirrors the /tmp/qluent-viz-<timestamp>.html convention.
assert_contains "$DEEP_DIVE" '/tmp/qluent-deep-dive-$(date +%Y%m%d-%H%M%S).html'

# 5. The "insight takeaways" surface — the user-visible feature being restored
#    from the Apr 10 dashboard — must be present in the prompt.
assert_contains "$DEEP_DIVE" 'Insight callouts'
assert_contains "$DEEP_DIVE" '.insight-warn'
assert_contains "$DEEP_DIVE" '.insight-bad'

# 6. Section composition must be data-driven, not templated.
assert_contains "$DEEP_DIVE" 'insight-to-section mapping'
assert_contains "$DEEP_DIVE" 'sections backed by actual bundle data'
assert_contains "$DEEP_DIVE" 'omit a section rather than render an'

# 7. The Rules section must enforce the HTML rendering rather than leaving it
#    optional, so the markdown narrative cannot ship without the dashboard.
assert_contains "$DEEP_DIVE" \
  'Always render an insight-driven HTML dashboard via the `dashboard-design`'

# 8. The dashboard-design skill must define the components deep-dive.md leans
#    on. If any of these are renamed, deep-dive.md needs to follow.
assert_contains "$SKILL" '### Hero'
assert_contains "$SKILL" '### KPI Strip'
assert_contains "$SKILL" '### Insight Callout'
assert_contains "$SKILL" '## Insight-to-Section Mapping'

# 9. Deep-dive must not regress to the static-template path that visualize uses
#    as its --simple fallback. That template lives in render-charts.html and is
#    reachable from /qluent:visualize, not from /qluent:deep-dive.
assert_not_contains "$DEEP_DIVE" 'render-charts.sh'
assert_not_contains "$DEEP_DIVE" 'render-charts.html'

echo "deep-dive HTML contract tests passed"
