#!/usr/bin/env bash
# Canonical declaration of the per-session rendezvous directory and the files
# inside it. Source it; do not execute it. `session-dir.sh` is the executable
# front door for slash commands and agents.
#
# Why a directory and not fixed /tmp paths (#78):
#
#   * Concurrency. The old rendezvous used one fixed file per artifact under
#     /tmp, global to the machine. A second Claude session against a different qluent
#     project deleted and overwrote the first session's cached catalog, so the
#     first session authored plans against the wrong project's vocabulary --
#     either a nonsense `plan_invalid` or, worse, a plan that validates against
#     the wrong catalog. The plan and result files clobbered each other the
#     same way mid-flight.
#
#   * Shared machines. Under /tmp's sticky bit, a file owned by another user
#     cannot be removed or replaced. The old code's `rm -f` failed silently,
#     the write failed too, and the session still announced the catalog as
#     cached -- then read the other user's file.
#
# Scoping by uid fixes the second; scoping by session id fixes the first.
# CLAUDE_CODE_SESSION_ID is set for hooks and for Bash tool calls alike, so
# both sides of the rendezvous derive the same directory independently.

QLUENT_SESSION_DIR="${TMPDIR:-/tmp}/qluent-${UID:-0}-${CLAUDE_CODE_SESSION_ID:-shared}"

QLUENT_CATALOG_FILE="$QLUENT_SESSION_DIR/catalog.json"
QLUENT_PLAN_FILE="$QLUENT_SESSION_DIR/plan.json"
QLUENT_PLAN_RESULT_FILE="$QLUENT_SESSION_DIR/plan-result.json"
QLUENT_QUERY_RESULT_FILE="$QLUENT_SESSION_DIR/query-result.json"
QLUENT_VIZ_DATA_FILE="$QLUENT_SESSION_DIR/viz-data.json"
QLUENT_DEEP_DIVE_FILE="$QLUENT_SESSION_DIR/deep-dive-bundle.json"
QLUENT_TREE_CAPABILITIES_FILE="$QLUENT_SESSION_DIR/tree-capabilities.json"

# Create the session directory 0700, or fail with a reason on stderr.
#
# The ownership check is the point: `mkdir -p` succeeds on a directory someone
# else owns, and every later write then fails one at a time in a way callers
# historically did not check. Refuse up front instead.
qluent_ensure_session_dir() {
  if [ -e "$QLUENT_SESSION_DIR" ] && [ ! -O "$QLUENT_SESSION_DIR" ]; then
    echo "qluent: $QLUENT_SESSION_DIR exists but is owned by another user; refusing to use it" >&2
    return 1
  fi
  if ! mkdir -p "$QLUENT_SESSION_DIR" 2>/dev/null; then
    echo "qluent: could not create $QLUENT_SESSION_DIR" >&2
    return 1
  fi
  if ! chmod 700 "$QLUENT_SESSION_DIR" 2>/dev/null; then
    echo "qluent: could not restrict permissions on $QLUENT_SESSION_DIR" >&2
    return 1
  fi
  if [ ! -d "$QLUENT_SESSION_DIR" ] || [ ! -w "$QLUENT_SESSION_DIR" ]; then
    echo "qluent: $QLUENT_SESSION_DIR is not a writable directory" >&2
    return 1
  fi
  return 0
}
