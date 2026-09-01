#!/usr/bin/env bash
# Report whether the installed plugin is the newest one available.
#
# The plugin is tracked by commit SHA, so "am I current?" is a SHA comparison.
# Nothing surfaces that on its own: a stale install looks identical to a fresh
# one from inside a session. This is what /qluent:setup calls to say so.
#
# Two independent kinds of staleness, each with its own fix:
#
#   remote  -> marketplace clone   `claude plugin marketplace update <mkt>`
#   clone   -> installed copy      `claude plugin update <plugin>@<mkt>`
#
# Usage:
#   plugin-version.sh            Compare installed, clone, and remote.
#   plugin-version.sh --local    Skip the network check against the remote.
#
# Exit codes:
#   0  up to date
#   1  behind — the printed lines say which update to run
#   2  undetermined (not a marketplace install, or the clone is unreadable)

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_ROOT" ]; then
  echo "[Qluent] Cannot determine the plugin version: CLAUDE_PLUGIN_ROOT is unset."
  exit 2
fi

check_remote=1
[ "${1:-}" = "--local" ] && check_remote=0

# .../plugins/cache/<marketplace>/<plugin>/<version>
installed_version="$(basename "$PLUGIN_ROOT")"
plugin_name="$(basename "$(dirname "$PLUGIN_ROOT")")"
marketplace="$(basename "$(dirname "$(dirname "$PLUGIN_ROOT")")")"
cache_dir="$(dirname "$(dirname "$(dirname "$PLUGIN_ROOT")")")"
plugins_dir="$(dirname "$cache_dir")"
clone="$plugins_dir/marketplaces/$marketplace"

if [ "$(basename "$cache_dir")" != "cache" ] || [ ! -d "$clone" ]; then
  echo "[Qluent] Version check skipped (not a marketplace install)."
  exit 2
fi

clone_head="$(git -C "$clone" rev-parse HEAD 2>/dev/null)" || clone_head=""
if [ -z "$clone_head" ]; then
  echo "[Qluent] Version check skipped (marketplace clone unreadable)."
  exit 2
fi

# A SHA-tracked install is named with a short SHA, so compare on that prefix.
# Anything else is a semver left over from when the plugin declared a `version`
# and pinned itself; the marketplace no longer declares one, so such an install
# is stale by definition and cannot be compared by prefix.
behind=0
pinned=0
if [[ "$installed_version" =~ ^[0-9a-f]{7,40}$ ]]; then
  clone_short="${clone_head:0:${#installed_version}}"
else
  pinned=1
  clone_short=""
fi

if [ "$check_remote" = "1" ]; then
  remote_head="$(git -C "$clone" ls-remote origin HEAD 2>/dev/null | awk 'NR==1{print $1}')"
  if [ -n "$remote_head" ] && [ "$remote_head" != "$clone_head" ]; then
    echo "[Qluent] A newer plugin version is available (${remote_head:0:12}; you have $installed_version)."
    echo "[Qluent] Update with: claude plugin marketplace update $marketplace && claude plugin update $plugin_name@$marketplace"
    echo "[Qluent] Then restart Claude Code to apply it."
    behind=1
  fi
fi

if [ "$behind" = "0" ] && [ "$pinned" = "1" ]; then
  echo "[Qluent] Installed version $installed_version predates SHA-based tracking; the marketplace is at ${clone_head:0:12}."
  echo "[Qluent] Update with: claude plugin update $plugin_name@$marketplace"
  echo "[Qluent] Then restart Claude Code to apply it."
  behind=1
elif [ "$behind" = "0" ] && [ "$clone_short" != "$installed_version" ]; then
  echo "[Qluent] The marketplace has ${clone_head:0:12} but $installed_version is installed."
  echo "[Qluent] Update with: claude plugin update $plugin_name@$marketplace"
  echo "[Qluent] Then restart Claude Code to apply it."
  behind=1
fi

if [ "$behind" = "1" ]; then
  exit 1
fi

echo "[Qluent] Plugin $installed_version is up to date."
exit 0
