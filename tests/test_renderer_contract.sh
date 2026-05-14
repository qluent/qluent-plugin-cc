#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
    fail "$file should not contain: $needle"
  fi
}

assert_contains "$ROOT/plugins/qluent/commands/investigate.md" \
  '--json-output | tee /tmp/qluent-viz-data.json'
assert_not_contains "$ROOT/plugins/qluent/commands/investigate.md" \
  '--json-output 2>&1 | tee /tmp/qluent-viz-data.json'
assert_contains "$ROOT/plugins/qluent/commands/deep-dive.md" \
  '--json-output --period "<period>" | tee /tmp/qluent-deep-dive-bundle.json'
assert_not_contains "$ROOT/plugins/qluent/commands/deep-dive.md" \
  '--json-output --period "<period>" 2>&1 | tee /tmp/qluent-deep-dive-bundle.json'

assert_contains "$ROOT/plugins/qluent/agents/qluent-analyst.md" \
  '--json-output | tee /tmp/qluent-viz-data.json'
assert_not_contains "$ROOT/plugins/qluent/agents/qluent-analyst.md" \
  '--json-output 2>&1 | tee /tmp/qluent-viz-data.json'

assert_contains "$ROOT/plugins/qluent/templates/render-charts.html" \
  'const rootNode = getRootNode(qdata);'
assert_contains "$ROOT/plugins/qluent/templates/render-charts.html" \
  'const contributors = getRootContributors(qdata);'
assert_contains "$ROOT/plugins/qluent/templates/render-charts.html" \
  'const present = rc.conclusion?.evidence_types_present || rc.evidence_types_present || [];'
assert_not_contains "$ROOT/plugins/qluent/templates/render-charts.html" \
  'qdata.root_cause?.top_contributors || []'
# Guard against NaN% when a contributor has no delta_share (e.g. takeaway fallback)
assert_contains "$ROOT/plugins/qluent/templates/render-charts.html" \
  'c.delta_share != null'
assert_contains "$ROOT/plugins/qluent/templates/render-charts.html" \
  'function isDeepDiveBundle(data)'
assert_contains "$ROOT/plugins/qluent/templates/render-charts.html" \
  'Cross-tree Root Movement'
assert_contains "$ROOT/plugins/qluent/commands/visualize.md" \
  "outcomeShape: 'driver_concentration' | 'mix_shift' | 'elasticity_tradeoff' | 'data_quality_blocker' | 'cross_tree_bundle' | string"
assert_contains "$ROOT/plugins/qluent/commands/visualize.md" \
  'cross_tree_hotspot_grid'
assert_contains "$ROOT/plugins/qluent/commands/visualize.md" \
  '**Insight-driven HTML mode**'
assert_contains "$ROOT/plugins/qluent/commands/visualize.md" \
  '${CLAUDE_PLUGIN_ROOT}/skills/dashboard-design/SKILL.md'
assert_contains "$ROOT/plugins/qluent/commands/visualize.md" \
  'Suggested single-tree section order'
assert_contains "$ROOT/plugins/qluent/commands/visualize.md" \
  'Use `render-charts.sh` only for `--simple` generic fallback output.'

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

valid_json="$tmpdir/investigate.json"
contaminated_json="$tmpdir/contaminated.json"
html="$tmpdir/out.html"

cat > "$valid_json" <<'JSON'
{
  "tree_id": "revenue",
  "tree_label": "Revenue & Commercial",
  "period_label": "Mar vs Feb",
  "current_window": {"date_from": "2026-03-01", "date_to": "2026-03-31"},
  "comparison_window": {"date_from": "2026-02-01", "date_to": "2026-02-28"},
  "evaluation": {
    "nodes": [
      {
        "id": "net_revenue",
        "label": "Net Revenue",
        "parent_id": null,
        "current_value": 39090016.17,
        "comparison_value": 31475112.41,
        "delta_value": 7614903.76,
        "delta_ratio": 0.2419,
        "contributions": [
          {"node_id": "gross_revenue", "label": "Gross Revenue", "delta_value": 7615633.11, "delta_share": 1.0001}
        ]
      },
      {
        "id": "gross_revenue",
        "label": "Gross Revenue",
        "parent_id": "net_revenue",
        "current_value": 39093738.73,
        "comparison_value": 31478105.62,
        "delta_value": 7615633.11,
        "delta_ratio": 0.2419
      }
    ],
    "top_contributors": [
      {"node_id": "gross_revenue", "label": "Gross Revenue", "delta_value": 7615633.11, "delta_share": 1.0001}
    ]
  },
  "root_cause": {
    "conclusion": {
      "confidence_score": 0.9,
      "evidence_types_present": ["driver", "time_slice"],
      "evidence_types_missing": [],
      "takeaways": [
        {"kind": "driver", "title": "Gross Revenue", "summary": "Gross Revenue contributed +$7.62M"}
      ]
    }
  }
}
JSON

"$ROOT/plugins/qluent/scripts/render-charts.sh" "$valid_json" "$html" >/dev/null
assert_contains "$html" '"label": "Net Revenue"'
assert_contains "$html" 'getRootNode(qdata)'
assert_contains "$html" 'getRootContributors(qdata)'

takeaway_only_json="$tmpdir/takeaway_only.json"
takeaway_html="$tmpdir/takeaway.html"

cat > "$takeaway_only_json" <<'JSON'
{
  "tree_id": "revenue",
  "tree_label": "Revenue & Commercial",
  "evaluation": {
    "nodes": [
      {
        "id": "net_revenue",
        "label": "Net Revenue",
        "parent_id": null,
        "current_value": 100,
        "delta_value": 10,
        "delta_ratio": 0.1
      }
    ]
  },
  "root_cause": {
    "conclusion": {
      "takeaways": [
        {"kind": "driver", "node_id": "gross_revenue", "title": "Gross Revenue", "summary": "drove the change", "delta_value": 8}
      ]
    }
  }
}
JSON

"$ROOT/plugins/qluent/scripts/render-charts.sh" "$takeaway_only_json" "$takeaway_html" >/dev/null
assert_contains "$takeaway_html" '"title": "Gross Revenue"'

deep_dive_json="$tmpdir/deep_dive.json"
deep_dive_html="$tmpdir/deep_dive.html"

cat > "$deep_dive_json" <<'JSON'
{
  "outcomeShape": "cross_tree_bundle",
  "title": "Q1 vs Q4 Deep Dive",
  "period_label": "Q1 2026 vs Q4 2025",
  "trees": [
    {
      "tree_id": "revenue",
      "tree_label": "Revenue",
      "status": "blocked",
      "evaluation": {
        "root": {
          "id": "net_revenue",
          "label": "Net Revenue",
          "current_value": 39090016.17,
          "comparison_value": 0,
          "delta_value": 39090016.17,
          "delta_ratio": null,
          "contributions": [
            {"node_id": "gross_revenue", "label": "Gross Revenue", "delta_value": 39090016.17, "delta_share": 1}
          ]
        }
      },
      "agent": {
        "gaps": ["Revenue comparison is missing or zero"]
      }
    },
    {
      "tree_id": "funnel",
      "tree_label": "Conversion Funnel",
      "evaluation": {
        "root": {
          "id": "conversion_rate",
          "label": "Conversion Rate",
          "current_value": 0.034,
          "comparison_value": 0.041,
          "delta_value": -0.007,
          "delta_ratio": -0.1707
        }
      },
      "root_cause": {
        "conclusion": {
          "takeaways": [
            {"kind": "driver", "title": "Checkout conversion", "summary": "Checkout conversion drove the decline", "delta_value": -0.006, "share_of_change": 0.86}
          ]
        },
        "findings": [
          {
            "segment_findings": [
              {"dimension": "channel", "segment": "paid_search", "delta_value": -0.004, "delta_share": 0.57, "direction": "down"}
            ]
          }
        ]
      }
    }
  ],
  "cross_tree_overlap": ["paid_search appears in funnel and growth declines"],
  "caveats": ["Operations tree was sparse"],
  "recommended_next_steps": [
    {"title": "Drill into paid search", "why": "Largest repeated hotspot", "command": "qluent rca analyze funnel --period \"Q1 2026\" --segment-by channel --json-output"}
  ]
}
JSON

"$ROOT/plugins/qluent/scripts/render-charts.sh" "$deep_dive_json" "$deep_dive_html" >/dev/null
assert_contains "$deep_dive_html" '"outcomeShape": "cross_tree_bundle"'
assert_contains "$deep_dive_html" 'Cross-tree Root Movement'
assert_contains "$deep_dive_html" 'Segment Hotspots'
assert_contains "$deep_dive_html" 'paid_search appears in funnel and growth declines'
assert_contains "$deep_dive_html" 'Revenue comparison is missing or zero'

cat > "$contaminated_json" <<'TEXT'
[qluent] awaiting response... (30s)
{"tree_id":"revenue"}
TEXT

if "$ROOT/plugins/qluent/scripts/render-charts.sh" "$contaminated_json" "$tmpdir/bad.html" >"$tmpdir/render.out" 2>"$tmpdir/render.err"; then
  fail "render-charts.sh should reject contaminated non-JSON input"
fi
assert_contains "$tmpdir/render.err" "Input is not valid JSON"
assert_contains "$tmpdir/render.err" "Diagnosis: expected JSON at line 1"
assert_contains "$tmpdir/render.err" "qluent trees deep-dive --json-output --period"

echo "renderer contract tests passed"
