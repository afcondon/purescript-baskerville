-- | The saturation engine: a Kleene least fixpoint of monotone rules over
-- | the knowledge base.
-- |
-- | Rules here are in *prim form* — plain functions from the KB to derived
-- | claims. (The analyzable eDSL over a Match functor, and the semi-naive
-- | scheduling its read-sets enable, layer on top of this; the naive
-- | fixpoint below is the semantics they must agree with.)
-- |
-- | Termination is by monotonicity: rules only add claims to a finite
-- | universe, `refine` only moves the residue down its (finite) lattice,
-- | and no fact is ever retracted — so a pass that changes nothing is the
-- | fixpoint and one must come.
-- |
-- | Rule order within a pass is part of the observable spec: it decides
-- | which justification a multiply-derivable fact receives, and clients
-- | pin their feeds with golden tests.
module Jtms.Engine
  ( Derivation
  , Rule
  , Engine
  , saturate
  , learn
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl)
import Jtms.Kernel (FactId, KB, Why(..), addFact, assertAxiom, factCount, residue, withResidue)

-- | What a single rule may emit: a claim, under the rule's name, citing
-- | the prior facts it consumed and any non-fact anchors it drew on.
type Derivation claim rule ax =
  { claim :: claim
  , rule :: rule
  , premises :: Array FactId
  , anchors :: Array ax
  }

type Rule res claim rule ax = KB res claim rule ax -> Array (Derivation claim rule ax)

-- | A client's inference system: its rules, and its residue refinement —
-- | the step that moves lattice state (candidate sets shrinking) between
-- | fact derivations. Clients with no residue pass `refine: \_ -> identity`.
type Engine res claim rule ax =
  { rules :: Array (Rule res claim rule ax)
  , refine :: KB res claim rule ax -> res -> res
  }

-- | Run the rules to fixpoint. `source` stamps every fact derived during
-- | this saturation with the processing context that triggered it — for
-- | stream clients, the event whose avalanche this is.
saturate
  :: forall res claim rule ax
   . Ord claim
  => Eq res
  => Engine res claim rule ax
  -> ax
  -> KB res claim rule ax
  -> KB res claim rule ax
saturate engine source = go
  where
  go kb =
    let
      next = saturateOnce engine source kb
    in
      if factCount next == factCount kb && residue next == residue kb then next
      else go next

saturateOnce
  :: forall res claim rule ax
   . Ord claim
  => Engine res claim rule ax
  -> ax
  -> KB res claim rule ax
  -> KB res claim rule ax
saturateOnce engine source kb =
  let
    refined = withResidue (engine.refine kb) kb
    derived = Array.concatMap (\rule -> rule refined) engine.rules
  in
    foldl
      ( \acc { claim, rule, premises, anchors } ->
          addFact { claim, why: ByRule { rule, source, premises, anchors } } acc
      )
      refined
      derived

-- | Record one observation's axioms, then saturate: the fold step that
-- | makes a mind from a stream. `foldl (learn engine) kb observations`.
learn
  :: forall res claim rule ax
   . Ord claim
  => Eq res
  => Engine res claim rule ax
  -> KB res claim rule ax
  -> { source :: ax, claims :: Array claim }
  -> KB res claim rule ax
learn engine kb { source, claims } =
  saturate engine source (foldl (flip (assertAxiom source)) kb claims)
