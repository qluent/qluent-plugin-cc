#!/usr/bin/env bash
# Architectural fitness test for protocol locality.
# Enforces the resolution of #45: the qluent-interpretation skill is the deep
# module — protocol rules live there, not restated across commands and agents.
# Callers reference the skill instead of paraphrasing it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/plugins/qluent/skills/qluent-interpretation/SKILL.md"

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
CALLERS=("$ROOT/plugins/qluent/CLAUDE.md")
for caller in "$ROOT"/plugins/qluent/commands/*.md "$ROOT"/plugins/qluent/agents/*.md; do
  case "$(basename "$caller")" in
    setup.md) continue ;;
  esac
  CALLERS+=("$caller")
done

# Canonical phrases that must live ONLY in the skill. Each phrase is the
# distinctive wording of a protocol rule the skill owns.
SKILL_ONLY_PHRASES=(
  'Reuse the exact'
  'Always use `--json-output`'
  'Never parse tool-result temp files'
  'back-calculate'
  'cooperative game theory'
  'Do not rerun both JSON and non-JSON'
  'Confidence scores are evidence-coverage heuristics'
)

# Evidence-label list: the four-label vocabulary belongs in the skill. Callers
# reference the skill — they do not enumerate the labels themselves.
EVIDENCE_LABELS=(
  'observed_correlation'
  'historical_elasticity'
  'model_estimate'
  'experiment_backed'
)

# 1. Skill carries every canonical phrase.
for phrase in "${SKILL_ONLY_PHRASES[@]}"; do
  assert_contains "$SKILL" "$phrase"
done
for label in "${EVIDENCE_LABELS[@]}"; do
  assert_contains "$SKILL" "$label"
done

# 2. No caller restates a canonical phrase.
for caller in "${CALLERS[@]}"; do
  for phrase in "${SKILL_ONLY_PHRASES[@]}"; do
    assert_not_contains "$caller" "$phrase"
  done
  for label in "${EVIDENCE_LABELS[@]}"; do
    assert_not_contains "$caller" "$label"
  done
done

# 3. Every caller names the skill so the pointer is real.
for caller in "${CALLERS[@]}"; do
  assert_contains "$caller" 'qluent-interpretation'
done

# 4. Agents declare the load contract via frontmatter (#32 seam).
for agent_file in "$ROOT"/plugins/qluent/agents/*.md; do
  # Crude but sufficient: the frontmatter line must appear.
  if ! grep -E '^[[:space:]]*-[[:space:]]+qluent-interpretation[[:space:]]*$' "$agent_file" >/dev/null; then
    fail "$agent_file frontmatter must list qluent-interpretation under skills:"
  fi
done

# 5. Slash commands declare the load contract via Step 0 Read (#32 seam).
#    setup.md is intentionally exempt — it predates any analysis flow.
for cmd_file in "$ROOT"/plugins/qluent/commands/*.md; do
  case "$(basename "$cmd_file")" in
    setup.md) continue ;;
  esac
  assert_contains "$cmd_file" 'skills/qluent-interpretation/SKILL.md'
done

echo "protocol locality tests passed"
