---
name: compose-authoring
description: Canonical protocol for authoring typed QueryPlans against a project's query catalog — node vocabulary, authoring rules, the plan_invalid repair loop, and cross-result composition safety. Loaded by qluent commands and agents; user-invocable for protocol inspection.
user-invocable: true
---

# Composed query authoring protocol

`qluent plan` compiles a typed QueryPlan you author against the project's
closed-world query catalog. It is **deterministic** (the same plan always
produces the same SQL) and **correct-by-construction**: the compiler rejects
anything outside the catalog with a repairable message instead of executing
plausible-but-wrong SQL. You author the plan; the backend owns the SQL.

This skill is the single source of truth for plan authoring. Commands and
agents should reference it by name rather than restating the rules.

## The catalog is the vocabulary

**This skill owns the exact invocations below.** Commands and agents run them
from here and must not restate, re-derive, or "improve" them in their own
files — a second copy is a second protocol.

Fetch the catalog once per session and cache it. `scripts/session-start.sh`
normally wrote it already, so the guard usually makes this a no-op:

```bash
umask 077
[ -s /tmp/qluent-catalog.json ] || qluent catalog --json-output > /tmp/qluent-catalog.json
jq '{bases: (.catalog.bases | map_values({columns})), metrics: .catalog.metrics, relationships: .catalog.relationships, derived_dimensions: .catalog.derived_dimensions, aliases: .catalog.column_aliases}' /tmp/qluent-catalog.json
```

If the catalog command reports that the project has no query catalog, the
compose path is unavailable for this project: say so and fall back to the NL
`qluent query` workflow.

Everything a plan references must come from this vocabulary:

- `catalog.bases` — the relations a `source` node may read, with their
  columns, scope keys and date columns.
- `catalog.metrics` — metric name → the bases that can compute it. Pair each
  metric with a base from its own list; the compiler rejects mismatches.
- `catalog.relationships` — the ONLY joins allowed. Each names its two bases,
  key columns, and cardinality.
- `catalog.derived_dimensions` — computed dims (time buckets like
  `order_month`, segment buckets) usable directly in `group_by.dims`.
- `catalog.column_aliases` / `value_aliases` — accepted alternative
  spellings. When unsure of a value's exact spelling, prefer `contains`
  filters over `=`.
- `plan_schema` — the JSON schema the plan document must satisfy.

## Plan shape

A plan is a DAG of nodes, each with a unique `id` (letters/digits/underscores,
not a SQL keyword), reading inputs by id. `output` names the terminal node.

```json
{
  "nodes": [
    {"op": "source", "id": "src", "base": "orders_successful_base"},
    {"op": "filter_by", "id": "f", "input": "src", "column": "business_type",
     "operator": "=", "value": "restaurants"},
    {"op": "group_by", "id": "g", "input": "f",
     "dims": ["order_month"], "metrics": ["gfv", "order_count"]},
    {"op": "top_k", "id": "top", "input": "g", "by": "gfv", "n": 10}
  ],
  "output": "top",
  "params": {"date_range": {"start": "2026-01-01", "end": "2026-04-01"}}
}
```

Node vocabulary:

| op | fields | notes |
|---|---|---|
| `source` | `base` | leaf; reads a catalog base |
| `filter_by` | `column`, `operator`, `value` | operators: `=`, `!=`, `>`, `<`, `>=`, `<=`, `in`, `not in`, `between`, `not between`, `like`, `not like`, `contains`, `starts_with`. Numbers as JSON numbers (enables HAVING-style filters after group_by); lists only for `in`/`not in`; `[low, high]` for between. `contains`/`starts_with` are case-insensitive and escape wildcards |
| `group_by` | `dims`, `metrics` | dims may be columns or derived dimensions; metrics from the catalog |
| `aggregate` | `metrics` | grand total, no dims |
| `top_k` | `by`, `n`, `direction` | rank + limit |
| `distinct` | `columns` | unique values |
| `select_columns` | `columns` | narrow projection |
| `add_derived_dims` | `names` | materialize derived dims without grouping |
| `join` | `left`, `right`, `how`, `relationship` | `relationship` must name a catalog relationship when any exist |
| `set_op` | `kind`, `inputs` | `union`/`union_all`/`intersect`/`except`; inputs need identical columns |
| `window` | `windows[]` | each: `func` (`running_total`/`delta`/`growth_pct`/`share_of_total`/`rank`), `value`, `order_by`, `partition_by`, `direction`, `as_name` |

`params` (top-level, not nodes): `date_range` (`start` inclusive, `end`
EXCLUSIVE), `currency` (`eur`/`local`), `global_entity_id` / `country_name`
(market scope).

## Authoring rules

1. **Date windows go in `params.date_range`**, never in a `filter_by` — the
   compiler applies them to the base's date column with partition pruning.
2. **Set market scope in `params.global_entity_id`** when the question names a
   market or your access is market-scoped. A `PLAN_SCOPE_VIOLATION` error
   means exactly this.
3. **Aggregate early.** `group_by` before `join`/`top_k`/`window`; join small
   aggregates on shared dims rather than joining raw bases (row-grain joins
   of additive metrics are rejected as double-counting).
4. **Period-over-period** = `group_by` on a time-grain derived dim (month →
   MoM, year → YoY), then `window` with `growth_pct` ordered by that dim.
   "Top N per group" = `window` `rank` with `partition_by`, then `filter_by`
   on the rank column. Place `window` after `group_by`.
5. **HAVING** = `filter_by` with a numeric value *after* `group_by`.
6. Copy catalog spellings exactly; `window.as_name` must not collide with an
   existing column.

## The repair loop

`Write` the plan document to `/tmp/qluent-plan.json`, then run — again, this
is the canonical invocation, not one shape among several:

```bash
umask 077
rm -f /tmp/qluent-plan-result.json
qluent plan --file /tmp/qluent-plan.json --json-output > /tmp/qluent-plan-result.json
jq '{status, error_code, error, row_count, grain}' /tmp/qluent-plan-result.json
```

`umask 077` plus `rm -f` recreate the result file private to the current user
each round (results can carry warehouse rows and SQL) and clobber any stale
file or symlink left at the fixed path. The plain redirect — not `| tee` —
keeps `qluent`'s own exit status as the command's status, so a failed run
cannot look successful.

- `status: "ok"` — proceed to presentation.
- `status: "plan_invalid"` — a repair instruction, not a failure. The `error`
  names what was wrong and what IS valid (available columns, the bases a
  metric works on, the relationship a join needs). Fix exactly that and
  re-run. Cap at 3 repair rounds.
- Re-running an *unchanged* plan is pointless; a *corrected* plan is expected.
- Fall back to `qluent query` (NL) only when the error shows the catalog
  genuinely lacks the vocabulary — a column, metric, or relationship that
  does not exist — or the shape needs SQL the node algebra cannot express.
  Say which vocabulary was missing when you fall back.

## Composing multiple results

Complex questions often decompose into several small plans whose results you
combine. Two fields in every result exist to keep that safe:

- `grain` — the columns that uniquely identify one result row. Only align
  results on their grain; never join two results on columns that are not the
  grain of at least one side.
- `metrics[*].summable` — whether values may be ADDED across result sets.
  Sums and row counts are summable. Averages, ratios (`kind: "ratio"`), and
  distinct counts (`kind: "count_distinct"`) are NOT: recompute them from
  their summable parts, or get them from one plan at the right grain instead.

Prefer one plan with an extra `group_by` dim over N single-value plans — the
compiler and the database do the composition better than post-hoc arithmetic.

## Provenance

Composed results are deterministic: the same plan always compiles to the same
SQL against the catalog. Label them "composed query (deterministic)" and cite
the returned `sql` (and plan on request). They are still NOT tree evidence —
never blend them into Shapley attribution or other tree-derived claims; the
`qluent-interpretation` skill owns that boundary.
