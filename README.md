# Baskerville

A justification-propagating inference engine for PureScript, where **the
explanation is the product**: every fact is a proof term carrying the
rule that derived it and the facts it consumed, and the derivation DAG
is the deliverable — renderable, queryable, and testable against a
model-enumeration oracle.

Extracted from [kibitzer](../kibitzer)'s core (the Cluedo-watching
demo), designed against three clients: kibitzer itself, Harmonia
(scale/key inference and counterpoint linting), and ShapedSteer (plan
facts over typed DAGs).

**New here?** Two entry points, by appetite:
[`docs/what-can-you-do.md`](docs/what-can-you-do.md) — what this is
for, in plain language, no code; then
[`docs/introduction.md`](docs/introduction.md) — the JTMS idea for
PureScript/Haskell programmers, grounded in this library's actual
types.

**Status: kernel v0 + first client.** The design record is
[`docs/library-sketch.md`](docs/library-sketch.md) — the layer stack
(proof-term kernel, analyzable rule eDSL with a declared-read-set
escape hatch, perspectives, oracle seam), the sets-vs-lattices carrier
decision, and the extensions catalogue (windows, negation, Doyle,
ATMS) with costed verdicts.

The workspace:

- **`core/`** (`baskerville-core`) — `Baskerville.Kernel` (facts as proof terms,
  hash-consed feed, acyclicity by construction), `Baskerville.Engine`
  (prim-form rules, naive monotone saturation, `learn` as the stream
  fold), `Baskerville.Rule` (the eDSL: rule bodies as nondeterministic KB
  queries where `matches`/`require` cite premises automatically and
  `absent` is negation-as-failure — the derivation writes itself),
  `Baskerville.Explain` (derivation DAGs by backward scan, depths,
  grounding). Tested against a toy reachability client: the kernel
  laws (acyclicity, hash-consing, monotonicity, first-justification,
  fixpoint idempotence) plus eDSL-vs-prim agreement.
- **`examples/meeting/`** (`baskerville-meeting`) — the hello-world client:
  five people scheduling a meeting, twenty candidate slots, one
  survivor, and the announcement carries the reason every other slot
  died. Three rules, one page; the appendix of
  `docs/what-can-you-do.md` walks through it.
- **`examples/sudoku/`** (`baskerville-sudoku`) — the second-client proof, and
  the prune-facts-on-the-feed pole of the residue policy: `Not cell
  digit` is a first-class claim with a derivation. Four singles-tier
  rules, all written in the eDSL (a naked single is four lines);
  fixtures generated from the pattern grid, never hand-transcribed.
  `spago run -p baskerville-sudoku` prints a solve transcript with one proof
  explained.

```
spago test                              # kernel laws + sudoku soundness/honesty
spago run -p baskerville-meeting               # the hello-world: one answer, nineteen reasons
spago run -p baskerville-sudoku                # solve transcript
spago run -p baskerville-sudoku -- page > pages/explain.html   # one proof, rendered
```

**On the name**: the Haskell propagator shelf already has `holmes`;
Baskerville is the casebook — the deliverable is the written-up
derivation, not the deduction alone. The library descends from the
truth-maintenance tradition without being a TMS: it keeps the
justification structure and deliberately omits belief revision, which
replay makes redundant at these scales. The family history — where
each piece of the classical TMS actually ended up, and the argued
verdict on truth maintenance proper — is
[`docs/antecedents.md`](docs/antecedents.md).
