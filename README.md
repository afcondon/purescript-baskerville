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

**Status: design.** The sketch is
[`docs/library-sketch.md`](docs/library-sketch.md) — the layer stack
(proof-term kernel, analyzable rule eDSL with a declared-read-set
escape hatch, perspectives, oracle seam), the sets-vs-lattices carrier
decision, and the extensions catalogue (windows, negation, Doyle,
ATMS) with costed verdicts.

**On the name**: a working name. It will be renamed before publication —
it shouldn't claim "JTMS" publicly unless it implements Doyle's full
non-monotonic system, which v1 deliberately does not.
