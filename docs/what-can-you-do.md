# What can you do with this library?

*The non-technical companion to the [introduction](introduction.md).
No prior knowledge assumed — of truth maintenance systems or, mostly,
of anything else.*

## The one-sentence version

This is a library for building software that **shows its work**: when
your program concludes something, it can hand back the complete chain
of reasons — down to the original evidence — instead of just the
answer.

If you have ever been on the receiving end of software that wouldn't
explain itself — a denied application, a mysteriously rebuilt project,
a dependency conflict with no story, a "computer says no" — you
already know the problem this library exists to solve.

## An example everyone has lived: why are we meeting at 4pm Friday?

Forget puzzles. Here is a small, real, everyday piece of reasoning.

Five people need a one-hour meeting this week. The scheduling
assistant collects constraints as they trickle in:

- Alice is on holiday Monday and Tuesday.
- Bob has standups every day at 10am.
- Carol is in a different timezone; nothing after her 5pm, which
  rules out our mornings.
- Dana's calendar shows a conflict Wednesday and Thursday afternoon.
- The meeting room is booked Friday until mid-afternoon.

Eventually the assistant announces: **Friday, 4pm.**

Every scheduling tool on earth can produce that answer. Here is what
almost none of them can produce, and what this library makes routine:

> **Friday 4pm — because it is the only slot left.**
>
> - Monday and Tuesday (all slots): Alice is on holiday.
> - Every day at 10am: Bob's standup.
> - All mornings: outside Carol's hours.
> - Wednesday and Thursday afternoon: Dana's conflict.
> - Friday until mid-afternoon: the room is booked.
>
> …which eliminates 19 of the 20 candidate slots. Each elimination
> above links to the exact calendar entry or message that caused it.

That answer is not a log that happened to be lying around. It is the
actual structure of the conclusion: in this library, "Friday 4pm" is a
fact that *carries* its reasons, and each reason is itself a fact
carrying its reasons, all the way down to the original observations.
The chain can be rendered as text, drawn as a diagram, or queried
("which of Alice's constraints actually mattered?").

And note what kind of answer it is. The interesting part was never
"Friday 4pm" — it was the nineteen *eliminations*. This library treats
the eliminations as first-class conclusions with their own stories,
because in real life, **"why not?" is asked more often than "why?"**

## The five things you actually get

### 1. Answers with receipts

Every conclusion knows which rule produced it and which earlier facts
it consumed. Ask any fact "why?" and you get the full derivation, down
to the evidence. Ask "which original inputs does this conclusion
actually depend on?" and you get exactly those — not the whole input
pile, just the ones that mattered. (In the meeting example: Bob's
standup mattered; his dentist appointment on an already-eliminated
Tuesday did not.)

### 2. "Why not?" as a first-class answer

Eliminated options — the slot that didn't work, the version that was
excluded, the candidate that was ruled out — can be recorded as real
conclusions with real reasons, not silently discarded. This is the
feature people actually want from solvers, checkers, and eligibility
systems: not "your application is denied" but the specific chain that
denied it.

### 3. What-if, by replay

The knowledge base is built by folding rules over a log of
observations. To ask "what if Carol skipped this one?" you replay the
log without Carol's constraints and see what the world looks like
then — could we have met Tuesday? What single constraint, if lifted,
would free up the most options? Undo, counterfactuals, and "what
changed between yesterday and today" all fall out of the same trick,
with no special machinery.

### 4. Honest about its limits

Sometimes rules alone can't settle a question, and most software
papers over that moment. This library ships a measuring instrument: an
independent enumeration of every scenario consistent with the
evidence, checked against what the rules concluded. That gives you two
numbers worth trusting. **Unsound** — did the rules ever conclude
something actually false? (Should be zero, and you can test that it
is.) **The gap** — what is definitely true that the rules *couldn't*
reach? So "this case needs human judgment" or "this puzzle requires
guessing" becomes something the system *knows and says*, rather than a
silent wrong answer or an infinite spinner. And when a question is
unsettled, the library tells you *which kind* of unsettled: here's a
scenario where it's false — versus — it's true in every scenario, but
beyond these rules.

### 5. Who knew what, when

Every fact is stamped with the observation that triggered it, so the
feed doubles as an audit trail: not just why the system believes
something, but when it started believing it and what event set off the
chain. And because conclusions only ever accumulate, you can run
several minds over different portions of the same event stream — what
the public saw versus what the insider saw — and compare them, with a
guarantee that whoever saw more, knows more.

## Where this shines

The pattern to look for: **facts arrive over time, rules draw
conclusions, and a human eventually asks "why?" or "why not?"** Some
places that pattern lives:

**Eligibility and policy decisions.** Benefits, visas, refunds,
insurance claims, access control. The rules are usually simple; the
value is entirely in the explanation — "denied because X, which
follows from Y and Z" — and in the audit trail behind each decision.

**Build systems and pipelines.** "Why did this target rebuild?" is
the perennial most-wanted feature of every build tool. A build's
staleness reasoning is facts (what changed) plus rules (what depends
on what); this library is the evidence store that makes the answer a
lookup instead of an archaeology dig.

**Dependency and version solving.** When installation fails, the only
useful output is the narrative of exclusions that cornered the solver
— the feature that made Dart's PubGrub famous. Candidate versions are
options; constraints eliminate them with reasons; the failure story
writes itself.

**Watching a game, or any unfolding situation.** The library's
original client watches Cluedo being played and deduces who holds
what, from the seat of each player — the deduction chains, and who
could know what when, are the entertainment. The same shape fits
election-night calls ("this seat is decided because…"), sports
eliminations ("mathematically out of the playoffs because…"), or any
running commentary on accumulating evidence.

**Teaching and assistance.** A solver that just answers is a spoiler;
one that explains is a tutor. The bundled example solves Sudoku this
way — every placed digit and every crossed-out pencil mark carries its
justification — and the same applies to any assistant whose user
should *learn* from the answer rather than obey it.

**Checking and linting.** Style checkers, counterpoint rules in
music, code review bots, compliance checks. A verdict with a
derivation names the exact offending elements and the rule that
condemned them; a verdict without one is a nag.

**Diagnosis and troubleshooting.** "Why is the wifi down", "why did
the alert fire", "which component failure explains these symptoms" —
domains where the reasoning chain from symptoms to conclusion *is* the
deliverable, and where "the evidence so far is consistent with these
three scenarios" (the honest-limits instrument) is exactly the right
kind of partial answer.

## What it is not for

Equally practical: the shapes where you'd fight the library.

- **You only want the answer, fast.** If nobody will ever ask why, a
  plain solver will be simpler and quicker. The proof structure is
  the product here; if it isn't yours, don't pay for it.
- **Genuinely huge or unbounded option spaces.** The library is built
  for domains you can enumerate — slots in a week, cards in a deck,
  cells in a grid, packages in a registry. If your facts are
  arbitrary sentences over infinite domains, this is the wrong tool.
- **Probabilities.** Conclusions here are definite: entailed or not.
  "70% likely" lives naturally *alongside* this library (over the
  enumerated scenarios) but deliberately not inside it.
- **Beliefs that must be argued back and forth.** The engine only
  ever adds conclusions; it never changes its mind mid-run.
  Changed evidence is handled by replaying (see what-if, above),
  which covers most practical needs — but if you need defaults that
  get retracted in place as evidence accumulates, you need the full
  classical machinery this library deliberately omits.

## Try it in two minutes

Both examples in this document ship with the repository, runnable:

```
spago run -p baskerville-meeting     # the meeting scheduler above, for real
spago run -p baskerville-sudoku      # a Sudoku solved, one proof narrated
spago test                    # the laws, including "the rules never lie"
```

When you're ready for how it works — proof terms, the rule language,
the measuring oracle — the [introduction](introduction.md) picks up
from here. And if you're curious what the meeting scheduler looks like
as an actual program, keep reading: it's the appendix, and it fits on
a page.

## Appendix: the meeting scheduler, as code

This is the real program — `examples/meeting/` in the repository,
compiled and run to produce the output at the end. Even if you don't
read PureScript, skim it: the point is how little there is, and how
directly each piece matches the story above.

First, the vocabulary. You declare what a claim can *say* — both the
observed kind and the derived kind:

```purescript
data Day    = Mon | Tue | Wed | Thu | Fri
data Person = Alice | Bob | Carol | Dana
data Slot   = Slot Day Int    -- day and hour: Slot Fri 16 is "Fri 4pm"

data Claim
  = CantMake Person Slot      -- observed: this person can't do this slot
  | RoomBusy Slot             -- observed: the room is taken
  | Dead Slot                 -- derived: this slot is impossible
  | MeetAt Slot               -- derived: the answer

data MeetingRule = SomeoneCant | NoRoom | LastSlotStanding
```

Then the reasoning — all three rules of it. Read `matches` as "for
every recorded fact of this shape…", `require` as "…and this must
already be established…", `absent` as "…and there's no sign of
this…". The crucial part is what you *don't* see: every fact a rule
touches through `matches` and `require` is automatically cited in the
conclusion's justification. Nobody wires up the explanations; they
accumulate as a side effect of the rules simply looking at things.

```purescript
engine =
  { rules:
      [ rule SomeoneCant do
          slot <- matches case _ of
            CantMake _ slot -> Just slot
            _ -> Nothing
          pure (Dead slot)

      , rule NoRoom do
          slot <- matches case _ of
            RoomBusy slot -> Just slot
            _ -> Nothing
          pure (Dead slot)

      , rule LastSlotStanding do
          slot <- each allSlots
          absent (Dead slot)
          traverse_ (\other -> require (Dead other))
            (Array.filter (_ /= slot) allSlots)
          pure (MeetAt slot)
      ]
  , refine: \_ -> identity
  }
```

The evidence, as it trickled in — each batch tagged with where it
came from, which is the string you'll see in parentheses in the
output:

```purescript
observations =
  [ { source: "Alice's out-of-office"
    , claims: map (CantMake Alice)
        (Array.filter (\(Slot d _) -> d == Mon || d == Tue) allSlots) }
  , { source: "Bob's recurring standup"
    , claims: map (CantMake Bob)
        (Array.filter (\(Slot _ h) -> h == 10) allSlots) }
  , { source: "Carol's working hours (UTC+8)"
    , claims: map (CantMake Carol)
        (Array.filter (\(Slot _ h) -> h < 12) allSlots) }
  -- …Dana's calendar and the room bookings, same shape
  ]
```

And the whole engine run is one line — fold the observations into an
empty knowledge base:

```purescript
main = do
  let kb = foldl (learn engine) (emptyKB unit) observations
  ...   -- find the MeetAt fact and pretty-print its reasons (~40 lines)
```

Here is the actual output:

```
Fri 4pm — the only slot left standing. The other nineteen:
  Mon 9am: Alice can't make it (Alice's out-of-office); Carol can't make it (Carol's working hours (UTC+8))
  Mon 10am: Alice can't make it (Alice's out-of-office); Bob can't make it (Bob's recurring standup); Carol can't make it (Carol's working hours (UTC+8))
  Mon 2pm: Alice can't make it (Alice's out-of-office)
  Mon 4pm: Alice can't make it (Alice's out-of-office)
  Tue 9am: Alice can't make it (Alice's out-of-office); Carol can't make it (Carol's working hours (UTC+8))
  Tue 10am: Alice can't make it (Alice's out-of-office); Bob can't make it (Bob's recurring standup); Carol can't make it (Carol's working hours (UTC+8))
  Tue 2pm: Alice can't make it (Alice's out-of-office)
  Tue 4pm: Alice can't make it (Alice's out-of-office)
  Wed 9am: Carol can't make it (Carol's working hours (UTC+8))
  Wed 10am: Bob can't make it (Bob's recurring standup); Carol can't make it (Carol's working hours (UTC+8))
  Wed 2pm: Dana can't make it (Dana's calendar)
  Wed 4pm: Dana can't make it (Dana's calendar)
  Thu 9am: Carol can't make it (Carol's working hours (UTC+8))
  Thu 10am: Bob can't make it (Bob's recurring standup); Carol can't make it (Carol's working hours (UTC+8))
  Thu 2pm: Dana can't make it (Dana's calendar)
  Thu 4pm: Dana can't make it (Dana's calendar)
  Fri 9am: Carol can't make it (Carol's working hours (UTC+8)); the room is booked (Room booking system)
  Fri 10am: Bob can't make it (Bob's recurring standup); Carol can't make it (Carol's working hours (UTC+8)); the room is booked (Room booking system)
  Fri 2pm: the room is booked (Room booking system)
Resting on 19 calendar facts.
```

Three things worth noticing, because they're the library showing
through:

- **Nobody wrote that explanation.** The rules above contain no
  explanation code at all. The reasons were captured as the rules
  fired and read back out at the end.
- **Slots eliminated more than once keep every reason.** Monday 10am
  died three separate times — Alice, Bob, *and* Carol — and all three
  are remembered, not just whichever rule got there first.
- **"Resting on 19 calendar facts."** Thirty conflicts were observed;
  the proof of "Friday 4pm" actually uses nineteen of them — one per
  eliminated slot. The other eleven are redundant confirmations, and
  the library knows the difference. That's the "which inputs actually
  mattered?" question from earlier, answered by a one-line query.
