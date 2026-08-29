#!/usr/bin/env bash
# PreToolUse hook for Bash: auto-approves the command shapes this plugin's
# skills and slash-commands actually prescribe, so a /qluent:query does not
# stop and wait for a permission prompt on every step.
#
# The previous version approved only a *bare* `qluent ...` invocation and fell
# through for anything containing `;`, `|`, `&`, `<`, `>`, a backtick, `$(` or
# a newline. Every command the protocol prescribes contains at least one of
# those, so on a real run it approved 0 of 12 calls (#72) -- in default
# permission mode, twelve stop-and-waits, one of which measured 543 seconds.
#
# Widening the old matcher would have been the wrong fix: a PreToolUse allow
# approves the *entire* Bash command, so "contains a qluent call" must never
# be the test. Instead this script parses the command into lines and approves
# only when EVERY line is one of the prescribed forms below. Anything else --
# an unrecognized line, an unexpected redirect target, an unknown expansion --
# falls through to the normal prompt exactly as before.
#
# Recognized forms (see skills/compose-authoring/SKILL.md and commands/*.md):
#
#   QLUENT_DIR=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-dir.sh") || exit 1
#   set -o pipefail
#   umask 077
#   rm -f "$QLUENT_DIR/<name>.json"
#   qluent <args>
#   qluent <args> > "$QLUENT_DIR/<name>.json"
#   qluent <args> | tee "$QLUENT_DIR/<name>.json"[ >/dev/null]
#   [ -s "$QLUENT_DIR/<name>.json" ] || qluent <args> > "$QLUENT_DIR/<name>.json"
#   jq '<filter>' "$QLUENT_DIR/<name>.json"
#   cat > "$QLUENT_DIR/<name>.json" <<'DELIM' ... DELIM
#   question=$(command cat <<'QLUENT_QUERY' ... QLUENT_QUERY )
#   answer=$(command cat <<'QLUENT_ANSWER' ... QLUENT_ANSWER )
#
# Two properties make this safe to approve wholesale:
#
#   * Redirect and `tee` targets must be a file inside the session workspace
#     (see scripts/session-paths.sh). Nothing can be written anywhere else.
#   * A heredoc body is skipped as data, never parsed as commands, and its
#     delimiter is always quoted -- so the user-controlled question text that
#     the body carries cannot expand or escape. If the body is missing its
#     terminator, the command is rejected rather than partly parsed.
#
# Only `$QLUENT_DIR`, `$question` and `$answer` may appear as expansions, and
# only inside double quotes. No command substitution is permitted anywhere
# except the one exact prelude line above.

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

command_text=$(printf '%s' "$payload" | "$jq_bin" -r '.command // .tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$command_text" ] || exit 0

# A file inside the session workspace, always double-quoted.
SESSION_FILE='"\$QLUENT_DIR/[A-Za-z0-9][A-Za-z0-9._-]*\.json"'

# The prelude runs a script; only three spellings of one script are allowed.
# Claude Code expands ${CLAUDE_PLUGIN_ROOT} when it loads a command file, so
# the model usually emits the absolute path -- which is why the resolved form
# has to be accepted, and why it is compared against this hook's own sibling
# rather than any path that merely ends in the right name.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_DIR_SCRIPT="$SELF_DIR/session-dir.sh"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# True when the argument region of a qluent/jq invocation is free of anything
# that could turn one command into two, and uses only the three expansions the
# protocol prescribes.
args_are_inert() {
  local args="$1"
  case "$args" in
    *';'*|*'|'*|*'&'*|*'<'*|*'>'*|*'`'*|*'$('*|*'${'*) return 1 ;;
  esac
  # Strip the permitted expansions, then reject any `$` that is left.
  local stripped="${args//\$QLUENT_DIR/}"
  stripped="${stripped//\$question/}"
  stripped="${stripped//\$answer/}"
  case "$stripped" in
    *'$'*) return 1 ;;
  esac
  return 0
}

# True for `qluent ...`, optionally ending in a redirect or tee into the
# session workspace.
is_qluent_line() {
  local line="$1"
  local args="$line"

  if [[ "$args" =~ ^(.*)\ \|\ tee\ ($SESSION_FILE)(\ \>/dev/null)?$ ]]; then
    args="${BASH_REMATCH[1]}"
  elif [[ "$args" =~ ^(.*)\ \>\ ($SESSION_FILE)$ ]]; then
    args="${BASH_REMATCH[1]}"
  fi

  case "$args" in
    qluent|'qluent '*) ;;
    *) return 1 ;;
  esac
  args_are_inert "$args"
}

# True for `jq '<filter>' "$QLUENT_DIR/<name>.json"` -- a read of our own file.
is_jq_line() {
  local line="$1"
  [[ "$line" =~ ^jq\ \'[^\']*\'\ $SESSION_FILE$ ]]
}

decision=""
saw_qluent_work=false

mapfile -t lines <<< "$command_text"
total=${#lines[@]}
index=0

while [ "$index" -lt "$total" ]; do
  line=$(trim "${lines[$index]}")
  index=$((index + 1))

  # Blank lines are noise between prescribed steps.
  [ -n "$line" ] || continue

  # The one permitted command substitution: resolving the session workspace.
  if [[ "$line" =~ ^QLUENT_DIR=\$\(bash\ \"(.+)\"\)\ \|\|\ exit\ 1$ ]]; then
    case "${BASH_REMATCH[1]}" in
      '${CLAUDE_PLUGIN_ROOT}/scripts/session-dir.sh') continue ;;
      '$CLAUDE_PLUGIN_ROOT/scripts/session-dir.sh') continue ;;
      "$SESSION_DIR_SCRIPT") continue ;;
      *) exit 0 ;;
    esac
  fi

  if [ "$line" = "set -o pipefail" ] || [ "$line" = "umask 077" ]; then
    continue
  fi

  if [[ "$line" =~ ^rm\ -f\ $SESSION_FILE$ ]]; then
    continue
  fi

  # `[ -s <file> ] || qluent ...` -- the cached-catalog guard.
  if [[ "$line" =~ ^\[\ -s\ $SESSION_FILE\ \]\ \|\|\ (.*)$ ]]; then
    line=$(trim "${BASH_REMATCH[1]}")
  fi

  # `question=$(command cat <<'DELIM'` / `answer=$(...)`: consume the quoted
  # heredoc body as data, then require the closing paren on its own line.
  if [[ "$line" =~ ^(question|answer)=\$\(command\ cat\ \<\<\'([A-Z_]+)\'$ ]]; then
    delimiter="${BASH_REMATCH[2]}"
    found=false
    while [ "$index" -lt "$total" ]; do
      body_line="${lines[$index]}"
      index=$((index + 1))
      if [ "$body_line" = "$delimiter" ]; then
        found=true
        break
      fi
    done
    $found || exit 0
    [ "$index" -lt "$total" ] || exit 0
    [ "$(trim "${lines[$index]}")" = ")" ] || exit 0
    index=$((index + 1))
    continue
  fi

  # `cat > <file> <<'DELIM'`: the plan document, written as inert data.
  if [[ "$line" =~ ^cat\ \>\ $SESSION_FILE\ \<\<\'([A-Z_]+)\'$ ]]; then
    delimiter="${BASH_REMATCH[1]}"
    found=false
    while [ "$index" -lt "$total" ]; do
      body_line="${lines[$index]}"
      index=$((index + 1))
      if [ "$body_line" = "$delimiter" ]; then
        found=true
        break
      fi
    done
    $found || exit 0
    saw_qluent_work=true
    continue
  fi

  if is_qluent_line "$line"; then
    saw_qluent_work=true
    continue
  fi

  if is_jq_line "$line"; then
    saw_qluent_work=true
    continue
  fi

  # Anything else: fall through to the normal permission prompt.
  exit 0
done

$saw_qluent_work || exit 0

decision='{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "qluent plugin command shape auto-approved by the qluent plugin"}}'
printf '%s\n' "$decision"
exit 0
