# Baskerville: antecedents, and the truth-maintenance verdict

*2026-07-25. The design record behind the rename from the working name
`purescript-jtms`, and the argued decision NOT to implement truth
maintenance proper. Companion to the extensions catalogue in
[`library-sketch.md`](library-sketch.md) (row #6) — this document
closes that row's naming gate the other way.*

## The name

The Haskell propagator shelf already has `holmes`; Baskerville is the
casebook. The library's thesis is that the deliverable is the
written-up derivation — renderable, queryable, testable — not the
deduction alone, and the name should say so without claiming
membership in a family whose defining feature (belief revision) it
deliberately omits.

## What Baskerville keeps from the TMS tradition

The core move of Doyle's JTMS (1979) and de Kleer's ATMS (1986):
don't record beliefs — record beliefs paired with the reason you hold
them. Baskerville keeps that entirely: facts as proof terms, the
hash-consed derivation DAG, all-justifications recording, provenance
anchors. What the tradition used as bookkeeping for retraction,
Baskerville promotes to the product.

## The verdict: why no truth maintenance

The "TM" in TMS is labels that can flip — IN/OUT states over the
justification network, revised as evidence changes. Considered
carefully (2026-07-25) and declined, on three grounds:

1. **Monotonicity is the feature, not the limitation.** A mind is a
   `foldl` over observations; same log, same feed; golden tests pin
   behavior; `subsumes` is an unconditional law; the oracle measures
   completeness from outside; counterfactuals are free. Every one of
   those properties is a consequence of monotonicity. Labels that
   flip would trade away exactly what makes the library trustworthy.

2. **In this architecture, truth maintenance is just incremental
   replay.** What TM does on revision — flip labels, propagate
   withdrawal through the affected cone — replay does by re-running
   the fold without the retracted observation. For stratified rule
   sets the answers are identical; TM's only advantage is doing less
   work per revision. At these KB sizes replay is milliseconds, so TM
   would be paying the extensions catalogue's worst ease-of-use row
   to speed up an operation that is not slow. The only *expressive*
   addition is choice among admissible belief states (even loops,
   defaults-as-decisions) — and no client has produced one.

3. **Every client landed monotone.** Cluedo, Sudoku, the meeting
   scheduler; Harmonia's linter, build staleness, version solving as
   designed — all naturally stratified, all monotone-per-replay.

**Reopen triggers** — both observable, so nothing is lost by waiting:

- *Replay cost*: a client (long-running rig, large graph) where
  re-folding on revision is measurably too slow. TM is fundamentally
  an incremental-computation optimisation; that is when it earns it.
- *Expressiveness*: a client with a genuinely non-stratified rule set
  — defaults that need choice, not just absence-at-fixpoint.

**If a trigger fires, the shape is known.** Doyle's system is monotone
one level up — justifications are never removed; only labels change —
so a label layer can be additive: a separate package computing labels
as a view over the append-only network, with a conservativity law (no
out-lists ⇒ identical to today) as the seam, and the well-founded
semantics via alternating fixpoint (two nested monotone fixpoints;
loops degrade to Unknown) preferred over Doyle's choice-making
algorithm. Two kernel accommodations would be wanted — justification
lists instead of `why`/`alsoWhy`, and nodes that can exist unjustified
so out-lists can cite them — and whether core absorbs those or the
label package defines its own network type is a decision to make
against the real client, not before.

## Where the rest of the TMS went

The TMS didn't survive as a thing; it was dismembered, and each organ
was transplanted into a lineage that did it better. Acknowledging
antecedents honestly means knowing which shelf each piece now lives
on:

- **The labelling semantics → logic programming.** Doyle's IN/OUT
  machinery was procedural; Elkan (1990) reconstructed JTMS
  labellings as the stable models (Gelfond & Lifschitz 1988) of the
  network read as a logic program, with the well-founded semantics
  (Van Gelder–Ross–Schlipf 1991) as the deterministic three-valued
  cousin. The industrial descendant is Answer Set Programming
  (clingo, DLV). Want defaults-with-choice today? Use ASP.
- **Dependency-directed backtracking → CDCL.** DDB predates Doyle
  (Stallman & Sussman 1977, the EL circuit analyzer); its
  nogood-recording idea became conflict-driven clause learning in SAT
  (GRASP 1996, Chaff 2001). The TMS's third pillar runs today inside
  every SAT/SMT solver, engineered beyond recognition.
- **ATMS labels → provenance semirings.** De Kleer's
  assumption-environment labels got their mature algebraic form in
  database theory: provenance semirings (Green, Karvounarakis &
  Tannen 2007) — Datalog derivations annotated over a semiring, with
  why-provenance as the Boolean instance. The one neighbour most
  worth reading against Baskerville's own justification structure.
  (The other ATMS descendants: knowledge compilation, and model-based
  diagnosis.)
- **Prolog: mostly no, with one exception.** Vanilla Prolog memoizes
  and maintains nothing. Tabled Prolog (XSB, SLG resolution) computes
  the well-founded semantics with dependency-tracked tables, and its
  incremental tabling is truth maintenance done properly,
  query-side. s(CASP) ships justification trees — one of the few
  moderns treating the why as product.
- **The maintenance half → incremental computation.** Materialized
  view maintenance (DRed, counting), differential dataflow, Adapton,
  salsa, Build Systems à la Carte: don't maintain beliefs with a
  bespoke labelling algorithm, make recomputation itself incremental.
  This is the replay-equivalence argument, industrialized. The living
  fossil: Rete-lineage rule engines (Drools) still embed an actual
  JTMS (`insertLogical`) in production today.
- **What nobody took: the explanations.** Every successor absorbed
  the mechanics and buried them as plumbing — CDCL burns nogoods as
  fuel, view maintenance keeps the view and discards the why.
  Explanations resurface only at the margins (unsat cores, PubGrub's
  narratives, s(CASP), provenance research). The derivation DAG as
  the deliverable is the piece still lying unclaimed on the table,
  and it is the piece Baskerville is built on.

## Prior art shelf (the additions)

Beyond the shelf in `library-sketch.md`:

- Charles Elkan, *A rational reconstruction of nonmonotonic truth
  maintenance systems* (AIJ, 1990).
- Gelfond & Lifschitz, *The stable model semantics for logic
  programming* (1988); Van Gelder, Ross & Schlipf, *The well-founded
  semantics for general logic programs* (1991).
- Stallman & Sussman, *Forward reasoning and dependency-directed
  backtracking* (1977).
- Green, Karvounarakis & Tannen, *Provenance semirings* (PODS 2007).
- Chen & Warren, *Tabled evaluation with delaying for general logic
  programs* (1996) — SLG resolution, XSB.
