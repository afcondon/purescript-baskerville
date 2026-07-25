-- | Saturation under the order-theory lens: `saturate`, read at the level of
-- | CLAIM SETS (`knownClaims ∘ saturate ∘ assertAll`), is a `ClosureOperator`
-- | on the powerset lattice — extensive, monotone, idempotent. Working at the
-- | claim-set level deliberately quotients out justification choice: rule
-- | order decides which `why` a fact gets (`alsoWhy` holds the rest), but the
-- | lattice is over WHAT is believed.
-- |
-- | The laws are specific bug detectors:
-- |
-- |   * extensive  — no retraction: nothing asserted is ever lost;
-- |   * idempotent — re-saturating a saturated store is a no-op (`still?` is
-- |     cheap at the fixpoint);
-- |   * monotone   — the NEGATION-AS-FAILURE DETECTOR. A rule that concludes
-- |     from the ABSENCE of a fact breaks exactly this law: a new axiom kills
-- |     a conclusion the smaller store licensed. The final section plants
-- |     precisely such a rule and convicts it — note that extensivity and
-- |     idempotence both still PASS for the outlaw engine; monotonicity is
-- |     the one law that names the crime.
-- |
-- | The toy domain is edge/reachability over nodes 0..4 — small enough that
-- | random axiom sets exercise every rule interaction.
module Test.OrderLawsSpec
  ( runOrderLawsTests
  ) where

import Prelude

import Data.Array as Array
import Data.Array.NonEmpty (cons')
import Data.Foldable (foldl)
import Data.Maybe (Maybe(..))
import Data.Order.Closure (ClosureOperator(..), close)
import Data.Order.Laws (closureExtensive, closureIdempotent, closureMonotone)
import Data.Set (Set)
import Data.Set as Set
import Effect (Effect)
import Effect.Console (log)
import Baskerville.Engine (Engine, Rule, saturate)
import Baskerville.Kernel (KB, assertAxiom, emptyKB, facts, knownClaims)
import Test.Assert (assertTrue)
import Test.QuickCheck (class Testable, quickCheckGen')
import Test.QuickCheck.Gen (Gen, arrayOf, chooseInt, oneOf)

-- The toy domain --------------------------------------------------------------

data Claim
  = Edge Int Int
  | Reach Int Int
  | Isolated Int -- only the outlaw engine derives these

derive instance Eq Claim
derive instance Ord Claim

data RuleName = Base | Step | Naf

derive instance Eq RuleName

type ToyKB = KB Unit Claim RuleName Unit

-- | Every edge is a reach.
baseRule :: Rule Unit Claim RuleName Unit
baseRule kb = facts kb # Array.mapMaybe \f -> case f.claim of
  Edge a b -> pure { claim: Reach a b, rule: Base, premises: [ f.id ], anchors: [] }
  _ -> Nothing

-- | Reach composes with an outgoing edge.
stepRule :: Rule Unit Claim RuleName Unit
stepRule kb = do
  r <- reaches
  e <- edges
  if r.b == e.b then pure { claim: Reach r.a e.c, rule: Step, premises: [ r.id, e.id ], anchors: [] }
  else []
  where
  fs = facts kb
  reaches = fs # Array.mapMaybe \f -> case f.claim of
    Reach a b -> pure { a, b, id: f.id }
    _ -> Nothing
  edges = fs # Array.mapMaybe \f -> case f.claim of
    Edge b c -> pure { b, c, id: f.id }
    _ -> Nothing

-- | THE OUTLAW: "a node with no incoming edge is isolated" — a conclusion
-- | from absence. In a monotone store this is unretractable the moment an
-- | incoming edge arrives; the monotonicity law convicts it below.
nafRule :: Rule Unit Claim RuleName Unit
nafRule kb =
  let
    targets = facts kb # Array.mapMaybe \f -> case f.claim of
      Edge _ n -> pure n
      _ -> Nothing
  in
    Array.range 0 4 # Array.mapMaybe \n ->
      if Array.elem n targets then Nothing
      else pure { claim: Isolated n, rule: Naf, premises: [], anchors: [] }

lawfulEngine :: Engine Unit Claim RuleName Unit
lawfulEngine = { rules: [ baseRule, stepRule ], refine: \_ -> identity }

outlawEngine :: Engine Unit Claim RuleName Unit
outlawEngine = { rules: [ baseRule, stepRule, nafRule ], refine: \_ -> identity }

-- | The claim-set reading of saturation: assert everything, saturate, read
-- | back what is believed.
closureFor :: Engine Unit Claim RuleName Unit -> ClosureOperator (Set Claim)
closureFor engine = ClosureOperator \s ->
  knownClaims
    (saturate engine unit (foldl (flip (assertAxiom unit)) (emptyKB unit :: ToyKB) (Array.fromFoldable s)))

-- Generators ------------------------------------------------------------------

genClaim :: Gen Claim
genClaim = oneOf
  ( cons'
      (Edge <$> chooseInt 0 4 <*> chooseInt 0 4)
      [ Reach <$> chooseInt 0 4 <*> chooseInt 0 4 ]
  )

genClaims :: Gen (Set Claim)
genClaims = Set.fromFoldable <$> arrayOf genClaim

-- Main ------------------------------------------------------------------------

runOrderLawsTests :: Effect Unit
runOrderLawsTests = do
  log ""
  log "--- baskerville-core — saturate as a lawful ClosureOperator (order-theory) ---"
  let c = closureFor lawfulEngine

  check "extensive — no retraction: s ⊆ saturate s" $
    closureExtensive c <$> genClaims
  check "monotone — more axioms never mean fewer conclusions" $
    closureMonotone c <$> genClaims <*> genClaims
  check "idempotent — re-saturating a saturated store is a no-op" $
    closureIdempotent c <$> genClaims

  log "  • the NAF detector: an absence-guarded rule fails monotonicity alone"
  let naf = closureFor outlawEngine
  -- With no edges, everything is "isolated"…
  assertTrue (Set.member (Isolated 0) (close naf Set.empty))
  -- …and one incoming edge retracts that belief: monotonicity broken.
  assertTrue (not (closureMonotone naf Set.empty (Set.singleton (Edge 1 0))))
  -- The other two laws still hold for the outlaw — monotonicity is the
  -- specific law that names negation-as-failure.
  check "  (outlaw is still extensive…)" $
    closureExtensive naf <$> genClaims
  check "  (…and still idempotent)" $
    closureIdempotent naf <$> genClaims
  log ""

check :: forall p. Testable p => String -> Gen p -> Effect Unit
check label gen = do
  log ("  • " <> label)
  quickCheckGen' 200 gen
