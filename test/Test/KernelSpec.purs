-- | The kernel laws, checked on a tiny hand-fed inference system: a toy
-- | transitive-reachability client (claims `Edge a b` / `Reach a b`, one
-- | rule composing reaches). Small enough to reason about exactly; rich
-- | enough to exercise premises, saturation, and the DAG reader.
-- | Also exports the toy system itself, for Test.RuleSpec to rebuild in
-- | the eDSL and compare.
module Test.KernelSpec
  ( runKernelTests
  , Claim(..)
  , Rule(..)
  , Ax(..)
  , ToyKB
  , primEngine
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set as Set
import Effect (Effect)
import Effect.Console (log)
import Baskerville.Engine (Engine, learn, saturate)
import Baskerville.Explain (axiomsBehind, depthOf, explain)
import Baskerville.Kernel (FactId(..), KB, Why(..), addFact, emptyKB, factCount, factIdFor, facts, isKnown, knownClaims, subsumes)
import Test.Assert (assert, assertEqual)

data Claim
  = Edge String String
  | Reach String String

derive instance Eq Claim
derive instance Ord Claim

instance Show Claim where
  show = case _ of
    Edge a b -> "(Edge " <> a <> " " <> b <> ")"
    Reach a b -> "(Reach " <> a <> " " <> b <> ")"

data Rule = EdgeIsReach | Compose

derive instance Eq Rule

data Ax = Observed Int

derive instance Eq Ax

type ToyKB = KB Unit Claim Rule Ax

primEngine :: Engine Unit Claim Rule Ax
primEngine =
  { rules: [ ruleEdgeIsReach, ruleCompose ]
  , refine: \_ -> identity
  }
  where
  ruleEdgeIsReach kb = knownClaims kb # Set.toUnfoldable # Array.mapMaybe case _ of
    Edge a b ->
      Just
        { claim: Reach a b
        , rule: EdgeIsReach
        , premises: Array.fromFoldable (factIdFor (Edge a b) kb)
        , anchors: []
        }
    Reach _ _ -> Nothing

  ruleCompose kb =
    let
      reaches = knownClaims kb # Set.toUnfoldable # Array.mapMaybe case _ of
        Reach a b -> Just { a, b }
        Edge _ _ -> Nothing
    in
      do
        first <- reaches
        second <- Array.filter (\r -> r.a == first.b) reaches
        pure
          { claim: Reach first.a second.b
          , rule: Compose
          , premises:
              Array.fromFoldable (factIdFor (Reach first.a first.b) kb)
                <> Array.fromFoldable (factIdFor (Reach second.a second.b) kb)
          , anchors: []
          }

feed :: Array (Array Claim) -> ToyKB
feed observations =
  foldl (learn primEngine) (emptyKB unit)
    (Array.mapWithIndex (\i claims -> { source: Observed i, claims }) observations)

chainKB :: ToyKB
chainKB = feed [ [ Edge "a" "b" ], [ Edge "b" "c" ], [ Edge "c" "d" ] ]

runKernelTests :: Effect Unit
runKernelTests = do
  log "Kernel: saturation closes the chain a->b->c->d"
  do
    let kb = chainKB
    assert (isKnown (Reach "a" "d") kb)
    assert (isKnown (Reach "a" "c") kb)
    assert (isKnown (Reach "b" "d") kb)
    -- 3 edges, 6 reaches
    assertEqual { actual: factCount kb, expected: 9 }

  log "Kernel: hash-consing — no claim appears twice, index covers the feed"
  do
    let kb = chainKB
    let claims = map _.claim (facts kb)
    assertEqual { actual: Array.length (Array.nub claims), expected: Array.length claims }
    assertEqual { actual: Set.size (knownClaims kb), expected: factCount kb }

  log "Kernel: acyclicity by construction — every premise id < fact id"
  do
    let kb = chainKB
    assert $ facts kb # Array.all \f -> case f.why of
      Axiom _ -> true
      ByRule d -> Array.all (_ < f.id) d.premises

  log "Kernel: ids are the feed positions"
  do
    let kb = chainKB
    assert $ facts kb # Array.mapWithIndex (\i f -> f.id == FactId i) # Array.all identity

  log "Kernel: monotonicity — learning extends the feed, never rewrites it"
  do
    let before = feed [ [ Edge "a" "b" ], [ Edge "b" "c" ] ]
    let after = learn primEngine before { source: Observed 9, claims: [ Edge "c" "d" ] }
    assert (factCount after > factCount before)
    assert (after `subsumes` before)
    assert (not (before `subsumes` after))
    assertEqual
      { actual: Array.take (factCount before) (map _.claim (facts after))
      , expected: map _.claim (facts before)
      }

  log "Kernel: addFact keeps the first justification"
  do
    let kb0 = emptyKB unit :: ToyKB
    let kb1 = addFact { claim: Edge "x" "y", why: Axiom (Observed 0) } kb0
    let kb2 = addFact { claim: Edge "x" "y", why: Axiom (Observed 1) } kb1
    assertEqual { actual: factCount kb2, expected: 1 }
    assert $ case Array.head (facts kb2) of
      Just f -> case f.why of
        Axiom (Observed n) -> n == 0
        ByRule _ -> false
      Nothing -> false

  log "Explain: the DAG behind Reach a d is closed and grounded in axioms"
  do
    let kb = chainKB
    case explain (Reach "a" "d") kb of
      Nothing -> assert false
      Just dag -> do
        let nodeIds = Set.fromFoldable (map _.id dag.nodes)
        assert (Set.member dag.root nodeIds)
        assert $ Array.all (\e -> Set.member e.from nodeIds && Set.member e.to nodeIds) dag.edges
        -- nodes arrive in feed order: premises before conclusions
        assert $ dag.nodes # map _.id # \ids -> ids == Array.sort ids
        -- grounded: the axioms behind it are exactly the three edges
        let axioms = axiomsBehind (Reach "a" "d") kb
        assertEqual
          { actual: Set.fromFoldable (map _.claim axioms)
          , expected: Set.fromFoldable [ Edge "a" "b", Edge "b" "c", Edge "c" "d" ]
          }

  log "Explain: an axiom explains itself with a one-node DAG"
  do
    let kb = chainKB
    case explain (Edge "a" "b") kb of
      Nothing -> assert false
      Just dag -> do
        assertEqual { actual: Array.length dag.nodes, expected: 1 }
        assertEqual { actual: Array.length dag.edges, expected: 0 }

  log "Explain: depths — axioms 0, lifted reaches 1, composed reaches deeper"
  do
    let kb = chainKB
    let depths = depthOf kb
    let depthFor claim = fromMaybe (-1) (factIdFor claim kb >>= \id -> Map.lookup id depths)
    assertEqual { actual: depthFor (Edge "a" "b"), expected: 0 }
    assertEqual { actual: depthFor (Reach "a" "b"), expected: 1 }
    assert (depthFor (Reach "a" "d") >= 2)

  log "Engine: saturate is idempotent at the fixpoint"
  do
    let kb = chainKB
    let again = saturate primEngine (Observed 99) kb
    assertEqual { actual: factCount again, expected: factCount kb }
