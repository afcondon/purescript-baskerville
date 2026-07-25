# Mycroft: a simple-smt port, and the SMT-backed oracle

*2026-07-25. Design record for the PureScript SMT wrapper and its
first client: extending Baskerville's oracle seam past enumerable
world-spaces, with kibitzer's Cluedo watcher as the flagship demo of
the two libraries together. Written to be built from directly — the
phases at the end are the checklist.*

## Name and shape

**Mycroft** (proposed; Andrew has veto): the smarter, sedentary
brother — he does no legwork; you bring him the facts and he
pronounces. That is exactly the ⊨ side's job description. Repo:
`purescript-mycroft`, a sibling workspace at
`/Users/afc/work/afc-work/purescript-mycroft`, with two packages:

- **`mycroft`** — the SMT wrapper proper. Zero Baskerville
  dependencies; publishable to the registry alone (there is currently
  no SMT wrapper on Pursuit).
- **`baskerville-mycroft`** — the oracle bridge. Path-dep on
  Baskerville (`../purescript-baskerville`). Lives here, not in the
  Baskerville repo, so the core stays free of process/Aff dependencies
  (same policy that keeps hylograph out).

The Cluedo demo lands in the kibitzer repo, not here.

## The model: simple-smt, explicitly not SBV

SBV's architecture — symbolic values overloading numeric classes,
observable sharing, laziness tricks, GADT-heavy typing — is exactly
the part that does not translate to strict PureScript, and none of it
is needed. The model is Iavor Diatchki's Haskell `simple-smt`: a thin
process wrapper around SMTLib2 s-expressions, smart constructors
rather than a symbolic EDSL, request/response kept in lockstep. Small
enough to hold in your head, which is the point.

## Layer stack

### 1. `Mycroft.SExpr`

```purescript
data SExpr = Atom String | List (Array SExpr)

print :: SExpr -> String
-- incremental: feed chunks, emit completed toplevel forms; handles
-- balanced parens, string literals, and |quoted symbols|
parser :: -- streaming state machine over chunked solver stdout
```

Pure, total, golden-tested. No solver needed to build or test this
layer.

### 2. `Mycroft.Solver` — the session

```purescript
newSolver :: { cmd :: String, args :: Array String, log :: Maybe (String -> Effect Unit) }
          -> Aff Solver          -- Node child_process, z3 -in -smt2
command   :: Solver -> SExpr -> Aff SExpr
stop      :: Solver -> Aff Unit
```

The simple-smt trick that makes framing trivial: immediately set
`(set-option :print-success true)`, so **every** command produces
exactly one response s-expression and requests/responses stay in
lockstep — no guessing which commands are silent. `check-sat`
responses are the atoms `sat`/`unsat`/`unknown`. Include `push`/`pop`
passthroughs and an optional wire log for debugging.

### 3. `Mycroft.SmtLib` — the typed veneer

Untyped `newtype Term = Term SExpr` with smart constructors,
simple-smt style; a phantom-typed layer can come later if it earns
its keep:

```purescript
declareEnum  :: Solver -> { name :: String, ctors :: Array String } -> Aff Sort
declareConst :: Solver -> String -> Sort -> Aff Term
declareFun   :: Solver -> String -> Array Sort -> Sort -> Aff Term
assert       :: Solver -> Term -> Aff Unit
assertNamed  :: Solver -> String -> Term -> Aff Unit   -- (assert (! t :named n))
checkSat     :: Solver -> Aff Result                   -- Sat | Unsat | Unknown
getModel     :: Solver -> Aff Model                    -- Map String Value
getUnsatCore :: Solver -> Aff (Array String)           -- the named assertions
-- term builders: eqT, neqT, distinct, andT, orT, notT, implies, ite,
-- intLit, app, var; cardinality helper: countEq (sum of ite) for
-- hand-size style constraints
```

Options set up front: `:produce-models`, `:produce-unsat-cores`.
Model parsing handles the `(define-fun name () Sort value)` shape z3
emits; enum values decode by constructor name.

### 4. `Baskerville.Oracle.Smt` — the bridge (in `baskerville-mycroft`)

The key observation that makes this clean: in Baskerville domains the
**claim universe stays finite even when the world space explodes** —
that is the library's founding restriction. SMT replaces world
*enumeration*; claim *iteration* survives. So the bridge mirrors the
testkit's instruments, one solver query per claim, `push`/`pop`
around each:

```purescript
type SmtTheory claim =
  { declare :: Array SExpr                 -- sorts, consts, domain axioms
  , encode  :: claim -> Term               -- claim as a formula
  , observe :: { name :: String, term :: Term }  -- observations, NAMED
  , universe :: Array claim                -- still finite, still yours
  }

entailed     :: Solver -> SmtTheory claim -> claim -> Aff Boolean
             -- unsat (axioms ∧ observations ∧ ¬(encode claim))
countermodel :: Solver -> SmtTheory claim -> claim -> Aff (Maybe Model)
unsound      :: Ord claim => Solver -> SmtTheory claim -> KB … -> Aff (Array claim)
gap          :: Ord claim => Solver -> SmtTheory claim -> KB … -> Aff (Array claim)
explainOr    :: -- as testkit's, with Refutation's Countermodel carrying a Model
whyEntailed  :: Solver -> SmtTheory claim -> claim -> Aff (Array String)
             -- unsat core over the NAMED observations: "which observations
             -- force this claim" — the ⊨-side twin of ⊢'s axiomsBehind
```

`whyEntailed` is the new instrument the counting oracle could never
offer, and the `UnsatCore` slot sketched in `explainOr`'s original
design finally gets its inhabitant. **Law suite**: on fixtures small
enough to enumerate (Sudoku's chain puzzle; toy Cluedo deals), the
SMT oracle and the counting oracle must agree on `entailed` and
`gap`, claim for claim. That differential is the whole trust story.

## The Cluedo demo (kibitzer + both libraries)

Theory encoding, the natural one:

- Enum sorts: `Card` (21 ctors), `Place` (one per player + `Envelope`).
- One function: `holder :: Card -> Place`.
- Domain axioms: per-player hand-size cardinality
  (`countEq holder p == handSize p`); exactly one card of each
  category in the envelope.
- Observations as **named** assertions: `Holds p c` ↦
  `holder c = p`; `Lacks p c` ↦ `holder c ≠ p`; a shown-card
  disjunction ↦ `or` over its candidates. Note the disjunctions the ⊢
  side keeps as residue are first-class assertions on the ⊨ side —
  the oracle must be independent and complete over observations, and
  now visibly is.

Demo beats (each is one screen):

1. **The gap over time** — replay a game; after each event plot
   entailed-but-underived count. The watcher-vs-Z3 story from the
   original kibitzer sessions, now running natively in the ecosystem.
2. **The countermodel as artifact** — pick any claim the watcher
   hasn't concluded; render Z3's model as a full alternate deal:
   "here is a possible world where Scarlett lacks the knife." A
   countermodel you can *look at* is the ⊨ side finally meeting the
   casebook aesthetic.
3. **Two grounding stories side by side** — for one entailed-and-
   derived claim, show `axiomsBehind` (⊢: the observations the proof
   uses) next to `whyEntailed`'s unsat core (⊨: the observations that
   force it). When they differ, the difference is itself interesting.

Acceptance: kibitzer's existing seed properties, with the agreement
law run on seeds where enumeration is tractable.

## Practicalities

- **z3 binary**: from nixpkgs, via the quartermaster purescript
  devShell (added 2026-07-25; z3 4.16.0). A homebrew z3 also lurks at
  `/opt/homebrew/bin/z3` but only as a stray transitive dep of
  homebrew llvm — it is not to be relied on (the everything-into-Nix
  sweep policy), and inside the dev shell the nix copy shadows it.
  The Solver config takes `cmd`/`args`, so cvc5 should work
  unmodified where it speaks the same subset.
- **Browser/WASM**: the official `z3-solver` npm package (Z3 compiled
  to WASM) makes an in-browser backend possible behind the same
  `Solver` interface — that is what puts live SMT inside hylograph
  demos. Deliberately **phase 5**, after the process backend proves
  the API.
- **Generic deriving** (from the type-level thread): deriving
  `declareEnum` + `encode` + `universe` from a claim ADT via
  `Generic` belongs in `baskerville-mycroft` eventually — it makes
  the bridge nearly free for any client. Not in v1; do Cluedo by
  hand first, derive the pattern from two hand-written instances
  (Cluedo + Sudoku), then generalize.

## Phases (the build checklist)

- **P0** — scaffold `purescript-mycroft`; `Mycroft.SExpr` with
  print/parse golden tests. No z3 required. *Done when: round-trip
  property + golden suite green.*
- **P1** — `Mycroft.Solver` against real z3 (print-success lockstep).
  *Done when: declare/assert/check-sat/get-model integration test
  green under the dev shell.*
- **P2** — `Mycroft.SmtLib`: veneer, named assertions, model parser,
  unsat cores. *Done when: a hand-written pigeonhole example returns
  Unsat with the expected named core.*
- **P3** — `baskerville-mycroft`: the bridge + the agreement law
  against the counting oracle on the Sudoku chain fixture. *Done
  when: `entailed`/`gap` agree claim-for-claim.*
- **P4** — the Cluedo demo in kibitzer (three beats above).
- **P5** — WASM backend for the browser. Later.

**Status 2026-07-25: P0–P5 built and green.** P0–P2 in
`purescript-mycroft` (agreement suites vs z3 4.15/4.16); P3's
agreement law holds claim-for-claim over Sudoku's full 1458-claim
universe; P4 is kibitzer's `smt-oracle/` package (native bettor
validation + the three beats; seed-42 gap is 10). P5 delivered as
`mycroft-z3-wasm`: `Mycroft.Solver` grew a transport seam
(`newSolverWith`), and the `z3-solver` npm build passes the
subprocess suite's beats in Node — `Z3_eval_smtlib2_string` state
persists across calls, so lockstep maps onto one eval per command.
Still open on the P5 line: actually *serving* it in a browser — the
pthread build needs `SharedArrayBuffer`, i.e. a cross-origin-isolated
page (COOP/COEP headers), which plain `http-server` doesn't provide;
that wiring belongs with the kibitzer-frontend SMT pane when it
comes.

## Non-goals

- SBV-style symbolic-value EDSL, quantifiers, theories beyond
  what finite-domain encodings need (enums, Int arithmetic for
  cardinality, uninterpreted functions).
- Replacing anyone's solver. The registry solver in particular
  (see `antecedents.md` and the sketch's client list) is
  domain-specific machinery with its own provenance design; the
  aspirational relationship remains *report through*, not *replace*.
