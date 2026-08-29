#!/usr/bin/env bash
# Canonical declaration of the qluent CLI version this plugin needs, plus the
# helpers for reading and comparing it. Source it; do not execute it.
#
# `qluent plan` and `qluent catalog` — the whole composed-plan path — first
# shipped in CLI 0.1.18. On anything older the compose path does not exist,
# and every question silently falls through to the NL workflow that the plugin
# itself warns "can take several minutes". This file is what turns that silence
# into a diagnostic.
#
# One declaration, referenced everywhere: tests/test_cli_version_gate.sh pins
# the number appearing in commands/setup.md and README.md to this value.

# The minimum CLI version that supports composed plans.
QLUENT_MIN_CLI_VERSION="0.1.18"

# The command that installs or upgrades it.
QLUENT_CLI_UPGRADE_COMMAND="npm install -g @qluent/cli"

# Print the installed CLI's version (bare "X.Y.Z"), or nothing when it cannot
# be determined — a CLI too old to support `--version`, or one that fails.
qluent_cli_version() {
  local raw
  raw=$(qluent --version 2>/dev/null) || return 1
  # `qluent, version 0.1.18` -> `0.1.18`. Any leading noise is ignored.
  raw=$(printf '%s' "$raw" | tr -d '\r' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
  [ -n "$raw" ] || return 1
  printf '%s' "$raw"
}

# Return 0 when version $1 is at least version $2. Pure bash on purpose:
# `sort -V` is not portable to every macOS the plugin runs on.
#
# A prerelease suffix is ignored rather than ordered below its release: the
# question here is "does this build have `qluent plan`", and 0.1.18-rc1 does.
qluent_version_at_least() {
  local have="$1" want="$2" i have_part want_part
  local -a have_parts want_parts
  IFS='.' read -r -a have_parts <<< "${have%%-*}"
  IFS='.' read -r -a want_parts <<< "${want%%-*}"
  for i in 0 1 2; do
    have_part=${have_parts[i]:-0}
    want_part=${want_parts[i]:-0}
    # Strip anything non-numeric so a build suffix cannot break the compare.
    have_part=${have_part//[!0-9]/}
    want_part=${want_part//[!0-9]/}
    have_part=$((10#${have_part:-0}))
    want_part=$((10#${want_part:-0}))
    if [ "$have_part" -gt "$want_part" ]; then return 0; fi
    if [ "$have_part" -lt "$want_part" ]; then return 1; fi
  done
  return 0
}

# Print the one-line notice for a CLI that is installed but too old.
qluent_outdated_cli_notice() {
  local found="$1"
  printf '[Qluent] qluent CLI %s detected; composed plans need %s+. Run `%s`.\n' \
    "$found" "$QLUENT_MIN_CLI_VERSION" "$QLUENT_CLI_UPGRADE_COMMAND"
  printf 'Until then every question falls back to the slower natural-language workflow.\n'
}
