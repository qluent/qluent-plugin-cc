#!/usr/bin/env bash
# Contract tests for the minimum-CLI-version gate (#75).
#
# `qluent plan` and `qluent catalog` first shipped in CLI 0.1.18. Below that
# the compose path does not exist, and the plugin used to skip it in silence
# while the session banner and CLAUDE.md kept advertising composed plans as
# the default. These tests pin the single declaration, the surfaces that quote
# it, the comparison itself, and the session-start behavior on each side of
# the boundary.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUIREMENTS="$ROOT/plugins/qluent/scripts/cli-requirements.sh"
SESSION_START="$ROOT/plugins/qluent/scripts/session-start.sh"
SETUP="$ROOT/plugins/qluent/commands/setup.md"
README="$ROOT/README.md"

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

# 1. One canonical declaration.
[ -f "$REQUIREMENTS" ] || fail "scripts/cli-requirements.sh is missing"
# shellcheck source=../plugins/qluent/scripts/cli-requirements.sh
. "$REQUIREMENTS"
[ -n "${QLUENT_MIN_CLI_VERSION:-}" ] || fail "QLUENT_MIN_CLI_VERSION is not declared"
[ -n "${QLUENT_CLI_UPGRADE_COMMAND:-}" ] || fail "QLUENT_CLI_UPGRADE_COMMAND is not declared"

# 2. Every surface that quotes the number quotes the declared one. A stale
#    number in the docs is the same failure this issue is about, one level up.
assert_contains "$SETUP" "$QLUENT_MIN_CLI_VERSION"
assert_contains "$SETUP" "$QLUENT_CLI_UPGRADE_COMMAND"
assert_contains "$README" "$QLUENT_MIN_CLI_VERSION"
assert_contains "$SESSION_START" 'cli-requirements.sh'

# 3. The comparison itself. Pure bash, so these are the real edge cases:
#    a same-length compare, a shorter/longer compare, and the double-digit
#    component that a lexical compare gets wrong.
version_at_least_cases=(
  "0.1.18 0.1.18 yes"
  "0.1.19 0.1.18 yes"
  "0.2.0  0.1.18 yes"
  "1.0.0  0.1.18 yes"
  "0.1.17 0.1.18 no"
  "0.1.9  0.1.18 no"
  "0.0.99 0.1.18 no"
  "0.1    0.1.18 no"
  "0.2    0.1.18 yes"
  "0.1.20 0.1.9  yes"
  # A prerelease of the minimum counts as having the feature -- see the note
  # in cli-requirements.sh.
  "0.1.18-rc1 0.1.18 yes"
)
for case_line in "${version_at_least_cases[@]}"; do
  # shellcheck disable=SC2086
  set -- $case_line
  have="$1"; want="$2"; expected="$3"
  if qluent_version_at_least "$have" "$want"; then
    actual=yes
  else
    actual=no
  fi
  [ "$actual" = "$expected" ] || \
    fail "qluent_version_at_least $have $want returned $actual, expected $expected"
done

# 4. Session-start behavior on both sides of the boundary.
tmpdir="$(mktemp -d)"
catalog_file="/tmp/qluent-catalog.json"

restore() {
  rm -f "$catalog_file"
  if [ -f "$tmpdir/catalog.bak" ]; then
    cp "$tmpdir/catalog.bak" "$catalog_file"
  fi
  rm -rf "$tmpdir"
}
if [ -f "$catalog_file" ]; then
  cp "$catalog_file" "$tmpdir/catalog.bak"
fi
trap restore EXIT

# A fake CLI whose version is whatever QLUENT_FAKE_VERSION says. It supports
# `plan`/`catalog` regardless, so a passing test proves the *version* gate
# fired rather than the subcommand probe.
mkdir -p "$tmpdir/bin"
cat > "$tmpdir/bin/qluent" <<'SH'
#!/usr/bin/env bash
case "$1 ${2:-}" in
  "trees list") printf '{"trees":[]}'; exit 0 ;;
  "--version ") ;&
  "--version") 
    if [ -z "${QLUENT_FAKE_VERSION:-}" ]; then exit 2; fi
    printf 'qluent, version %s\n' "$QLUENT_FAKE_VERSION"; exit 0 ;;
  "plan --help") exit 0 ;;
  "catalog --json-output") printf '{"catalog":{"bases":{"b":{}},"metrics":{}}}'; exit 0 ;;
esac
exit 1
SH
chmod +x "$tmpdir/bin/qluent"

# 4a. Below the minimum: a notice, and no catalog claimed.
rm -f "$catalog_file"
out=$(PATH="$tmpdir/bin:$PATH" QLUENT_FAKE_VERSION=0.1.15 bash "$SESSION_START")
assert_output_contains "$out" '0.1.15'
assert_output_contains "$out" "composed plans need $QLUENT_MIN_CLI_VERSION+"
assert_output_contains "$out" "$QLUENT_CLI_UPGRADE_COMMAND"
assert_output_not_contains "$out" 'Query catalog available'
[ ! -e "$catalog_file" ] || fail "no catalog should be cached below the minimum CLI version"

# 4b. At the minimum: no notice, catalog cached as before.
rm -f "$catalog_file"
out=$(PATH="$tmpdir/bin:$PATH" QLUENT_FAKE_VERSION="$QLUENT_MIN_CLI_VERSION" bash "$SESSION_START")
assert_output_not_contains "$out" 'composed plans need'
assert_output_contains "$out" 'Query catalog available'
[ -s "$catalog_file" ] || fail "the catalog should still be cached at the minimum CLI version"

# 4c. Above the minimum: unchanged.
rm -f "$catalog_file"
out=$(PATH="$tmpdir/bin:$PATH" QLUENT_FAKE_VERSION=1.2.3 bash "$SESSION_START")
assert_output_not_contains "$out" 'composed plans need'
assert_output_contains "$out" 'Query catalog available'

# 4d. `--version` unsupported (a CLI older than the flag): fall back to the
#     subcommand probe rather than blocking the compose path on an unreadable
#     version.
rm -f "$catalog_file"
out=$(PATH="$tmpdir/bin:$PATH" bash "$SESSION_START")
assert_output_not_contains "$out" 'composed plans need'
assert_output_contains "$out" 'Query catalog available'

echo "cli version gate tests passed"
