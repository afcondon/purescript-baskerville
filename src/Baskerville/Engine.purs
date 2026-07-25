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
module Baskerville.Engine
  ( Derivation
  , Rule
  , Engine
  , saturate
  , learn
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl)
import Baskerville.Kernel (FactId, KB, Why(..), addFact, assertAxiom, factCount, residue, withResidue)

-- | What a single rule may emit: a claim, under the rule's name, citing
-- | the prior facts it consumed and any non-fact anchors it drew on.
type Derivation claim rule axiom =
  { claim :: claim
  , rule :: rule
  , premises :: Array FactId
  , anchors :: Array axiom
  }

type Rule residue claim rule axiom = KB residue claim rule axiom -> Array (Derivation claim rule axiom)

-- | A client's inference system: its rules, and its residue refinement —
-- | the step that moves lattice state (candidate sets shrinking) between
-- | fact derivations. Clients with no residue pass `refine: \_ -> identity`.
type Engine residue claim rule axiom =
  { rules :: Array (Rule residue claim rule axiom)
  , refine :: KB residue claim rule axiom -> residue -> residue
  }

-- | Run the rules to fixpoint. `source` stamps every fact derived during
-- | this saturation with the processing context that triggered it — for
-- | stream clients, the event whose avalanche this is.
saturate
  :: forall residue claim rule axiom
   . Ord claim
  => Eq rule
  => Eq axiom
  => Eq residue
  => Engine residue claim rule axiom
  -> axiom
  -> KB residue claim rule axiom
  -> KB residue claim rule axiom
saturate engine source = go
  where
  go kb =
    let
      next = saturateOnce engine source kb
    in
      if factCount next == factCount kb && residue next == residue kb then next
      else go next

saturateOnce
  :: forall residue claim rule axiom
   . Ord claim
  => Eq rule
  => Eq axiom
  => Engine residue claim rule axiom
  -> axiom
  -> KB residue claim rule axiom
  -> KB residue claim rule axiom
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
  :: forall residue claim rule axiom
   . Ord claim
  => Eq rule
  => Eq axiom
  => Eq residue
  => Engine residue claim rule axiom
  -> KB residue claim rule axiom
  -> { source :: axiom, claims :: Array claim }
  -> KB residue claim rule axiom
learn engine kb { source, claims } =
  saturate engine source (foldl (flip (assertAxiom source)) kb claims)
