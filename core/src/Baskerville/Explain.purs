-- | Reading the proof structure back out: the derivation DAG behind a
-- | claim, and the transitive closures a UI scrubs along.
-- |
-- | Everything here exploits acyclicity-by-construction (premises point at
-- | strictly smaller ids): `explain` is a single backward scan over the
-- | feed prefix ending at the root — no recursion, no visited set beyond
-- | the growing needed-set.
module Baskerville.Explain
  ( DerivationDag
  , Edge
  , explain
  , explainFact
  , supporters
  , axiomsBehind
  , depthOf
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set as Set
import Baskerville.Kernel (Fact, FactId(..), KB, Why(..), factFor, facts)

type Edge = { from :: FactId, to :: FactId }

-- | The proof behind one claim: every fact it transitively rests on
-- | (feed order — premises before conclusions), and the premise edges
-- | among them.
type DerivationDag claim rule axiom =
  { root :: FactId
  , nodes :: Array (Fact claim rule axiom)
  , edges :: Array Edge
  }

premisesOf :: forall claim rule axiom. Fact claim rule axiom -> Array FactId
premisesOf fact = case fact.why of
  Axiom _ -> []
  ByRule d -> d.premises

explain
  :: forall residue claim rule axiom
   . Ord claim
  => claim
  -> KB residue claim rule axiom
  -> Maybe (DerivationDag claim rule axiom)
explain claim kb = explainFact kb <$> factFor claim kb

-- | The DAG below a fact: scan the feed prefix backwards from the root;
-- | a fact is in the proof iff some already-needed fact cites it.
explainFact
  :: forall residue claim rule axiom
   . KB residue claim rule axiom
  -> Fact claim rule axiom
  -> DerivationDag claim rule axiom
explainFact kb root =
  let
    prefix = case root.id of FactId i -> Array.take (i + 1) (facts kb)

    collect acc fact
      | Set.member fact.id acc.needed =
          { needed: foldl (flip Set.insert) acc.needed (premisesOf fact)
          , nodes: Array.cons fact acc.nodes
          , edges:
              map (\from -> { from, to: fact.id }) (premisesOf fact) <> acc.edges
          }
      | otherwise = acc

    gathered = foldl collect
      { needed: Set.singleton root.id, nodes: [], edges: [] }
      (Array.reverse prefix)
  in
    { root: root.id, nodes: gathered.nodes, edges: gathered.edges }

-- | Direct premises of a fact, resolved.
supporters
  :: forall residue claim rule axiom
   . KB residue claim rule axiom
  -> Fact claim rule axiom
  -> Array (Fact claim rule axiom)
supporters kb fact = Array.mapMaybe lookup (premisesOf fact)
  where
  lookup id = Array.find (\f -> f.id == id) (facts kb)

-- | The observation leaves a claim ultimately rests on.
axiomsBehind
  :: forall residue claim rule axiom
   . Ord claim
  => claim
  -> KB residue claim rule axiom
  -> Array (Fact claim rule axiom)
axiomsBehind claim kb = case explain claim kb of
  Nothing -> []
  Just dag -> Array.filter isAxiom dag.nodes
  where
  isAxiom fact = case fact.why of
    Axiom _ -> true
    ByRule _ -> false

-- | Longest premise chain below each fact (axioms at 0) — the cascade's
-- | stagger order. One forward scan; premises are always already depthed.
depthOf :: forall residue claim rule axiom. KB residue claim rule axiom -> Map FactId Int
depthOf kb = foldl step Map.empty (facts kb)
  where
  step depths fact = Map.insert fact.id (depth depths fact) depths
  depth depths fact = case premisesOf fact of
    [] -> 0
    ps -> 1 + foldl (\m p -> max m (fromMaybe 0 (Map.lookup p depths))) 0 ps
