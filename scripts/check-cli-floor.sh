#!/usr/bin/env bash
# Assert that the CLI version this plugin demands is actually installable.
#
# The plugin depends on the CLI, never the reverse. QLUENT_MIN_CLI_VERSION is
# the one declared point of contact between the two repos, and raising it before
# the matching CLI reaches npm points every user at an upgrade that does not
# exist: the session-start gate fires, tells them to run
# `npm install -g @qluent/cli`, and the newest version npm can give them is
# still too old.
#
# Running this in CI turns "release the CLI first" from a thing you remember
# into a thing the build enforces.
#
# Usage:
#   scripts/check-cli-floor.sh                 Compare against the npm registry.
#   scripts/check-cli-floor.sh <version>       Compare against an explicit
#                                              published version (used by tests).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../plugins/qluent/scripts/cli-requirements.sh
. "$REPO_ROOT/plugins/qluent/scripts/cli-requirements.sh"

published="${1:-}"

if [ -z "$published" ]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "Error: npm is required to look up the published CLI version" >&2
    exit 1
  fi
  published="$(npm view @qluent/cli version 2>/dev/null || true)"
  if [ -z "$published" ]; then
    echo "Error: could not read the published @qluent/cli version from npm" >&2
    exit 1
  fi
fi

if qluent_version_at_least "$published" "$QLUENT_MIN_CLI_VERSION"; then
  printf 'OK: QLUENT_MIN_CLI_VERSION %s is satisfied by published @qluent/cli %s\n' \
    "$QLUENT_MIN_CLI_VERSION" "$published"
  exit 0
fi

command cat >&2 <<MSG
Error: this plugin requires qluent CLI $QLUENT_MIN_CLI_VERSION, but the newest
version published to npm is $published.

Merging this would tell every user to run \`$QLUENT_CLI_UPGRADE_COMMAND\` and
then hand them a CLI that is still too old.

Release qluent-cli $QLUENT_MIN_CLI_VERSION first, then merge this.
MSG
exit 1
