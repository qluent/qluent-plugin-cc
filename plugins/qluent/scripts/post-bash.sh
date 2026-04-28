#!/usr/bin/env bash
# PostToolUse hook for Bash: injects contextual guidance after qluent CLI commands.
# Reminds about available skills, confirms viz data was saved, and nudges
# dimension-aware fallback when a requested cut is unsupported on the tree.

set -euo pipefail

jq_bin=$(command -v jq || true)
[ -n "$jq_bin" ] || exit 0

# Extract the command from TOOL_INPUT (JSON with a "command" field)
command=$(printf '%s' "${TOOL_INPUT:-}" | "$jq_bin" -r '.command // empty' 2>/dev/null) || exit 0
[ -n "$command" ] || exit 0

# Only act on qluent CLI commands
[[ "$command" == *"qluent"* ]] || exit 0

# Detect which type of command was run
is_investigate=false
is_trend=false
is_rca=false
is_compare=false

[[ "$command" == *"investigate"* ]] && is_investigate=true
[[ "$command" == *"trend"* ]] && is_trend=true
[[ "$command" == *"rca"* ]] && is_rca=true
[[ "$command" == *"compare"* ]] && is_compare=true

# Only act on analysis commands (not list, validate, setup, etc.)
if ! $is_investigate && ! $is_trend && ! $is_rca && ! $is_compare; then
  exit 0
fi

viz_file=/tmp/qluent-viz-data.json
catalog_file=/tmp/qluent-tree-capabilities.json

parse_requested_dims_from_command() {
  local command_text="$1"
  local remaining="$command_text"

  while [[ "$remaining" =~ --segment-by[[:space:]]+([^[:space:]|]+) ]]; do
    printf '%s\n' "${BASH_REMATCH[1]}"
    remaining="${remaining#*"${BASH_REMATCH[0]}"}"
  done
}

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

join_by() {
  local delimiter="$1"
  shift || true
  local first=1
  local item
  for item in "$@"; do
    if [ $first -eq 0 ]; then
      printf '%s' "$delimiter"
    fi
    printf '%s' "$item"
    first=0
  done
}

build_fallback_guidance() {
  local command_text="$1"
  local viz_path="$2"
  local catalog_path="$3"

  [ -f "$viz_path" ] || return 0
  "$jq_bin" -e 'type == "object"' "$viz_path" >/dev/null 2>&1 || return 0

  local tree_id tree_label status current_from current_to comparison_from comparison_to
  tree_id=$("$jq_bin" -r '.tree_id // empty' "$viz_path")
  tree_label=$("$jq_bin" -r '.tree_label // empty' "$viz_path")
  status=$("$jq_bin" -r '.agent.status // empty' "$viz_path")
  current_from=$("$jq_bin" -r '.current_window.date_from // empty' "$viz_path")
  current_to=$("$jq_bin" -r '.current_window.date_to // empty' "$viz_path")
  comparison_from=$("$jq_bin" -r '.comparison_window.date_from // empty' "$viz_path")
  comparison_to=$("$jq_bin" -r '.comparison_window.date_to // empty' "$viz_path")

  local -a requested_dims=()
  local -a supported_dims=()
  local -a warning_dims=()
  local -a unsupported_dims=()
  local dim warning

  while IFS= read -r dim; do
    [ -n "$dim" ] && requested_dims+=("$dim")
  done < <("$jq_bin" -r '.segment_by_requested[]? // empty' "$viz_path")

  if [ ${#requested_dims[@]} -eq 0 ]; then
    while IFS= read -r dim; do
      [ -n "$dim" ] && requested_dims+=("$dim")
    done < <(parse_requested_dims_from_command "$command_text")
  fi

  while IFS= read -r dim; do
    [ -n "$dim" ] && supported_dims+=("$dim")
  done < <("$jq_bin" -r '.validation.supported_dimensions[]? // empty' "$viz_path")

  while IFS= read -r warning; do
    if [[ "$warning" =~ Skipped\ segment\ analysis\ for\ dimension\ \'([^\']+)\' ]]; then
      warning_dims+=("${BASH_REMATCH[1]}")
    fi
  done < <("$jq_bin" -r '[.warnings[]?, .root_cause.warnings[]?] | .[]?' "$viz_path")

  if [ ${#requested_dims[@]} -gt 0 ]; then
    for dim in "${requested_dims[@]}"; do
      if ! array_contains "$dim" "${supported_dims[@]+"${supported_dims[@]}"}" && ! array_contains "$dim" "${unsupported_dims[@]+"${unsupported_dims[@]}"}"; then
        unsupported_dims+=("$dim")
      fi
    done
  fi

  if [ ${#warning_dims[@]} -gt 0 ]; then
    for dim in "${warning_dims[@]}"; do
      if ! array_contains "$dim" "${unsupported_dims[@]+"${unsupported_dims[@]}"}"; then
        unsupported_dims+=("$dim")
      fi
    done
  fi

  [ ${#unsupported_dims[@]} -gt 0 ] || return 0

  local window_args=""
  if [ -n "$current_from" ] && [ -n "$current_to" ] && [ -n "$comparison_from" ] && [ -n "$comparison_to" ]; then
    window_args="--current ${current_from}:${current_to} --compare ${comparison_from}:${comparison_to}"
  fi

  local required_json='[]'
  if [ ${#unsupported_dims[@]} -gt 0 ]; then
    required_json=$(printf '%s\n' "${unsupported_dims[@]}" | "$jq_bin" -R . | "$jq_bin" -s .)
  fi

  local -a compatible_candidates=()
  local -a partial_candidates=()
  local line candidate_id candidate_dims

  if [ -f "$catalog_path" ]; then
    while IFS=$'\t' read -r candidate_id candidate_dims; do
      [ -n "$candidate_id" ] && compatible_candidates+=("${candidate_id} (segments: ${candidate_dims})")
    done < <(
      "$jq_bin" -r --arg current "$tree_id" --argjson required "$required_json" '
        .trees[]?
        | select(.id != $current)
        | (.dims // .dimensions // []) as $dims
        | select(($required | all(. as $req | $dims | index($req))))
        | [.id, ($dims | join(", "))] | @tsv
      ' "$catalog_path"
    )

    if [ ${#compatible_candidates[@]} -eq 0 ]; then
      while IFS=$'\t' read -r candidate_id candidate_dims; do
        [ -n "$candidate_id" ] && partial_candidates+=("${candidate_id} (segments: ${candidate_dims})")
      done < <(
        "$jq_bin" -r --arg current "$tree_id" --argjson required "$required_json" '
          [
            .trees[]?
            | select(.id != $current)
            | (.dims // .dimensions // []) as $dims
            | {
                id: .id,
                dims: ($dims | join(", ")),
                overlap: ($required | map(select($dims | index(.))) | length)
              }
            | select(.overlap > 0)
          ]
          | sort_by(-.overlap, .id)[]
          | [.id, .dims] | @tsv
        ' "$catalog_path"
      )
    fi
  fi

  echo "  → Requested segment cuts are unavailable on ${tree_id:-this tree}: $(join_by ', ' "${unsupported_dims[@]}")."
  echo "  → Keep the same windows and pivot to the closest tree that supports the missing cuts. Do not stop at the limitation."

  if [ ${#compatible_candidates[@]} -gt 0 ]; then
    echo "  → Compatible fallback trees from session context: $(join_by ', ' "${compatible_candidates[@]:0:3}")"
    if [ -n "$window_args" ]; then
      line="${compatible_candidates[0]}"
      candidate_id="${line%% *}"
      echo "  → Example next step: qluent trees investigate ${candidate_id} ${window_args} --json-output"
    fi
  elif [ ${#partial_candidates[@]} -gt 0 ]; then
    echo "  → No tree covers every requested cut, but these trees cover part of it: $(join_by ', ' "${partial_candidates[@]:0:3}")"
  else
    echo "  → No compatible fallback tree is cached yet. Run \`qluent trees list --json-output\`, choose a tree exposing those dimensions, and continue with the same windows."
  fi

  echo "  → Synthesize both views: keep the original tree for KPI-specific or category/margin reasoning, and use the fallback tree for the requested segmentation."

  if [ "$status" = "needs_more_data" ] || [ "$status" = "partially_resolved" ]; then
    echo "  → Agent status is ${status}. Continue with the fallback or recommended next steps instead of handing control back."
  fi
}

# Build contextual guidance
echo ""
echo "[Qluent] Analysis complete."

# Viz data reminder
if [[ "$command" == *"--json-output"* ]]; then
  if [ -f "$viz_file" ]; then
    echo "  → Visualization data saved. Use /qluent:visualize to produce a UI RcaReportSpec first; use styled HTML only as a local fallback."
  else
    echo "  → To enable /qluent:visualize, pipe output through: | tee /tmp/qluent-viz-data.json"
  fi
fi

if [[ "$command" == *"--json-output"* ]]; then
  build_fallback_guidance "$command" "$viz_file" "$catalog_file"
fi

# Contextual follow-up suggestions
if $is_investigate; then
  echo "  → Follow-up skills: /qluent:visualize (RcaReportSpec/charts), /qluent:rca (root cause), /qluent:trend (multi-period), /qluent:compare (cross-tree)"
  echo "  → Report options: RCA report, mix-shift report when segment/mix effects exist, or elasticity report for a selected lever/outcome."
fi

if $is_trend || $is_rca || $is_compare; then
  echo "  → Offer /qluent:visualize to shape these results into RcaReportSpec sections, with styled charts as a fallback."
fi
