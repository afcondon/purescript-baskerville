# Institutions, ologs, and the missing signature layer

*2026-08-05, after a conversation with Paul Harrington that surfaced
Spivak & Kent, [*Ologs: a categorical framework for knowledge
representation*](https://arxiv.org/abs/1102.1889) (arXiv:1102.1889,
2011) — a paper neither this repo nor `purescript-mycroft` had ever
cited. This document is the reading of that paper against what is
already built: the claim that Baskerville + Mycroft +
`baskerville-mycroft` are already an unwitting instance of a known
formalism, what that buys, and the costed verdict on a third library.
Companion to [`antecedents.md`](antecedents.md), which traces the
**consequence** lineage; this traces the **signature** one, and they
are orthogonal, which is why they had not collided before.*

**Status: nothing built, nothing committed to.** This is a design
record and a reopen-trigger sheet, written so the thread can be picked
up cold.

## 1. The paper is two papers

Two authors, two contributions, and the useful one is not the one on
the tin.

**Spivak's half — the olog.** A finite category whose objects are
boxes labelled with English types ("a man"; "a pair (x,y) where x is a
man and y is a woman and x is married to y"), whose morphisms are
labelled *functions* between them ("a man ↦ his mother"), and whose
path equations declare what commutes. An instance is a functor to
**Set**. It is a database schema that a non-specialist can author, and
the paper's own applications are that any primitive recursive function
is describable as an olog, and that ologs connect via functors.

**Kent's half — the alignment.** The last two sentences of the
abstract: *"We also show that ologs can be aligned or connected
together into a larger network using functors. The various methods of
information flow and institutions can then be used to integrate local
and global world-views."* That is Barwise–Seligman information flow
and Goguen–Burstall **institutions**.

The ologs are the famous half. The institutions are the half that
answers the question this repo has been circling.

## 2. The reading: `Oracle` is one object of an institution

An institution is: a category of signatures **Sign**; a functor
Sen : **Sign** → **Set** giving the sentences over each signature; a
functor Mod : **Sign**^op → **Cat** giving the models; and a
satisfaction relation ⊨ — all subject to the **satisfaction
condition**, that truth is invariant under change of notation.

Now `Baskerville.Conformance`:

```purescript
type Oracle world claim =
  { worlds    :: Array world
  , holds     :: world -> claim -> Boolean
  , universe  :: Array claim
  }
```

That is one object of an institution, written extensionally and by
hand. `universe` is Sen at a fixed signature; `worlds` is Mod at the
same signature; `holds` is ⊨. The signature itself is not a value in
the program — it is the client's `claim` ADT, which is to say it lives
in the type system and in the author's head, and every client
re-materialises it by hand.

Mycroft is a *second* institution: many-sorted first-order logic with
theories, sentences as s-expressions over an SMTLib signature, models
as solver-produced assignments, satisfaction decided rather than
enumerated.

And `Baskerville.Conformance.Smt` — the `baskerville-mycroft` bridge —
is an **institution comorphism**: a translation of signatures and
sentences from the first into the second, under which the instruments
mirror one for one (`entailed`, `countermodel`, `unsound`, `gap`,
`explainOr`, plus `whyEntailed` for the unsat core).

None of this was designed. It is what the code already is.

## 3. The load-bearing consequence

`baskerville-mycroft`'s headline test is the **agreement law**: on the
Sudoku chain puzzle — the largest fixture small enough to enumerate —
the SMT oracle and Baskerville's counting oracle agree on `entailed`
and `gap`, claim for claim, all 1458 of them.

**Claim: the agreement law is the satisfaction condition.** If the
encoding is presented as a comorphism rather than as hand-written
translation code, agreement is a property of the *translation*, not of
the fixture — provable once, holding for every client, at every size,
including the sizes where enumeration is impossible and the test
therefore cannot be run at all.

That is the whole argument for a signature layer, and it should be
stated as a claim to be discharged, not a fact: discharging it means
actually exhibiting the signature category and the sentence
translation, and showing the models pull back the right way. Until
that is done the reading is suggestive and no more. But note what it
would replace: today, agreement is verified precisely where it is
cheapest to verify and least likely to fail, and asserted nowhere
else.

## 4. Where the third library goes

Not "a category theory library". The concrete hole is this: for every
client, three artefacts are written by hand and are required to agree.

1. the `claim` ADT (and, in practice, a `universe` enumerator);
2. the `Oracle` — `worlds` and `holds`, i.e. a model enumerator;
3. the SMTLib encoding in the `baskerville-mycroft` bridge.

Sudoku writes all three. The meeting scheduler writes the first two.
Harmonia and ShapedSteer will write all three again. They are three
presentations of one domain, and the only thing keeping them honest is
a fixture test on the one client small enough to check.

**The third library is the presentation from which all three are
derived.** One schema declaration; `universe`, the world enumerator,
and the SMT encoding as *exports* of it. Agreement stops being tested
and starts being structural.

## 5. Build the algebraic-database variant, not raw ologs

The 2011 olog's morphisms are total, single-valued functions. A large
part of what Baskerville asserts is relational and partial — `Not cell
digit`, "could be", claims about absence. Ologs accommodate that by
promoting relations to objects (the "pair (x,y) such that…" box) plus
spans, which works, and taxes every single model you write.

Spivak's own line moved for exactly this reason: functorial data
migration, then **algebraic databases** (Schultz, Spivak,
Vasilakopoulou) — schema as a category *plus a typeside* of attribute
types — with **CQL** (Wisnesky et al.) as the practical artefact. That
is the shape to copy: entities and their morphisms on one side,
attribute types on the other. Start there; do not re-derive the 2011
ergonomics.

The migration machinery comes along for free and is worth knowing
about before it is needed: along a functor F between schemas, Δ_F is
reindexing (pull an instance back — projection/restriction), with left
adjoint Σ_F and right adjoint Π_F (the freely-adjoining and the
products-and-joins directions respectively). This is the formal
content of "your vocabulary and mine overlap; here is the translation".

## 6. Costed verdict

Against the standard set in `antecedents.md` — *no client has produced
the need* was sufficient to decline truth maintenance, and the same bar
applies here.

**It clears the bar, on three clients, two of them already built.**

- **`baskerville-mycroft`, now.** Two encodings of one domain that must
  agree, with no shared presentation to derive both from, and an
  agreement law verifiable only where enumeration is cheap. This is not
  a hypothetical client; it is the one that exists.
- **The Marginalia ⇄ Bosun seam.** Ports, servers, and start commands
  migrated out of one world-view into another. `MARGINALIA-SEAM.md`
  exists; the `/marginalia` skill still carries a "MOVED TO BOSUN"
  caveat because the two vocabularies overlap and nothing formalises
  the overlap. That is data migration along a functor, performed by
  hand and documented in prose. It is also the strongest evidence that
  Kent's half — alignment, not schemas — is the half with a live client.
- **Minard's layer/violation work.** A schema plus constraints that are
  supposed to commute, checked procedurally. Path equations are what
  that is.

**Reopen triggers, if the verdict is nevertheless to wait** (both
observable, so nothing is lost by waiting):

- *A third `claim`/`Oracle`/encoding triple written by hand* — Harmonia
  or ShapedSteer landing its SMT bridge. Three hand-written triples is
  where the duplication stops being anecdote.
- *An agreement failure, or a client too large to check.* The moment a
  bridge is written for a domain whose worlds cannot be enumerated, the
  agreement law goes untested by construction, and the fixture strategy
  has run out.

## 7. What not to build

**Do not encode institutions in PureScript's type system.** Sen and Mod
are functors out of a category of signatures, into **Set** and **Cat**
respectively. Encoding that faithfully will consume the entire budget
in the encoding and return no client value. The theory earns its keep
as *vocabulary* — it is what tells you the comorphism law is worth
stating, and where the seams belong — and it should live in the docs
and in the naming, not in the types.

The library is a schema layer with three code generators hanging off
it. The institution is the reason those three are guaranteed to agree.

## 8. Naming

In the register:

- **Commonplace** — Holmes's commonplace books, the great index volumes
  he consults to find out who a person is. That is exactly what a
  schema is: the indexed vocabulary, consulted before the deduction
  starts. Best fit if the library's centre of gravity is the schema.
- **Diogenes** — Mycroft's club: a building full of world-views
  forbidden to communicate with one another, with a Stranger's Room
  where translation is permitted. Almost too apt if the centre of
  gravity turns out to be *alignment* — a network of local ologs plus
  the functors between them.

Both keep the existing convention: the name states the thesis without
claiming membership in a family whose defining feature is omitted.

## 9. Prior art shelf (the additions)

- David I. Spivak & Robert E. Kent, *Ologs: a categorical framework for
  knowledge representation*, arXiv:1102.1889 (2011). — the source.
- Joseph Goguen & Rod Burstall, *Institutions: abstract model theory
  for specification and programming* (JACM, 1992). — Sign/Sen/Mod/⊨ and
  the satisfaction condition; the actual unifying theory.
- Jon Barwise & Jerry Seligman, *Information Flow: The Logic of
  Distributed Systems* (1997). — Kent's other half.
- David I. Spivak, *Functorial data migration* (2012); Spivak &
  Wisnesky, *Relational foundations for functorial data migration*
  (2015). — Δ / Σ / Π as query and migration.
- Patrick Schultz, David I. Spivak & Christina Vasilakopoulou,
  *Algebraic databases* (2017). — schema + typeside; the variant to
  build.
- **CQL / Categorical Query Language** (Wisnesky, Spivak, Conexus) —
  the implementation lineage; read before writing any of this.

## 10. Next actions, if picked up

1. Discharge §3 on paper before writing code: exhibit the signature,
   the sentence translation, and the model reduct for the Sudoku
   client, and check the satisfaction condition holds by construction
   against the existing 1458-claim fixture.
2. Only then design the schema surface, against **two** existing
   clients (Sudoku and the meeting scheduler), generating `universe`
   and the world enumerator. The SMT encoding is the third export and
   the real prize; it is also the one that can be deferred.
3. Keep `Baskerville.Conformance`'s `Oracle` as the interface. If the
   schema layer cannot produce a plain `Oracle` that the existing tests
   accept unchanged, the abstraction is wrong.
