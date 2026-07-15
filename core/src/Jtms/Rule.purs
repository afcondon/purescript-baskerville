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
module Jtms.Rule
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
import Jtms.Kernel (FactId, KB, facts, factIdFor, isKnown)
import Jtms.Engine (Rule)

type Match ax a = { value :: a, premises :: Array FactId, anchors :: Array ax }

-- | A nondeterministic KB query accumulating the premises and anchors it
-- | touched along each branch.
newtype RuleM res claim rule ax a = RuleM
  (KB res claim rule ax -> Array (Match ax a))

runRuleM
  :: forall res claim rule ax a
   . RuleM res claim rule ax a
  -> KB res claim rule ax
  -> Array (Match ax a)
runRuleM (RuleM run) = run

instance Functor (RuleM res claim rule ax) where
  map f (RuleM run) = RuleM \kb ->
    run kb <#> \m -> { value: f m.value, premises: m.premises, anchors: m.anchors }

instance Apply (RuleM res claim rule ax) where
  apply (RuleM runF) (RuleM runA) = RuleM \kb -> do
    f <- runF kb
    a <- runA kb
    pure
      { value: f.value a.value
      , premises: f.premises <> a.premises
      , anchors: f.anchors <> a.anchors
      }

instance Applicative (RuleM res claim rule ax) where
  pure a = RuleM \_ -> [ { value: a, premises: [], anchors: [] } ]

instance Bind (RuleM res claim rule ax) where
  bind (RuleM run) f = RuleM \kb -> do
    m <- run kb
    m2 <- runRuleM (f m.value) kb
    pure
      { value: m2.value
      , premises: m.premises <> m2.premises
      , anchors: m.anchors <> m2.anchors
      }

instance Monad (RuleM res claim rule ax)

instance Alt (RuleM res claim rule ax) where
  alt (RuleM x) (RuleM y) = RuleM \kb -> x kb <> y kb

instance Plus (RuleM res claim rule ax) where
  empty = RuleM \_ -> []

instance Alternative (RuleM res claim rule ax)

-- | Seal a body into an engine rule. Each query result becomes one
-- | derivation of the returned claim, citing the deduplicated premises
-- | the branch touched.
rule
  :: forall res claim rule ax
   . Eq ax
  => rule
  -> RuleM res claim rule ax claim
  -> Rule res claim rule ax
rule name (RuleM run) kb =
  run kb <#> \m ->
    { claim: m.value
    , rule: name
    , premises: Array.nub m.premises
    , anchors: Array.nubEq m.anchors
    }

-- | Enumerate a domain. Cites nothing.
each :: forall res claim rule ax a. Array a -> RuleM res claim rule ax a
each xs = RuleM \_ -> xs <#> \x -> { value: x, premises: [], anchors: [] }

-- | Match a pattern against the feed: one branch per fact whose claim
-- | projects, each citing that fact. The Datalog relation scan.
matches
  :: forall res claim rule ax a
   . (claim -> Maybe a)
  -> RuleM res claim rule ax a
matches project = RuleM \kb ->
  facts kb # Array.mapMaybe \fact ->
    project fact.claim <#> \a ->
      { value: a, premises: [ fact.id ], anchors: [] }

-- | The claim must already be known; cites the fact recording it. The
-- | point lookup to `matches`' scan.
require
  :: forall res claim rule ax
   . Ord claim
  => claim
  -> RuleM res claim rule ax Unit
require claim = RuleM \kb -> case factIdFor claim kb of
  Just id -> [ { value: unit, premises: [ id ], anchors: [] } ]
  Nothing -> []

-- | Negation as failure: succeed iff the claim is not on the feed.
absent
  :: forall res claim rule ax
   . Ord claim
  => claim
  -> RuleM res claim rule ax Unit
absent claim = RuleM \kb ->
  if isKnown claim kb then []
  else [ { value: unit, premises: [], anchors: [] } ]

-- | Attach a non-fact anchor (an event id, a timestamp) to this branch's
-- | derivation.
anchor :: forall res claim rule ax. ax -> RuleM res claim rule ax Unit
anchor ax = RuleM \_ -> [ { value: unit, premises: [], anchors: [ ax ] } ]

-- | The raw KB — the residue reader, and the eDSL's own small escape
-- | hatch. Reads through it cite nothing.
askKB :: forall res claim rule ax. RuleM res claim rule ax (KB res claim rule ax)
askKB = RuleM \kb -> [ { value: kb, premises: [], anchors: [] } ]
