-- | The eDSL against the prim originals: the same toy reachability
-- | system written both ways must know the same things — and the eDSL's
-- | automatic citation must produce real premises.
module Test.RuleSpec (runRuleTests) where

import Prelude

import Control.Alternative (guard)
import Data.Array as Array
import Data.Foldable (foldl)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Console (log)
import Jtms.Engine (Engine, learn)
import Jtms.Kernel (Why(..), emptyKB, factCount, facts, justificationsFor, knownClaims)
import Jtms.Rule (each, matches, require, rule)
import Test.Assert (assert, assertEqual)
import Test.KernelSpec (Ax(..), Claim(..), Rule(..), ToyKB, primEngine)

edslEngine :: Engine Unit Claim Rule Ax
edslEngine =
  { rules:
      [ rule EdgeIsReach do
          e <- matches case _ of
            Edge a b -> Just { a, b }
            Reach _ _ -> Nothing
          pure (Reach e.a e.b)
      , rule Compose do
          first <- matches case _ of
            Reach a b -> Just { a, b }
            Edge _ _ -> Nothing
          second <- matches case _ of
            Reach a b -> Just { a, b }
            Edge _ _ -> Nothing
          guard (first.b == second.a)
          pure (Reach first.a second.b)
      ]
  , refine: \_ -> identity
  }

feedWith :: Engine Unit Claim Rule Ax -> Array (Array Claim) -> ToyKB
feedWith engine observations =
  foldl (learn engine) (emptyKB unit)
    (Array.mapWithIndex (\i claims -> { source: Observed i, claims }) observations)

chain :: Array (Array Claim)
chain = [ [ Edge "a" "b" ], [ Edge "b" "c" ], [ Edge "c" "d" ], [ Edge "b" "e" ] ]

runRuleTests :: Effect Unit
runRuleTests = do
  log "Rule eDSL: knows exactly what the prim rules know"
  do
    let primKB = feedWith primEngine chain
    let edslKB = feedWith edslEngine chain
    assertEqual { actual: factCount edslKB, expected: factCount primKB }
    assertEqual { actual: knownClaims edslKB, expected: knownClaims primKB }

  log "Rule eDSL: matches cites its facts — every derivation has premises"
  do
    let kb = feedWith edslEngine chain
    let
      derived = facts kb # Array.filter \f -> case f.why of
        ByRule _ -> true
        Axiom _ -> false
    assert (not (Array.null derived))
    assert $ derived # Array.all \f -> case f.why of
      ByRule d -> not (Array.null d.premises)
      Axiom _ -> false

  log "Rule eDSL: a Compose derivation cites exactly its two reaches"
  do
    let kb = feedWith edslEngine chain
    let
      composed = facts kb # Array.find \f -> case f.why of
        ByRule d -> d.rule == Compose
        Axiom _ -> false
    case composed of
      Nothing -> assert false
      Just f -> case f.why of
        ByRule d -> assertEqual { actual: Array.length d.premises, expected: 2 }
        Axiom _ -> assert false

  log "Kernel: rederivations are remembered — justificationsFor, primary first"
  do
    -- a -> b -> c -> d: Reach a d composes two ways ((ab·bd) and (ac·cd))
    let kb = feedWith edslEngine chain
    let js = justificationsFor (Reach "a" "d") kb
    assert (Array.length js >= 2)
    -- all alternatives are rule derivations, none an axiom
    assert $ js # Array.all case _ of
      ByRule _ -> true
      Axiom _ -> false
    -- and the record is stable: saturating again adds nothing
    let again = learn edslEngine kb { source: Observed 42, claims: [] }
    assertEqual
      { actual: Array.length (justificationsFor (Reach "a" "d") again)
      , expected: Array.length js
      }

  log "Rule eDSL: require agrees with matches"
  do
    let
      requireEngine :: Engine Unit Claim Rule Ax
      requireEngine =
        { rules:
            [ rule EdgeIsReach do
                a <- each nodes
                b <- each nodes
                require (Edge a b)
                pure (Reach a b)
            , rule Compose do
                a <- each nodes
                b <- each nodes
                c <- each nodes
                require (Reach a b)
                require (Reach b c)
                pure (Reach a c)
            ]
        , refine: \_ -> identity
        }
      nodes = [ "a", "b", "c", "d", "e" ]
    let viaRequire = feedWith requireEngine chain
    let viaMatches = feedWith edslEngine chain
    assertEqual { actual: knownClaims viaRequire, expected: knownClaims viaMatches }
