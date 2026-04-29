#!/usr/bin/env bash
# Select the closest companion tree when the requested segment cuts are not
# supported on the current tree. This is the single source of truth for the
# unsupported-cut fallback ranking; the post-bash hook calls it to surface
# nudges, and the skill (qluent-interpretation) names it as the canonical
# implementation.
#
# Usage:
#   select-fallback-tree.sh <catalog_path> <current_tree_id> <required_dims_csv>
#
# Output (single TSV line on stdout):
#   <tree_id>\t<reason>\t<comma_separated_dims>
#
# Reasons:
#   full_coverage   — chosen tree exposes every requested dimension
#   partial_overlap — chosen tree exposes a subset (best available)
#   none            — no other tree exposes any of the requested dimensions
#                     (or the catalog is missing/unreadable)
#
# Ranking (matches the skill's documented algorithm):
#   1. Full coverage wins.
#   2. Most overlapping dimensions wins.
#   3. Tiebreak: same root-metric family as the current tree.
#   4. Final tiebreak: alphabetical tree id.

set -euo pipefail

if [ $# -lt 3 ]; then
  echo "usage: $0 <catalog_path> <current_tree_id> <required_dims_csv>" >&2
  exit 2
fi

catalog_path="$1"
current_tree="$2"
required_csv="$3"

jq_bin=$(command -v jq || true)
if [ -z "$jq_bin" ]; then
  echo "select-fallback-tree.sh requires jq" >&2
  exit 2
fi

if [ ! -f "$catalog_path" ]; then
  printf '\tnone\t\n'
  exit 0
fi

required_json=$(printf '%s' "$required_csv" | "$jq_bin" -R 'split(",") | map(select(length > 0))')

current_root=$("$jq_bin" -r --arg id "$current_tree" '
  .trees[]? | select(.id == $id) | (.root // .root_metric // "")
' "$catalog_path" | head -n 1)

"$jq_bin" -r \
  --arg current "$current_tree" \
  --arg current_root "$current_root" \
  --argjson required "$required_json" '
  ($required | length) as $needed
  | [
      .trees[]?
      | select(.id != $current)
      | (.dims // .dimensions // []) as $dims
      | (.root // .root_metric // "") as $root
      | ($required | map(select(IN($dims[]))) | length) as $overlap
      | select($overlap > 0)
      | {
          id: .id,
          dims: ($dims | join(",")),
          overlap: $overlap,
          full: ($overlap == $needed),
          family: ($root == $current_root and $current_root != "")
        }
    ]
  | sort_by([
      -(.full | if . then 1 else 0 end),
      -.overlap,
      -(.family | if . then 1 else 0 end),
      .id
    ])
  | if length == 0 then
      "\tnone\t"
    else
      .[0] as $best
      | "\($best.id)\t\(if $best.full then "full_coverage" else "partial_overlap" end)\t\($best.dims)"
    end
' "$catalog_path"
