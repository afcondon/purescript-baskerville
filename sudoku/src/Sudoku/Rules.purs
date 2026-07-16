-- | The inference system: claims, rule names, and the four singles-tier
-- | rules, all in prim form against the jtms kernel.
-- |
-- | This client opts INTO prune-facts (the sketch's open question 1):
-- | `Not cell digit` — an eliminated pencil mark — is a first-class claim
-- | with a derivation, because "why is 7 impossible here" is the whole
-- | point of an explainable solver. (Contrast Harmonia's ambiguity-first
-- | reading, which keeps its candidate residue off the feed.)
-- |
-- | The singles tier solves exactly the no-search subset of puzzles; what
-- | it cannot solve is a measurement, not a failure. Régin's alldifferent
-- | (the hatch's poster boy) joins later, once hylograph-graph grows
-- | maximum bipartite matching.
module Sudoku.Rules
  ( SudokuClaim(..)
  , SudokuRule(..)
  , Given(..)
  , SudokuKB
  , View
  , engine
  , alldifferentEngine
  , view
  , placedAt
  , candidatesFor
  , consistent
  ) where

import Prelude

import Control.Alternative (guard)
import Data.Array as Array
import Data.Foldable (foldl, traverse_)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set (Set)
import Data.Set as Set
import Data.Tuple.Nested ((/\))
import Jtms.Engine (Derivation, Engine)
import Jtms.Kernel (FactId, KB, factIdFor, facts)
import Jtms.Rule (absent, each, matches, require, rule)
import Sudoku.Board (Cell, Digit, allCells, allDigits, peersOf, units)
import Sudoku.Matching (maximumMatching, sccIds)

data SudokuClaim
  = Is Cell Digit
  | Not Cell Digit

derive instance Eq SudokuClaim
derive instance Ord SudokuClaim

instance Show SudokuClaim where
  show = case _ of
    Is c d -> "(Is " <> show c <> " " <> show d <> ")"
    Not c d -> "(Not " <> show c <> " " <> show d <> ")"

-- | Named so the UI can say them — the human solving vocabulary, plus the
-- | one algorithmic tier.
data SudokuRule
  = SoleDigit -- a placed cell holds no other digit
  | PeerElimination -- a placed digit is nowhere among its peers
  | NakedSingle -- eight digits eliminated: the ninth is placed
  | HiddenSingle -- a digit with one home left in a house lives there
  | Alldifferent -- Régin: a candidate in no maximum matching of its house

derive instance Eq SudokuRule

instance Show SudokuRule where
  show = case _ of
    SoleDigit -> "SoleDigit"
    PeerElimination -> "PeerElimination"
    NakedSingle -> "NakedSingle"
    HiddenSingle -> "HiddenSingle"
    Alldifferent -> "Alldifferent"

-- | The only axiom source: the puzzle's givens.
data Given = Given

derive instance Eq Given

instance Show Given where
  show Given = "Given"

type SudokuKB = KB Unit SudokuClaim SudokuRule Given

-- | One fold over the feed, shared by every rule in a pass.
type View =
  { placed :: Map Cell Digit
  , excluded :: Map Cell (Set Digit)
  }

view :: SudokuKB -> View
view kb = foldl step { placed: Map.empty, excluded: Map.empty } (facts kb)
  where
  step acc fact = case fact.claim of
    Is c d -> acc { placed = Map.insert c d acc.placed }
    Not c d -> acc { excluded = Map.insertWith Set.union c (Set.singleton d) acc.excluded }

placedAt :: View -> Cell -> Maybe Digit
placedAt v c = Map.lookup c v.placed

candidatesFor :: View -> Cell -> Set Digit
candidatesFor v c = case Map.lookup c v.placed of
  Just d -> Set.singleton d
  Nothing -> Set.difference (Set.fromFoldable allDigits) (exclusionsAt v c)

exclusionsAt :: View -> Cell -> Set Digit
exclusionsAt v c = fromMaybe Set.empty (Map.lookup c v.excluded)

-- | No cell claims two digits, and no placement is also excluded. False
-- | only when the givens themselves were contradictory: the rules are
-- | monotone and sound, so garbage in is the only route to garbage out.
consistent :: SudokuKB -> Boolean
consistent kb = noDoublePlacement && noContradiction
  where
  placements = facts kb # Array.mapMaybe \fact -> case fact.claim of
    Is c d -> Just (c /\ d)
    Not _ _ -> Nothing

  cells = map (\(c /\ _) -> c) placements
  noDoublePlacement = Array.length (Array.nub cells) == Array.length cells

  v = view kb
  noContradiction = placements # Array.all \(c /\ d) ->
    not (Set.member d (exclusionsAt v c))

-- | All four rules in the eDSL: `matches`/`require` cite the premises
-- | automatically, so a naked single's derivation carries its eight
-- | eliminations without anyone threading FactIds. `absent` is the
-- | negation-as-failure guard, sound at the fixpoint.
engine :: Engine Unit SudokuClaim SudokuRule Given
engine =
  { rules:
      [ rule SoleDigit do
          p <- placement
          other <- each (Array.filter (_ /= p.digit) allDigits)
          pure (Not p.cell other)
      , rule PeerElimination do
          p <- placement
          peer <- each (peersOf p.cell)
          pure (Not peer p.digit)
      , rule NakedSingle do
          c <- each allCells
          traverse_ (\d -> absent (Is c d)) allDigits
          d <- each allDigits
          traverse_ (\other -> require (Not c other)) (Array.filter (_ /= d) allDigits)
          pure (Is c d)
      , rule HiddenSingle do
          house <- each units
          d <- each allDigits
          traverse_ (\c -> absent (Is c d)) house
          c <- each house
          traverse_ (\other -> require (Not other d)) (Array.filter (_ /= c) house)
          pure (Is c d)
      ]
  , refine: \_ -> identity
  }
  where
  placement = matches case _ of
    Is c d -> Just { cell: c, digit: d }
    Not _ _ -> Nothing

-- | The singles tier plus Régin's alldifferent — the escape-hatch tier.
-- | Rule order: singles first (they own the human-vocabulary
-- | justifications), the algorithm last.
alldifferentEngine :: Engine Unit SudokuClaim SudokuRule Given
alldifferentEngine = engine { rules = Array.snoc engine.rules ruleAlldifferent }

-- | Régin (1994), the canonical global propagator, as a prim rule: a
-- | house induces a bipartite cells↔digits graph; build a maximum
-- | matching; in the square perfect-matching case an unmatched candidate
-- | edge survives in SOME maximum matching iff its endpoints share a
-- | strongly connected component of the alternating digraph — everything
-- | else is eliminated. Constitutionally inexpressible in the eDSL; this
-- | is what the hatch is FOR.
-- |
-- | Provenance is the house-level certificate: the elimination follows
-- | from exactly the `Not` facts that shaped the house's candidate graph,
-- | all cited. Sound but coarse — extracting the minimal Hall-set
-- | certificate from the SCC structure is the marked refinement.
ruleAlldifferent :: SudokuKB -> Array (Derivation SudokuClaim SudokuRule Given)
ruleAlldifferent kb = do
  let v = view kb
  house <- units
  let adjacency = Map.fromFoldable (house <#> \c -> c /\ candidatesFor v c)
  let matching = maximumMatching adjacency
  -- an imperfect matching means the observations contradict; stay silent
  -- and let the client's consistency check tell that story
  guard (Map.size matching == 9)
  let
    matchedCell d = Map.lookup d matching

    -- alternating digraph: candidate edges cell→digit, matched digit→cell
    graph :: Map RNode (Array RNode)
    graph = Map.fromFoldable
      ( (house <#> \c -> CellN c /\ map DigitN (Set.toUnfoldable (candidatesFor v c)))
          <> (allDigits <#> \d -> DigitN d /\ Array.fromFoldable (CellN <$> matchedCell d))
      )

    comp = sccIds graph

    houseNots = house # Array.concatMap \c ->
      allDigits
        # Array.filter (\d -> not (Set.member d (candidatesFor v c)))
        # Array.concatMap (\d -> cite kb (Not c d))
  c <- house
  d <- Set.toUnfoldable (candidatesFor v c)
  guard (matchedCell d /= Just c)
  guard (Map.lookup (CellN c) comp /= Map.lookup (DigitN d) comp)
  pure { claim: Not c d, rule: Alldifferent, premises: houseNots, anchors: [] }

data RNode = CellN Cell | DigitN Digit

derive instance Eq RNode
derive instance Ord RNode

cite :: SudokuKB -> SudokuClaim -> Array FactId
cite kb claim = Array.fromFoldable (factIdFor claim kb)
