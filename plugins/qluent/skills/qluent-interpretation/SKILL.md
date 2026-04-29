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

If the user asks for a dimension the current tree does not expose:

1. Reuse the exact current/comparison windows from the prior result.
2. Check the session tree catalog (or run `qluent trees list --json-output`)
   for a compatible tree that declares the missing dimension.
3. Re-run the investigation or RCA on the fallback tree with the same windows.
4. Synthesize both views: original tree for KPI-specific reasoning, fallback
   tree for the requested segmentation. State which tree provided which view.

Never stop at the limitation. The PostToolUse hook surfaces compatible
fallback trees automatically — follow its suggestions.

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
