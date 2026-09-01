#!/usr/bin/env bash
# Architectural fitness test for protocol locality.
# Enforces the resolution of #45: the protocol skills are the deep modules —
# protocol rules live there, not restated across commands and agents. Callers
# reference a skill instead of paraphrasing it.
#
# #102 split that deep module in two, by audience:
#   qluent-interpretation  → the core every workflow loads (routing,
#                            provenance, grounding, session workspace).
#   qluent-tree-protocol   → the metric-tree half, loaded only by the tree
#                            commands and agents. /qluent:query must not load
#                            it: a "GMV by market last month" question never
#                            touches Shapley, elasticity or tree resolution.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/plugins/qluent/skills/qluent-interpretation/SKILL.md"
TREE_SKILL="$ROOT/plugins/qluent/skills/qluent-tree-protocol/SKILL.md"
QUERY_CMD="$ROOT/plugins/qluent/commands/query.md"

# Commands and agents that drive a metric tree, and so load both modules.
TREE_CALLERS=(
  "$ROOT/plugins/qluent/commands/investigate.md"
  "$ROOT/plugins/qluent/commands/deep-dive.md"
  "$ROOT/plugins/qluent/commands/visualize.md"
)
for agent_file in "$ROOT"/plugins/qluent/agents/*.md; do
  TREE_CALLERS+=("$agent_file")
done

fail() {
  echo "FAIL: $*" >&2
  exit 1
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
    fail "$file should not contain (lives only in the skill): $needle"
  fi
}

# Files that must defer to the skill instead of restating it.
CALLERS=("$ROOT/plugins/qluent/skills/qluent-orientation/SKILL.md")
for caller in "$ROOT"/plugins/qluent/commands/*.md "$ROOT"/plugins/qluent/agents/*.md; do
  case "$(basename "$caller")" in
    setup.md) continue ;;
  esac
  CALLERS+=("$caller")
done

# Canonical phrases that must live ONLY in the core skill. Each phrase is the
# distinctive wording of a protocol rule that skill owns.
CORE_ONLY_PHRASES=(
  'Always use `--json-output`'
  'Never parse tool-result temp files'
  'back-calculate'
  'Do not rerun both JSON and non-JSON'
  'Do not require a tree before answering a data question'
)

# The same, for the metric-tree module.
TREE_ONLY_PHRASES=(
  'Reuse the exact'
  'cooperative game theory'
  'Confidence scores are evidence-coverage heuristics'
)

# Evidence-label list: the four-label vocabulary is tree-lever material and
# belongs in the tree module. Callers reference it — they do not enumerate the
# labels themselves.
EVIDENCE_LABELS=(
  'observed_correlation'
  'historical_elasticity'
  'model_estimate'
  'experiment_backed'
)

# 1. Each skill carries its own canonical phrases, and neither carries the
#    other's — a phrase in both files is one rule with two homes.
for phrase in "${CORE_ONLY_PHRASES[@]}"; do
  assert_contains "$SKILL" "$phrase"
  assert_not_contains "$TREE_SKILL" "$phrase"
done
for phrase in "${TREE_ONLY_PHRASES[@]}"; do
  assert_contains "$TREE_SKILL" "$phrase"
  assert_not_contains "$SKILL" "$phrase"
done
for label in "${EVIDENCE_LABELS[@]}"; do
  assert_contains "$TREE_SKILL" "$label"
  assert_not_contains "$SKILL" "$label"
done

# 2. No caller restates a canonical phrase.
for caller in "${CALLERS[@]}"; do
  for phrase in "${CORE_ONLY_PHRASES[@]}" "${TREE_ONLY_PHRASES[@]}"; do
    assert_not_contains "$caller" "$phrase"
  done
  for label in "${EVIDENCE_LABELS[@]}"; do
    assert_not_contains "$caller" "$label"
  done
done

# 3. Every caller names the core skill, and every tree caller also names the
#    tree module, so each pointer is real.
for caller in "${CALLERS[@]}"; do
  assert_contains "$caller" 'qluent-interpretation'
done
for caller in "${TREE_CALLERS[@]}"; do
  assert_contains "$caller" 'qluent-tree-protocol'
done

# 4. Agents declare the load contract via frontmatter (#32 seam). Every agent
#    drives a tree, so every agent declares both modules.
for agent_file in "$ROOT"/plugins/qluent/agents/*.md; do
  # Crude but sufficient: the frontmatter line must appear.
  for skill_name in qluent-interpretation qluent-tree-protocol; do
    if ! grep -E "^[[:space:]]*-[[:space:]]+$skill_name[[:space:]]*\$" "$agent_file" >/dev/null; then
      fail "$agent_file frontmatter must list $skill_name under skills:"
    fi
  done
done

# 5. Slash commands declare the load contract via Step 0 Read (#32 seam).
#    setup.md is intentionally exempt — it predates any analysis flow.
for cmd_file in "$ROOT"/plugins/qluent/commands/*.md; do
  case "$(basename "$cmd_file")" in
    setup.md) continue ;;
  esac
  assert_contains "$cmd_file" 'skills/qluent-interpretation/SKILL.md'
done

# 5b. The tree commands load the tree module; /qluent:query must not (#102).
#     This is the whole point of the split: the query path stops paying for
#     tree protocol it never reads.
for cmd_file in "$ROOT"/plugins/qluent/commands/investigate.md \
                "$ROOT"/plugins/qluent/commands/deep-dive.md \
                "$ROOT"/plugins/qluent/commands/visualize.md; do
  assert_contains "$cmd_file" 'skills/qluent-tree-protocol/SKILL.md'
done
assert_not_contains "$QUERY_CMD" 'skills/qluent-tree-protocol/SKILL.md'

# 6. Compose-path invocations live only in the compose-authoring skill (#77).
#    Two copies of one command are two protocols: the divergent jq projections
#    in commands/query.md and compose-authoring/SKILL.md disagreed about what
#    vocabulary the plan author gets to see. `scripts/session-start.sh` is the
#    one other legitimate producer -- it caches the catalog before any command
#    runs -- and the qluent-interpretation skill names the paths without
#    prescribing the commands.
COMPOSE_SKILL="$ROOT/plugins/qluent/skills/compose-authoring/SKILL.md"

# invocation => the exact set of files allowed to spell it out. The skill owns
# every one; session-start.sh additionally caches the catalog before any
# command runs, which is why it produces the catalog fetch itself.
check_invocation_locality() {
  local invocation="$1"
  shift
  assert_contains "$COMPOSE_SKILL" "$invocation"

  local expected
  expected=$(printf '%s\n' "$@" | sort)
  local actual
  actual=$(grep -rlF --include='*.md' --include='*.sh' -e "$invocation" \
      "$ROOT/plugins" 2>/dev/null \
    | while read -r f; do echo "${f#$ROOT/}"; done \
    | sort)

  if [ "$actual" != "$expected" ]; then
    echo "FAIL: '$invocation' is restated outside the compose-authoring skill" >&2
    echo "  Expected:" >&2
    printf '    %s\n' $expected >&2
    echo "  Actual:" >&2
    printf '    %s\n' $actual >&2
    echo "  Reference the skill by name instead of restating its commands." >&2
    exit 1
  fi
}

check_invocation_locality 'qluent catalog --json-output' \
  'plugins/qluent/skills/compose-authoring/SKILL.md' \
  'plugins/qluent/scripts/session-start.sh'

check_invocation_locality 'qluent plan --file' \
  'plugins/qluent/skills/compose-authoring/SKILL.md'

# 7. Callers of the compose path name the skill that owns it.
for caller in "$ROOT/plugins/qluent/commands/query.md" "$ROOT/plugins/qluent/agents/qluent-analyst.md"; do
  assert_contains "$caller" 'compose-authoring'
done

echo "protocol locality tests passed"
