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
  , view
  , placedAt
  , candidatesFor
  , consistent
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl, traverse_)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set (Set)
import Data.Set as Set
import Data.Tuple.Nested ((/\))
import Jtms.Engine (Engine)
import Jtms.Kernel (KB, facts)
import Jtms.Rule (absent, each, matches, require, rule)
import Sudoku.Board (Cell, Digit, allCells, allDigits, peersOf, units)

data SudokuClaim
  = Is Cell Digit
  | Not Cell Digit

derive instance Eq SudokuClaim
derive instance Ord SudokuClaim

instance Show SudokuClaim where
  show = case _ of
    Is c d -> "(Is " <> show c <> " " <> show d <> ")"
    Not c d -> "(Not " <> show c <> " " <> show d <> ")"

-- | Named so the UI can say them — the human solving vocabulary.
data SudokuRule
  = SoleDigit -- a placed cell holds no other digit
  | PeerElimination -- a placed digit is nowhere among its peers
  | NakedSingle -- eight digits eliminated: the ninth is placed
  | HiddenSingle -- a digit with one home left in a house lives there

derive instance Eq SudokuRule

instance Show SudokuRule where
  show = case _ of
    SoleDigit -> "SoleDigit"
    PeerElimination -> "PeerElimination"
    NakedSingle -> "NakedSingle"
    HiddenSingle -> "HiddenSingle"

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
