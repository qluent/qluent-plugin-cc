#!/usr/bin/env bash
# Qluent session-start hook: injects available metric tree metadata into context.
# Fails silently if qluent is not installed or configured.

set -euo pipefail

python_bin=/usr/bin/python3
if [ ! -x "$python_bin" ]; then
  python_bin=$(command -v python3 || true)
fi

[ -n "$python_bin" ] || exit 0

# Check if qluent is available
if ! command -v qluent &>/dev/null; then
  cat <<'EOF'
[Qluent] CLI is not installed. Run /qluent:setup to install and configure it.
EOF
  exit 0
fi

# Try to list trees — reports setup needed on auth/config failure
if ! output=$(qluent trees list --json-output 2>/dev/null); then
  cat <<'EOF'
[Qluent] CLI is installed but not configured. Run /qluent:setup to authenticate and connect to your project.
EOF
  exit 0
fi

# Extract tree metadata for context injection
catalog_file=/tmp/qluent-tree-capabilities.json

context=$(printf '%s' "$output" | QLUENT_TREE_CATALOG="$catalog_file" "$python_bin" -c "
import sys, json
import os

try:
    data = json.load(sys.stdin)
    raw = data.get('trees', data) if isinstance(data, dict) else data
except Exception:
    sys.exit(0)

if not raw:
    sys.exit(0)

def norm(t):
    return {
        'id': t.get('id', t.get('tree_id', 'unknown')),
        'label': t.get('label', t.get('tree_label', t.get('id', t.get('tree_id', 'unknown')))),
        'root': t.get('root_metric', t.get('root', '')),
        'desc': t.get('description', t.get('label', '')),
        'dims': t.get('dimensions', []),
        'children': t.get('children', t.get('child_metrics', [])),
    }

trees = [norm(t) for t in raw]
count = len(trees)
catalog_path = os.environ.get('QLUENT_TREE_CATALOG')

if catalog_path:
    try:
        with open(catalog_path, 'w', encoding='utf-8') as fh:
            json.dump({'trees': trees}, fh)
    except Exception:
        pass

print(f'[Qluent] {count} metric tree{\"s\" if count != 1 else \"\"} available for analysis:')
print()
for t in trees:
    line = f'- **{t[\"id\"]}**'
    if t['desc']:
        line += f': {t[\"desc\"]}'
    meta = []
    if t['root']:
        meta.append(f'root metric: {t[\"root\"]}')
    if t['children']:
        names = [c.get('id', c.get('name', str(c))) if isinstance(c, dict) else str(c) for c in t['children'][:5]]
        meta.append('breaks into: ' + ', '.join(names))
    if t['dims']:
        names = [d.get('name', str(d)) if isinstance(d, dict) else str(d) for d in t['dims'][:4]]
        meta.append('segments: ' + ', '.join(names))
    if meta:
        line += '  (' + ' | '.join(meta) + ')'
    print(line)
print()
print('Unsupported cuts: the post-bash hook surfaces the closest companion tree per the algorithm in the qluent-interpretation skill. Follow its suggestion and synthesize both views.')
print()
print('Business-language routing hints: revenue/sales/GMV/AOV -> revenue; growth/users/acquisition/reactivation -> growth; delivery/late/failed/courier/ops quality -> operations; conversion/checkout/cart/traffic/payment -> conversion_funnel.')
print('No tree match? Ad-hoc, row-level, entity-lookup, or SQL-shaped questions route per the qluent-interpretation skill (slash command /qluent:query): a composed plan first when the query catalog covers the question, else qluent query. KPI movement/RCA questions stay on the trees above.')
print('On first run, orient the user from this tree metadata and offer one concrete first command. Use qluent whoami/status/suggestions only when available; do not probe unsupported project/status commands.')
print('After an investigation, offer an RCA report, mix-shift report, or elasticity report through /qluent:visualize before any local HTML fallback.')
print()
print('Ask a business performance question or use /qluent:investigate to start, for example /qluent:investigate revenue last month.')
" 2>/dev/null) || context=""

if [ -n "$context" ]; then
  echo "$context"
fi

# Composed-plan capability probe (newer CLI + backend). Runs even when no
# metric trees exist -- a catalog-only project still gets the plan path. Fails
# silently on CLIs without `qluent plan`; a loadable catalog is cached at the
# session path the compose-authoring skill expects, so later plan authoring
# skips the re-fetch.
compose_catalog=/tmp/qluent-catalog.json
compose_context=""
# The fixed path outlives a Claude session; never reuse another project's catalog.
rm -f "$compose_catalog"
if qluent plan --help &>/dev/null; then
  catalog_err=$(mktemp)
  if catalog_json=$(qluent catalog --json-output 2>"$catalog_err"); then
    (umask 077; printf '%s' "$catalog_json" > "$compose_catalog")
    compose_context=$(printf '%s' "$catalog_json" | "$python_bin" -c "
import sys, json
try:
    data = json.load(sys.stdin)
    catalog = data.get('catalog') or {}
    bases = catalog.get('bases') or {}
    metrics = catalog.get('metrics') or {}
except Exception:
    sys.exit(0)
if not bases:
    sys.exit(0)
print(f'[Qluent] Query catalog available: {len(bases)} bases, {len(metrics)} metrics (cached at /tmp/qluent-catalog.json).')
print('For ad-hoc aggregations, breakdowns and rankings the catalog covers, prefer a composed plan (qluent plan; protocol in the compose-authoring skill) over the NL qluent query -- deterministic and catalog-checked.')
" 2>/dev/null) || compose_context=""
  elif grep -q 'QUERY_CATALOG_INVALID' "$catalog_err" 2>/dev/null; then
    compose_context='[Qluent] This project has a query_catalog that fails to load (fix it under the Model tab) -- composed plans are unavailable until then; ad-hoc questions fall back to qluent query.'
  fi
  rm -f "$catalog_err"
fi

if [ -n "$compose_context" ]; then
  echo ""
  echo "$compose_context"
fi
