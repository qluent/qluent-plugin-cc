#!/usr/bin/env bash
# Print this session's qluent rendezvous directory, creating it 0700 first.
#
# This is the prelude every prescribed qluent Bash call starts with:
#
#   QLUENT_DIR=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-dir.sh") || exit 1
#
# It exits non-zero with a reason on stderr rather than printing a path it
# could not make safe, so a caller that checks the status never writes results
# into a directory it does not own.

set -euo pipefail

# shellcheck source=./session-paths.sh
. "$(dirname "${BASH_SOURCE[0]}")/session-paths.sh"

qluent_ensure_session_dir || exit 1
printf '%s\n' "$QLUENT_SESSION_DIR"
