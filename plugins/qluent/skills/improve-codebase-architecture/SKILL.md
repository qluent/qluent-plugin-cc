---
name: improve-codebase-architecture
description: Surface deepening opportunities in a codebase — refactors that turn shallow modules into deep ones for testability and AI-navigability. Use when the user wants to improve architecture, find refactor candidates, consolidate tightly-coupled modules, or sharpen module boundaries.
user-invocable: true
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities** —
refactors that turn shallow modules into deep ones. The aim is testability and
AI-navigability.

Adapted from Matt Pocock's `improve-codebase-architecture` skill
(`github.com/mattpocock/skills`).

## Vocabulary

Use the terms in [LANGUAGE.md](LANGUAGE.md) exactly — **module**, **interface**,
**implementation**, **depth**, **seam**, **adapter**, **leverage**, **locality**.
Don't substitute "component," "service," "API," or "boundary." Consistent
language is the whole point.

The two tests you'll quote most:

- **Deletion test** — imagine deleting the module. If complexity vanishes, it
  was a pass-through. If complexity reappears across N callers, it was earning
  its keep.
- **The interface is the test surface** — callers and tests cross the same
  seam. If you want to test *past* the interface, the module is probably the
  wrong shape.

## Inputs

This skill is _informed_ by the project's domain model:

- **Domain glossary** — if the project has `CONTEXT.md`, `GLOSSARY.md`, or an
  equivalent, read it first. Domain terms name good seams.
- **ADRs** — if `docs/adr/` (or equivalent) exists, read the ones touching the
  area you're considering. Decisions there should not be re-litigated unless
  friction warrants reopening them.

If neither exists, proceed without — but offer to capture new domain terms as
you discover them (see the grilling loop below).

## Process

### 1. Explore

Use the Agent tool with `subagent_type=Explore` to walk the codebase. Don't
follow rigid heuristics — explore organically and note where you experience
friction:

- Where does understanding one concept require bouncing between many small
  modules?
- Where are modules **shallow** — interface nearly as complex as the
  implementation?
- Where have pure functions been extracted just for testability, but the real
  bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts of the codebase are untested, or hard to test through their
  current interface?

Apply the **deletion test** to anything you suspect is shallow: would deleting
it concentrate complexity, or just move it? A "yes, concentrates" is the signal
you want.

### 2. Present candidates

Present a numbered list of deepening opportunities. For each candidate:

- **Files** — which files/modules are involved
- **Problem** — why the current architecture is causing friction
- **Solution** — plain English description of what would change
- **Benefits** — explained in terms of locality and leverage, and how tests
  would improve

Use the project's domain vocabulary for what the modules represent, and
[LANGUAGE.md](LANGUAGE.md) vocabulary for the architecture. If the project's
glossary defines "Order," talk about "the Order intake module" — not "the
FooBarHandler," not "the Order service."

**ADR conflicts**: if a candidate contradicts an existing ADR, only surface it
when the friction is real enough to warrant revisiting the ADR. Mark it clearly
(e.g. _"contradicts ADR-0007 — but worth reopening because…"_). Don't list
every theoretical refactor an ADR forbids.

Do NOT propose interfaces yet. Ask the user: "Which of these would you like to
explore?"

### 3. Grilling loop

Once the user picks a candidate, drop into a grilling conversation. Walk the
design tree with them — constraints, dependencies, the shape of the deepened
module, what sits behind the seam, what tests survive. See [DEEPENING.md](DEEPENING.md)
for how dependency category determines the test seam.

Side effects happen inline as decisions crystallize:

- **Naming a deepened module after a concept not in the domain glossary?** Add
  the term to the project's `CONTEXT.md` (create the file lazily if it doesn't
  exist). Capture: term, one-line definition, distinction from neighbouring
  terms.
- **Sharpening a fuzzy term during the conversation?** Update the glossary
  right there.
- **User rejects the candidate with a load-bearing reason?** Offer an ADR,
  framed as: _"Want me to record this as an ADR so future architecture reviews
  don't re-suggest it?"_ Only offer when the reason would actually be needed by
  a future explorer to avoid re-suggesting the same thing — skip ephemeral
  reasons ("not worth it right now") and self-evident ones. A minimal ADR
  captures: context, decision, consequences, and the rejected alternative this
  skill surfaced.
- **Want to explore alternative interfaces for the deepened module?** See
  [INTERFACE-DESIGN.md](INTERFACE-DESIGN.md).
