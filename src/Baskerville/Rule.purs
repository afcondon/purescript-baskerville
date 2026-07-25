-- | The rule eDSL: rule bodies as nondeterministic queries over the KB
-- | that cite their premises automatically.
-- |
-- | The ergonomic point: in prim form the author looks up and threads
-- | `FactId`s by hand, and a forgotten citation silently weakens the proof
-- | term. Here `matches` and `require` both *test* a claim and *cite* the
-- | fact recording it — the derivation writes itself.
-- |
-- | `absent` is negation as failure: sound at the fixpoint within a
-- | stratum, and it cites nothing (there is no fact to cite — that is the
-- | nature of negative knowledge in a monotone system). Stratification
-- | checking arrives with the analyzable layer; until then the client
-- | vouches, exactly as with prim rules' read-sets.
-- |
-- | This is the pragmatic monadic tier from the design sketch: fully
-- | expressive, not yet statically analyzable. The naive engine needs no
-- | read-sets; when the semi-naive engine lands, eDSL rules grow theirs by
-- | interpretation and prim rules keep declaring them.
module Baskerville.Rule
  ( RuleM
  , rule
  , each
  , matches
  , require
  , absent
  , anchor
  , askKB
  ) where

import Prelude

import Control.Alt (class Alt)
import Control.Alternative (class Alternative)
import Control.Plus (class Plus)
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Baskerville.Kernel (FactId, KB, facts, factIdFor, isKnown)
import Baskerville.Engine (Rule)

type Match axiom a = { value :: a, premises :: Array FactId, anchors :: Array axiom }

-- | A nondeterministic KB query accumulating the premises and anchors it
-- | touched along each branch.
newtype RuleM residue claim rule axiom a = RuleM
  (KB residue claim rule axiom -> Array (Match axiom a))

runRuleM
  :: forall residue claim rule axiom a
   . RuleM residue claim rule axiom a
  -> KB residue claim rule axiom
  -> Array (Match axiom a)
runRuleM (RuleM run) = run

instance Functor (RuleM residue claim rule axiom) where
  map f (RuleM run) = RuleM \kb ->
    run kb <#> \m -> { value: f m.value, premises: m.premises, anchors: m.anchors }

instance Apply (RuleM residue claim rule axiom) where
  apply (RuleM runF) (RuleM runA) = RuleM \kb -> do
    f <- runF kb
    a <- runA kb
    pure
      { value: f.value a.value
      , premises: f.premises <> a.premises
      , anchors: f.anchors <> a.anchors
      }

instance Applicative (RuleM residue claim rule axiom) where
  pure a = RuleM \_ -> [ { value: a, premises: [], anchors: [] } ]

instance Bind (RuleM residue claim rule axiom) where
  bind (RuleM run) f = RuleM \kb -> do
    m <- run kb
    m2 <- runRuleM (f m.value) kb
    pure
      { value: m2.value
      , premises: m.premises <> m2.premises
      , anchors: m.anchors <> m2.anchors
      }

instance Monad (RuleM residue claim rule axiom)

instance Alt (RuleM residue claim rule axiom) where
  alt (RuleM x) (RuleM y) = RuleM \kb -> x kb <> y kb

instance Plus (RuleM residue claim rule axiom) where
  empty = RuleM \_ -> []

instance Alternative (RuleM residue claim rule axiom)

-- | Seal a body into an engine rule. Each query result becomes one
-- | derivation of the returned claim, citing the deduplicated premises
-- | the branch touched.
rule
  :: forall residue claim rule axiom
   . Eq axiom
  => rule
  -> RuleM residue claim rule axiom claim
  -> Rule residue claim rule axiom
rule name (RuleM run) kb =
  run kb <#> \m ->
    { claim: m.value
    , rule: name
    , premises: Array.nub m.premises
    , anchors: Array.nubEq m.anchors
    }

-- | Enumerate a domain. Cites nothing.
each :: forall residue claim rule axiom a. Array a -> RuleM residue claim rule axiom a
each xs = RuleM \_ -> xs <#> \x -> { value: x, premises: [], anchors: [] }

-- | Match a pattern against the feed: one branch per fact whose claim
-- | projects, each citing that fact. The Datalog relation scan.
matches
  :: forall residue claim rule axiom a
   . (claim -> Maybe a)
  -> RuleM residue claim rule axiom a
matches project = RuleM \kb ->
  facts kb # Array.mapMaybe \fact ->
    project fact.claim <#> \a ->
      { value: a, premises: [ fact.id ], anchors: [] }

-- | The claim must already be known; cites the fact recording it. The
-- | point lookup to `matches`' scan.
require
  :: forall residue claim rule axiom
   . Ord claim
  => claim
  -> RuleM residue claim rule axiom Unit
require claim = RuleM \kb -> case factIdFor claim kb of
  Just id -> [ { value: unit, premises: [ id ], anchors: [] } ]
  Nothing -> []

-- | Negation as failure: succeed iff the claim is not on the feed.
absent
  :: forall residue claim rule axiom
   . Ord claim
  => claim
  -> RuleM residue claim rule axiom Unit
absent claim = RuleM \kb ->
  if isKnown claim kb then []
  else [ { value: unit, premises: [], anchors: [] } ]

-- | Attach a non-fact anchor (an event id, a timestamp) to this branch's
-- | derivation.
anchor :: forall residue claim rule axiom. axiom -> RuleM residue claim rule axiom Unit
anchor axiom = RuleM \_ -> [ { value: unit, premises: [], anchors: [ axiom ] } ]

-- | The raw KB — the residue reader, and the eDSL's own small escape
-- | hatch. Reads through it cite nothing.
askKB :: forall residue claim rule axiom. RuleM residue claim rule axiom (KB residue claim rule axiom)
askKB = RuleM \kb -> [ { value: kb, premises: [], anchors: [] } ]
