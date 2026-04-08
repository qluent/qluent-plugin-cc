#!/usr/bin/env bash
# render-charts.sh — Reads qluent JSON output and generates a self-contained HTML dashboard
# Usage: render-charts.sh <input.json> <output.html>

set -euo pipefail

INPUT="${1:-/tmp/qluent-viz-data.json}"
OUTPUT="${2:-/tmp/qluent-viz.html}"

if [ ! -f "$INPUT" ]; then
  echo "Error: Input file not found: $INPUT" >&2
  exit 1
fi

# Read file once; escape </script> to prevent XSS when embedding in HTML
JSON_DATA=$(sed 's|</script>|<\\/script>|gi' "$INPUT")

cat > "$OUTPUT" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Qluent Analysis Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
    background: #0f1117;
    color: #e1e4e8;
    padding: 24px;
    min-height: 100vh;
  }
  .header {
    text-align: center;
    margin-bottom: 32px;
    padding-bottom: 20px;
    border-bottom: 1px solid #2d333b;
  }
  .header h1 {
    font-size: 1.6rem;
    font-weight: 600;
    color: #f0f6fc;
    margin-bottom: 8px;
  }
  .header .subtitle {
    font-size: 0.9rem;
    color: #8b949e;
    max-width: 700px;
    margin: 0 auto;
  }
  .chart-section {
    background: #161b22;
    border: 1px solid #2d333b;
    border-radius: 12px;
    padding: 24px;
    margin-bottom: 24px;
    max-width: 900px;
    margin-left: auto;
    margin-right: auto;
  }
  .chart-section h2 {
    font-size: 1.1rem;
    font-weight: 600;
    color: #f0f6fc;
    margin-bottom: 16px;
  }
  .chart-container {
    position: relative;
    width: 100%;
    max-height: 400px;
  }
  .confidence-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
    margin-top: 12px;
  }
  .evidence-tag {
    display: inline-block;
    padding: 4px 10px;
    border-radius: 6px;
    font-size: 0.8rem;
    font-weight: 500;
    margin: 3px;
  }
  .evidence-present { background: #1a3a2a; color: #3fb950; border: 1px solid #2ea04380; }
  .evidence-missing { background: #3a1a1a; color: #f85149; border: 1px solid #da363480; }
  .score-display {
    font-size: 2.4rem;
    font-weight: 700;
    text-align: center;
    padding: 16px;
  }
  .score-high { color: #3fb950; }
  .score-medium { color: #d29922; }
  .score-low { color: #f85149; }
  .no-data {
    text-align: center;
    color: #8b949e;
    padding: 40px;
    font-size: 0.95rem;
  }
  .hidden { display: none; }
  canvas { max-height: 380px; }
</style>
</head>
<body>
HTMLEOF

# Inject data as JS variable (already XSS-escaped above)
echo "<script>const qdata = $JSON_DATA;</script>" >> "$OUTPUT"

cat >> "$OUTPUT" << 'JSEOF'

<!-- Header — rendered from JS to avoid shell injection -->
<div class="header">
  <h1 id="dash-title"></h1>
  <div class="subtitle" id="dash-subtitle"></div>
</div>
<script>
(function() {
  const esc = s => { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; };
  const title = qdata.tree_id || qdata.match?.tree_id || 'Metric';
  const findings = (qdata.agent?.top_findings || []).join(' | ');
  document.getElementById('dash-title').textContent = title + ' \u2014 Analysis Dashboard';
  document.getElementById('dash-subtitle').textContent = findings;
})();
</script>

<!-- Trend -->
<div class="chart-section" id="trend-section">
  <h2>Trend Over Time</h2>
  <div class="chart-container">
    <canvas id="trendChart"></canvas>
  </div>
</div>
<script>
(function() {
  const periods = qdata.trend?.periods || [];
  if (!periods.length) { document.getElementById('trend-section').classList.add('hidden'); return; }

  const labels = periods.map(p => p.period_id || `${p.start_date || ''}`);
  const values = periods.map(p => p.value);
  const pctChanges = periods.map(p => p.percentage_change || 0);
  const trendColors = periods.map(p => {
    const label = (p.trend_label || '').toLowerCase();
    if (label === 'accelerating' || label === 'recovering') return '#3fb950';
    if (label === 'declining') return '#f85149';
    if (label === 'decelerating') return '#d29922';
    if (label === 'volatile') return '#a371f7';
    return '#8b949e';
  });

  new Chart(document.getElementById('trendChart'), {
    type: 'bar',
    data: {
      labels,
      datasets: [
        {
          type: 'line',
          label: 'Value',
          data: values,
          borderColor: '#58a6ff',
          backgroundColor: '#58a6ff22',
          borderWidth: 2.5,
          pointRadius: 5,
          pointBackgroundColor: '#58a6ff',
          tension: 0.3,
          fill: true,
          yAxisID: 'y'
        },
        {
          type: 'bar',
          label: '% Change',
          data: pctChanges,
          backgroundColor: trendColors.map(c => c + '99'),
          borderColor: trendColors,
          borderWidth: 1,
          borderRadius: 4,
          yAxisID: 'y1'
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: { labels: { color: '#e1e4e8' } },
        tooltip: {
          callbacks: {
            afterBody(items) {
              const i = items[0]?.dataIndex;
              if (i != null && periods[i]?.trend_label) return `Trend: ${periods[i].trend_label}`;
            }
          }
        }
      },
      scales: {
        x: { ticks: { color: '#8b949e' }, grid: { color: '#2d333b' } },
        y: { position: 'left', ticks: { color: '#58a6ff' }, grid: { color: '#2d333b' }, title: { display: true, text: 'Value', color: '#8b949e' } },
        y1: { position: 'right', ticks: { color: '#8b949e', callback: v => v + '%' }, grid: { display: false }, title: { display: true, text: '% Change', color: '#8b949e' } }
      }
    }
  });
})();
</script>

<!-- Shapley Attribution -->
<div class="chart-section" id="rca-section">
  <h2>Root Cause — Shapley Attribution</h2>
  <div class="chart-container">
    <canvas id="rcaChart"></canvas>
  </div>
</div>
<script>
(function() {
  const contributors = qdata.root_cause?.top_contributors || [];
  if (!contributors.length) { document.getElementById('rca-section').classList.add('hidden'); return; }

  const sorted = [...contributors].sort((a, b) => Math.abs(b.shapley_share || b.percentage_share || 0) - Math.abs(a.shapley_share || a.percentage_share || 0));
  const labels = sorted.map(c => c.node || c.node_id || 'Unknown');
  const shares = sorted.map(c => ((c.shapley_share || c.percentage_share || 0) * 100));
  const colors = shares.map(v => v >= 0 ? '#3fb95099' : '#f8514999');
  const borders = shares.map(v => v >= 0 ? '#3fb950' : '#f85149');

  new Chart(document.getElementById('rcaChart'), {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        label: 'Attribution Share (%)',
        data: shares,
        backgroundColor: colors,
        borderColor: borders,
        borderWidth: 1,
        borderRadius: 4
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: ctx => `${ctx.parsed.x >= 0 ? '+' : ''}${ctx.parsed.x.toFixed(1)}% of total change`
          }
        }
      },
      scales: {
        x: { ticks: { color: '#8b949e', callback: v => v + '%' }, grid: { color: '#2d333b' }, title: { display: true, text: 'Share of Parent Delta', color: '#8b949e' } },
        y: { ticks: { color: '#e1e4e8' }, grid: { display: false } }
      }
    }
  });
})();
</script>

<!-- Evidence Coverage -->
<div class="chart-section" id="confidence-section">
  <h2>Evidence Coverage</h2>
  <div class="confidence-grid">
    <div>
      <div class="score-display" id="conf-score"></div>
      <div style="text-align:center;color:#8b949e;font-size:0.85rem;">Evidence Coverage Score</div>
    </div>
    <div>
      <div style="padding:8px;">
        <div style="margin-bottom:8px;font-weight:500;color:#f0f6fc;">Evidence Types</div>
        <div id="evidence-tags"></div>
      </div>
    </div>
  </div>
</div>
<script>
(function() {
  const rc = qdata.root_cause || {};
  const score = rc.conclusion?.confidence_score;
  if (score == null) { document.getElementById('confidence-section').classList.add('hidden'); return; }

  const pct = (score * 100).toFixed(0);
  const el = document.getElementById('conf-score');
  el.textContent = pct + '%';
  el.className = 'score-display ' + (score >= 0.8 ? 'score-high' : score >= 0.6 ? 'score-medium' : 'score-low');

  const present = rc.evidence_types_present || [];
  const missing = rc.evidence_types_missing || [];
  const container = document.getElementById('evidence-tags');
  present.forEach(t => {
    const span = document.createElement('span');
    span.className = 'evidence-tag evidence-present';
    span.textContent = '\u2713 ' + t;
    container.appendChild(span);
  });
  missing.forEach(t => {
    const span = document.createElement('span');
    span.className = 'evidence-tag evidence-missing';
    span.textContent = '\u2717 ' + t;
    container.appendChild(span);
  });
})();
</script>

<!-- Tree Comparison -->
<div class="chart-section" id="compare-section">
  <h2>Tree Comparison</h2>
  <div class="chart-container">
    <canvas id="compareChart"></canvas>
  </div>
  <div id="mechanism-label" style="text-align:center;margin-top:12px;color:#8b949e;font-size:0.9rem;"></div>
</div>
<script>
(function() {
  const t1 = qdata.tree1;
  const t2 = qdata.tree2;
  if (!t1 || !t2) { document.getElementById('compare-section').classList.add('hidden'); return; }

  new Chart(document.getElementById('compareChart'), {
    type: 'bar',
    data: {
      labels: [t1.name || 'Tree 1', t2.name || 'Tree 2'],
      datasets: [
        {
          label: 'Compare Period',
          data: [t1.value_compare, t2.value_compare],
          backgroundColor: '#8b949e66',
          borderColor: '#8b949e',
          borderWidth: 1,
          borderRadius: 4
        },
        {
          label: 'Current Period',
          data: [t1.value_current, t2.value_current],
          backgroundColor: '#58a6ff88',
          borderColor: '#58a6ff',
          borderWidth: 1,
          borderRadius: 4
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { labels: { color: '#e1e4e8' } },
        tooltip: {
          callbacks: {
            afterBody() {
              const m = qdata.mechanism_type;
              return m ? `Mechanism: ${m.replace(/_/g, ' ')}` : '';
            }
          }
        }
      },
      scales: {
        x: { ticks: { color: '#e1e4e8' }, grid: { display: false } },
        y: { ticks: { color: '#8b949e' }, grid: { color: '#2d333b' } }
      }
    }
  });

  if (qdata.mechanism_type) {
    document.getElementById('mechanism-label').textContent =
      'Mechanism: ' + qdata.mechanism_type.replace(/_/g, ' ');
  }
})();
</script>

<!-- No-data fallback -->
<div class="chart-section hidden" id="no-data-section">
  <div class="no-data">No visualizable data sections found in the output.<br>Run <code>/qluent:investigate</code> first to generate analysis data.</div>
</div>
<script>
(function() {
  const sections = ['trend-section', 'rca-section', 'confidence-section', 'compare-section'];
  const anyVisible = sections.some(id => !document.getElementById(id).classList.contains('hidden'));
  if (!anyVisible) document.getElementById('no-data-section').classList.remove('hidden');
})();
</script>

</body></html>
JSEOF

echo "$OUTPUT"
