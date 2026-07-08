#!/usr/bin/env bash
# PreToolUse hook for Bash: auto-approves `qluent` CLI commands so the plugin's
# skills and slash-commands never prompt for permission on each query.
#
# Safety: this emits an "allow" permission decision only for a *single* qluent
# invocation. A PreToolUse allow approves the entire Bash command, so anything
# that chains, pipes, redirects, or substitutes (`;`, `|`, `&`, `<`, `>`, `` ` ``,
# `$(...)`, newlines) is deliberately NOT auto-approved — those fall through to
# the normal permission prompt, exactly like the `Bash(qluent:*)` allow rule.
# The match lives in this script (not just the hook's `if` filter) so it stays
# safe on Claude Code versions that predate `if`.

set -euo pipefail

jq_bin=$(command -v jq || true)
[ -n "$jq_bin" ] || exit 0

# Tool input arrives via the TOOL_INPUT env var (harness convention used by the
# sibling hooks); fall back to stdin for robustness.
payload="${TOOL_INPUT:-}"
if [ -z "$payload" ]; then
  payload=$(cat 2>/dev/null || true)
fi
[ -n "$payload" ] || exit 0

command=$(printf '%s' "$payload" | "$jq_bin" -r '.command // .tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$command" ] || exit 0

# Trim leading whitespace.
command="${command#"${command%%[![:space:]]*}"}"

# Fall through to the normal prompt if the command chains / pipes / redirects /
# substitutes — never blanket-approve a piggy-backed command.
if [[ "$command" == *';'* || "$command" == *'|'* || "$command" == *'&'* \
   || "$command" == *'<'* || "$command" == *'>'* || "$command" == *'`'* \
   || "$command" == *'$('* || "$command" == *$'\n'* ]]; then
  exit 0
fi

# Auto-approve only when the command is a bare qluent invocation.
case "$command" in
  qluent | "qluent "*)
    printf '%s\n' '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "qluent CLI command auto-approved by the qluent plugin"}}'
    ;;
esac

exit 0
