# purescript-jtms

A justification-propagating inference engine for PureScript, where **the
explanation is the product**: every fact is a proof term carrying the
rule that derived it and the facts it consumed, and the derivation DAG
is the deliverable — renderable, queryable, and testable against a
model-enumeration oracle.

Extracted from [kibitzer](../kibitzer)'s core (the Cluedo-watching
demo), designed against three clients: kibitzer itself, Harmonia
(scale/key inference and counterpoint linting), and ShapedSteer (plan
facts over typed DAGs).

**Status: kernel v0 + first client.** The design record is
[`docs/library-sketch.md`](docs/library-sketch.md) — the layer stack
(proof-term kernel, analyzable rule eDSL with a declared-read-set
escape hatch, perspectives, oracle seam), the sets-vs-lattices carrier
decision, and the extensions catalogue (windows, negation, Doyle,
ATMS) with costed verdicts.

The workspace:

- **`core/`** (`jtms-core`) — `Jtms.Kernel` (facts as proof terms,
  hash-consed feed, acyclicity by construction), `Jtms.Engine`
  (prim-form rules, naive monotone saturation, `learn` as the stream
  fold), `Jtms.Rule` (the eDSL: rule bodies as nondeterministic KB
  queries where `matches`/`require` cite premises automatically and
  `absent` is negation-as-failure — the derivation writes itself),
  `Jtms.Explain` (derivation DAGs by backward scan, depths,
  grounding). Tested against a toy reachability client: the kernel
  laws (acyclicity, hash-consing, monotonicity, first-justification,
  fixpoint idempotence) plus eDSL-vs-prim agreement.
- **`sudoku/`** (`jtms-sudoku`) — the second-client proof, and the
  prune-facts-on-the-feed pole of the residue policy: `Not cell digit`
  is a first-class claim with a derivation. Four singles-tier rules,
  all written in the eDSL (a naked single is four lines); fixtures
  generated from the pattern grid, never hand-transcribed. `spago run
  -p jtms-sudoku` prints a solve transcript with one proof explained.

```
spago test          # both packages: kernel laws + sudoku soundness/honesty
spago run -p jtms-sudoku
```

**On the name**: a working name. It will be renamed before publication —
it shouldn't claim "JTMS" publicly unless it implements Doyle's full
non-monotonic system, which v1 deliberately does not.
