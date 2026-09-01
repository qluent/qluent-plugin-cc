#!/usr/bin/env bash
# Contract tests for the plugin staleness check.
#
# The plugin is tracked by commit SHA, so a months-old install and a current
# one are indistinguishable from inside a session: no banner, no error, just
# behavior that predates every fix since. This is not hypothetical — an install
# sat 21 commits behind for two months without a single symptom. These tests
# pin the check that surfaces it, and the setup command that runs it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/plugins/qluent/scripts/plugin-version.sh"
SETUP="$ROOT/plugins/qluent/commands/setup.md"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1" needle="$2"
  grep -qF -- "$needle" "$file" || fail "$(basename "$file") is missing: $needle"
}

# A throwaway marketplace layout: a git clone plus a cache directory named the
# way Claude Code names one, so the script's path derivation is exercised for
# real rather than mocked.
make_fixture() {
  local installed="$1" head_sha_out="$2"
  local tmp
  tmp="$(mktemp -d)"
  local clone="$tmp/marketplaces/qluent-metric-trees"
  mkdir -p "$clone" "$tmp/cache/qluent-metric-trees/qluent/$installed"
  git -C "$clone" init -q
  git -C "$clone" config user.email t@t
  git -C "$clone" config user.name t
  echo x > "$clone/f"
  git -C "$clone" add f
  git -C "$clone" commit -qm c
  printf '%s' "$(git -C "$clone" rev-parse HEAD)" > "$head_sha_out"
  printf '%s' "$tmp"
}

run() {
  CLAUDE_PLUGIN_ROOT="$1" bash "$SCRIPT" --local 2>&1
}
run_status() {
  CLAUDE_PLUGIN_ROOT="$1" bash "$SCRIPT" --local >/dev/null 2>&1
  echo $?
}

# 1. An install matching the marketplace clone reports up to date.
head_file="$(mktemp)"
root="$(make_fixture placeholder "$head_file")"
head_sha="$(cat "$head_file")"
short="${head_sha:0:12}"
mv "$root/cache/qluent-metric-trees/qluent/placeholder" \
   "$root/cache/qluent-metric-trees/qluent/$short"
current="$root/cache/qluent-metric-trees/qluent/$short"
[ "$(run_status "$current")" = "0" ] || fail "matching SHA should exit 0"
run "$current" | grep -q "up to date" || fail "matching SHA should report up to date"

# 2. An install behind the clone reports the drift and the fix.
stale="$root/cache/qluent-metric-trees/qluent/000000000000"
mkdir -p "$stale"
[ "$(run_status "$stale")" = "1" ] || fail "stale SHA should exit 1"
out="$(run "$stale")" || true
grep -q "$short" <<<"$out" || fail "drift report should name the available version"
grep -q "claude plugin update qluent@qluent-metric-trees" <<<"$out" \
  || fail "drift report should give the update command"
grep -qi "restart" <<<"$out" || fail "drift report should mention the restart"

# 3. A semver install predates SHA tracking and is stale by definition. It must
#    not be prefix-compared, which would print a truncated nonsense SHA.
pinned="$root/cache/qluent-metric-trees/qluent/0.4.3"
mkdir -p "$pinned"
[ "$(run_status "$pinned")" = "1" ] || fail "pinned semver should exit 1"
out="$(run "$pinned")" || true
grep -q "predates SHA-based tracking" <<<"$out" || fail "pinned semver needs its own message"
grep -q "${head_sha:0:12}" <<<"$out" || fail "pinned semver report should name the full short SHA"

# 4. A local checkout is not a failure — it is how the plugin is developed.
[ "$(run_status "/tmp/not/a/marketplace/install")" = "2" ] || fail "non-marketplace should exit 2"
out="$(run "/tmp/not/a/marketplace/install")" || true
grep -q "skipped" <<<"$out" || fail "non-marketplace should say skipped"

# 5. No CLAUDE_PLUGIN_ROOT is undetermined, not a crash.
status=0
(env -u CLAUDE_PLUGIN_ROOT bash "$SCRIPT" >/dev/null 2>&1) || status=$?
[ "$status" = "2" ] || fail "unset CLAUDE_PLUGIN_ROOT should exit 2, got $status"

rm -rf "$root" "$head_file"

# 6. /qluent:setup runs the check and can execute it.
assert_contains "$SETUP" 'scripts/plugin-version.sh'
assert_contains "$SETUP" 'Bash(bash *)'
assert_contains "$SETUP" 'Plugin version:'

echo "plugin version gate tests passed"
