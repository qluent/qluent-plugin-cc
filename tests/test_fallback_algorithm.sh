#!/usr/bin/env bash
# Architectural fitness + behavior tests for the unsupported-cut fallback
# algorithm. Enforces the resolution of #47:
#   1. The ranking lives in exactly one place: scripts/select-fallback-tree.sh.
#   2. The skill names the algorithm; callers (post-bash hook, segment-explorer
#      agent, CLAUDE.md, session-start) defer to it instead of restating it.
#   3. Behavior tests pin the ranking decisions against synthetic catalogs.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/plugins/qluent/scripts/select-fallback-tree.sh"
SKILL="$ROOT/plugins/qluent/skills/qluent-interpretation/SKILL.md"
HOOK="$ROOT/plugins/qluent/scripts/post-bash.sh"
AGENT="$ROOT/plugins/qluent/agents/segment-explorer.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [ "$expected" != "$actual" ]; then
    fail "$label: expected [$expected], got [$actual]"
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
    fail "$file should not contain (algorithm lives in the skill + script): $needle"
  fi
}

# 1. The script exists and is executable.
[ -x "$SCRIPT" ] || fail "select-fallback-tree.sh must exist and be executable"

# 2. Behavior tests against synthetic catalogs.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Catalog A: tree_full has every requested dim → full_coverage.
cat > "$tmpdir/catalog_full.json" <<'JSON'
{"trees":[
  {"id":"current","root":"revenue","dims":["region"]},
  {"id":"tree_full","root":"orders","dims":["region","channel","cohort"]},
  {"id":"tree_partial","root":"orders","dims":["region","channel"]}
]}
JSON
out=$("$SCRIPT" "$tmpdir/catalog_full.json" "current" "channel,cohort")
assert_eq "tree_full" "$(printf '%s' "$out" | cut -f1)" "full_coverage selection"
assert_eq "full_coverage" "$(printf '%s' "$out" | cut -f2)" "full_coverage reason"

# Catalog B: no tree covers all dims; tree_high_overlap covers more than tree_low_overlap.
cat > "$tmpdir/catalog_partial.json" <<'JSON'
{"trees":[
  {"id":"current","root":"revenue","dims":["region"]},
  {"id":"tree_high_overlap","root":"orders","dims":["region","channel"]},
  {"id":"tree_low_overlap","root":"orders","dims":["region","platform"]}
]}
JSON
out=$("$SCRIPT" "$tmpdir/catalog_partial.json" "current" "channel,cohort,platform")
assert_eq "tree_high_overlap" "$(printf '%s' "$out" | cut -f1)" "partial_overlap selection (highest count)"
assert_eq "partial_overlap" "$(printf '%s' "$out" | cut -f2)" "partial_overlap reason"

# Catalog C: no overlap at all → none.
cat > "$tmpdir/catalog_none.json" <<'JSON'
{"trees":[
  {"id":"current","root":"revenue","dims":["region"]},
  {"id":"tree_unrelated","root":"orders","dims":["foo","bar"]}
]}
JSON
out=$("$SCRIPT" "$tmpdir/catalog_none.json" "current" "channel,cohort")
assert_eq "" "$(printf '%s' "$out" | cut -f1)" "none selection"
assert_eq "none" "$(printf '%s' "$out" | cut -f2)" "none reason"

# Catalog D: tiebreak — same overlap count, family wins over non-family.
cat > "$tmpdir/catalog_family.json" <<'JSON'
{"trees":[
  {"id":"current","root":"revenue","dims":["region"]},
  {"id":"tree_other_family","root":"orders","dims":["region","channel"]},
  {"id":"tree_same_family","root":"revenue","dims":["region","channel"]}
]}
JSON
out=$("$SCRIPT" "$tmpdir/catalog_family.json" "current" "channel")
assert_eq "tree_same_family" "$(printf '%s' "$out" | cut -f1)" "family tiebreak wins"

# Catalog E: tiebreak — same overlap, same family, alphabetical id wins.
cat > "$tmpdir/catalog_alpha.json" <<'JSON'
{"trees":[
  {"id":"current","root":"revenue","dims":["region"]},
  {"id":"tree_z","root":"revenue","dims":["region","channel"]},
  {"id":"tree_a","root":"revenue","dims":["region","channel"]}
]}
JSON
out=$("$SCRIPT" "$tmpdir/catalog_alpha.json" "current" "channel")
assert_eq "tree_a" "$(printf '%s' "$out" | cut -f1)" "alphabetical tiebreak wins"

# Catalog F: missing catalog file → none, exit 0.
out=$("$SCRIPT" "$tmpdir/does-not-exist.json" "current" "channel" || true)
assert_eq "none" "$(printf '%s' "$out" | cut -f2)" "missing catalog returns none"

# 3. Drift assertions: ranking-distinctive phrases live only in the skill +
#    the script implementing them. The agent, CLAUDE.md, and session-start.sh
#    must reference, not restate.
RANKING_PHRASES=(
  'Full coverage'
  'most overlapping'
  'Root-metric family tiebreak'
)
DRIFT_TARGETS=(
  "$AGENT"
  "$ROOT/plugins/qluent/CLAUDE.md"
  "$ROOT/plugins/qluent/scripts/session-start.sh"
)
for target in "${DRIFT_TARGETS[@]}"; do
  for phrase in "${RANKING_PHRASES[@]}"; do
    assert_not_contains "$target" "$phrase"
  done
done

# 4. The skill carries the canonical algorithm.
for phrase in "${RANKING_PHRASES[@]}"; do
  assert_contains "$SKILL" "$phrase"
done
assert_contains "$SKILL" 'select-fallback-tree.sh'

# 5. The hook delegates to the script (no inline ranking jq).
assert_contains "$HOOK" 'select-fallback-tree.sh'
# The two characteristic field names from the previous inline impl should be
# gone — they were the ranking logic's local variable names.
assert_not_contains "$HOOK" 'compatible_candidates'
assert_not_contains "$HOOK" 'partial_candidates'

echo "fallback algorithm tests passed"
