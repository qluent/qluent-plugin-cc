---
name: qluent-interpretation
description: Canonical protocol for interpreting qluent CLI output — tree resolution, windows, provenance, Shapley, elasticity guardrails, and segment-cut fallback. Loaded by qluent commands and agents; user-invocable for protocol inspection.
user-invocable: true
---

# Qluent interpretation protocol

The qluent server is deterministic. It returns pre-interpreted analysis (root
movement, Shapley attribution, trend labels, mechanism interpretations,
confidence scores, elasticity tables). Your job is to drive it correctly and
present what it returns — not to recompute, infer, or paraphrase the math.

This skill is the single source of truth for protocol. Commands and agents
should reference it by name rather than restating the rules.

## Tree resolution

The server does not match natural-language questions to trees. Pick a tree id
client-side before any quantitative call.

1. If the user named a tree (`revenue`, `order_volume`, `roas`), use it directly.
2. Otherwise run `qluent trees list --json-output` and match the question
   against each tree's `id`, `label`, `description`, declared `dimensions`, and
   child node labels. Bias toward:
   - nouns that match a tree label (e.g. "revenue" → revenue tree)
   - concepts that match a child node label (e.g. "spend efficiency" → roas)
   - dimensions named in the question (e.g. "by country" → tree declaring `country`)
3. If no tree is a clear winner, ask the user to choose from the top 2–3
   candidates with labels and descriptions. Use `AskUserQuestion` only when
   the caller has that tool; otherwise ask in plain text. Do not guess silently.

Always pass an explicit `<tree_id>` to every qluent subcommand.
Always use `--json-output`.

## Windows

Reuse the exact `current_window` and `comparison_window` from the prior
investigation when answering follow-ups. Do not infer a new period unless the
user changed it.

- Natural-language periods: `--period "last week"`.
- Explicit windows: `--current YYYY-MM-DD:YYYY-MM-DD --compare YYYY-MM-DD:YYYY-MM-DD`.
- If the user gave neither, default to `--period "last week"` for `investigate`
  and ask for a period before `deep-dive`. Use `AskUserQuestion` only when the
  caller has that tool; otherwise ask in plain text.

When current and comparison windows have different day counts, surface that as
a caveat near the headline.

## Quantitative claims

Every metric value, delta, decomposition, segment ranking, elasticity estimate,
and ranked recommendation must be grounded in deterministic qluent JSON
returned during the current workflow.

- Query root movement before explaining what changed.
- Query child decomposition before naming drivers.
- Drill into material drivers only after returned attribution or
  `agent.recommended_next_steps` identifies them.
- Do not invent, back-calculate, interpolate, or combine metric math outside
  the returned qluent fields.
- Never parse tool-result temp files or write ad-hoc scripts against prior
  bash output.
- Do not rerun both JSON and non-JSON versions of the same command unless JSON
  is genuinely insufficient.

For every material finding, cite provenance in plain language: result type,
tree id or label, node/segment, exact current/comparison windows. Separate
returned facts from interpretation, caveats, and recommendations.

If a required field is missing, run the deterministic follow-up query or state
the missing query — do not fill the gap from prose.

## Confidence and Shapley

- Confidence scores are evidence-coverage heuristics. Never describe them as
  probabilities or likelihoods.
- Attribution values are computed server-side using Shapley values from
  cooperative game theory. Use the returned numbers; do not redistribute them.
- Trend labels, anomaly flags, and mechanism interpretations are returned by
  the server. Present them; do not relabel.

## Elasticity and lever guardrails

Elasticity output is directional decision support, not causal proof. Treat it
as a measured association from the returned sample window unless the response
explicitly includes causal validation.

When interpreting `levers`, `elasticity`, scenario, or impact fields:

- Label the evidence type using the returned label when present:
  `observed_correlation`, `historical_elasticity`, `model_estimate`,
  `experiment_backed`.
- State the exact sample windows and dimensions/cuts in the returned result.
- Report server-provided confidence, materiality, data-quality warnings, and
  guardrail metrics before recommending any lever change.
- Distinguish correlation and sensitivity from causality. Do not write that a
  lever "caused" a movement unless a returned field supports causal language.
- Treat low confidence, immaterial effects, sparse windows, volatile segments,
  or guardrail warnings as reasons to suggest the next drill or test, not an
  action plan.
- Scenario rows (+1%, +5%, +10%) are local linear estimates from the current
  operating point and may not hold outside the observed range.

Recommend a lever change only when all of these hold in the returned result:

1. The lever effect is material, not merely directional.
2. Confidence/evidence coverage is sufficient.
3. Guardrail metrics show no offsetting risk and no unresolved data-quality
   warning.
4. The recommendation is scoped to the returned sample window and segment.

Otherwise recommend the next drill: extend the window, validate across another
segment, run `qluent trees compare ... --json-output`, or request an
experiment/instrumentation check.

Acceptable: *"The returned elasticity table shows a directional association in
2026-04-13:2026-04-19 vs 2026-04-06:2026-04-12; conversion rate has the largest
local sensitivity, with sufficient evidence coverage and no guardrail warning.
Treat the +5% row as a local estimate, not a forecast."*

Unacceptable: *"Increase conversion by 5% and revenue will rise by the
scenario amount."* — overstates causality and ignores guardrails.

For follow-ups about elasticity, leverage, or "what if": read the embedded
`investigate.levers` block first. Run `qluent trees levers <tree_id> --current
<start>:<end> --compare <start>:<end> --json-output` only when the embedded
block is insufficient.

## Unsupported segment cuts

If the user asks for a dimension the current tree does not expose, pivot to a
compatible companion tree with the same windows and synthesize both views.

### Selection algorithm

Given the cached catalog (`/tmp/qluent-tree-capabilities.json`, or a fresh
`qluent trees list --json-output`), the current tree id, and the requested
dimensions, rank candidates as follows:

1. **Full coverage wins.** Among trees that declare *every* requested
   dimension, prefer the best.
2. **Otherwise, most overlapping dimensions wins.** Among trees that expose at
   least one requested dimension, prefer the highest count.
3. **Tiebreak — Root-metric family tiebreak.** Within either group, prefer
   trees that share the current tree's root metric.
4. **Final tiebreak: alphabetical tree id.**
5. **No candidate? Stop and say so.** Do not invent or fabricate.

This is the single source of truth for the algorithm. The PostToolUse hook
runs `scripts/select-fallback-tree.sh` to surface the chosen tree to the
user; agents that decide pre-emptively (e.g. `segment-explorer`) apply the
same algorithm against the cached catalog.

### Synthesis

Combine both views: the original tree for KPI-specific reasoning, the
companion tree for the requested segmentation. State which tree provided
which view. Reuse the exact current/comparison windows from the prior
result; never stop at the limitation.

## Visualization

When deterministic RCA or elasticity output is available, the primary artifact
is a `RcaReportSpec` produced by `/qluent:visualize`. Do not hand-roll HTML,
CSS, or Chart.js for normal analysis output. Local HTML is a fallback only
when the user explicitly requests `--simple`/`--html`/a browser demo, or the
UI report contract is unavailable.

See `/qluent:visualize` for the section mapping (`root_movement`,
`driver_decomposition`, `material_segment_scan`, `mix_shift`,
`elasticity_summary`, `next_drills`) and the `dashboard-design` skill for HTML
fallback styling.

## Session paths

Three temp files form the rendezvous between qluent producers and consumers
within a session. This section is the canonical declaration; every producer,
consumer, and test fixture references the path string verbatim. The set of
files allowed to mention each path is pinned by `tests/test_session_paths.sh`
— adding a new consumer requires updating that allowlist on purpose.

### `/tmp/qluent-viz-data.json` — investigation cache
- **Producer:** `/qluent:investigate` (and `qluent-analyst`) tee bundled
  investigation JSON to this path.
- **Consumers:** `/qluent:visualize` reads it to build `RcaReportSpec`;
  `scripts/post-bash.sh` inspects it to surface unsupported-cut nudges and
  freshness reminders; `scripts/render-charts.sh` reads it for the HTML
  fallback.
- **Schema:** the full investigate response, including `tree_id`,
  `tree_label`, `current_window`, `comparison_window`, `agent`, `evaluation`,
  `root_cause`, `levers`, `validation`, `warnings`.
- **Freshness:** consumers should verify `current_window.date_from` is recent
  and the `tree_id` matches the question before rendering. Stale or
  mismatched data triggers a re-run suggestion.

### `/tmp/qluent-deep-dive-bundle.json` — cross-tree deep-dive bundle
- **Producer:** `/qluent:deep-dive` tees the bundled cross-tree JSON to this
  path.
- **Consumer:** `scripts/post-bash.sh` checks for it and steers synthesis
  toward one cross-tree narrative.
- **Schema:** bundle-level period/windows plus per-tree results per
  `qluent trees deep-dive --json-output`.

### `/tmp/qluent-tree-capabilities.json` — session tree catalog
- **Producer:** `scripts/session-start.sh` writes the normalized catalog
  (tree id, label, root metric, dimensions, children) at session start.
- **Consumers:** `scripts/post-bash.sh` and `scripts/select-fallback-tree.sh`
  read it for the unsupported-cut algorithm; `segment-explorer` and
  `rca-validator` agents read it to pick companion trees pre-emptively.
- **Schema:** `{"trees": [{"id", "label", "root", "desc", "dims", "children"}, ...]}`.
