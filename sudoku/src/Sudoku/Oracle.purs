-- | Sudoku's ⊨ side: enumerate the complete grids consistent with the
-- | givens. This is a solver — backtracking search, everything the
-- | monotone engine refuses to do — which is exactly why it lives on the
-- | oracle side of the seam: it judges the engine from outside, using
-- | only the observations, never the engine's conclusions.
module Sudoku.Oracle
  ( Grid
  , completions
  , oracleFor
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl, minimumBy)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Set (Set)
import Data.Set as Set
import Data.Tuple.Nested ((/\))
import Jtms.Testkit (Oracle)
import Sudoku.Board (Cell, Digit, Placement, allCells, allDigits, peersOf)
import Sudoku.Rules (SudokuClaim(..))

type Grid = Map Cell Digit

-- | All completions of the givens, up to `cap`. `exhaustive` is false when
-- | the cap cut the enumeration short — a non-exhaustive world set must
-- | not be used for entailment.
completions :: Int -> Array Placement -> { grids :: Array Grid, exhaustive :: Boolean }
completions cap givens =
  let
    start = Map.fromFoldable (givens <#> \g -> g.cell /\ g.digit)
    result = go { grids: [], truncated: false } start
  in
    { grids: result.grids, exhaustive: not result.truncated }
  where
  go acc assigned
    | Array.length acc.grids >= cap = acc { truncated = true }
    | otherwise = case bestOpenCell assigned of
        Nothing -> acc { grids = Array.snoc acc.grids assigned }
        Just { cell, candidates } ->
          foldl
            (\a d -> go a (Map.insert cell d assigned))
            acc
            (Set.toUnfoldable candidates :: Array Digit)

  -- Most-constrained open cell first; an empty candidate set fails fast.
  bestOpenCell :: Grid -> Maybe { cell :: Cell, candidates :: Set Digit }
  bestOpenCell assigned =
    allCells
      # Array.filter (\c -> not (Map.member c assigned))
      # map (\c -> { cell: c, candidates: candidatesAt assigned c })
      # minimumBy (comparing (Set.size <<< _.candidates))

  candidatesAt :: Grid -> Cell -> Set Digit
  candidatesAt assigned c =
    Set.difference (Set.fromFoldable allDigits)
      (Set.fromFoldable (Array.mapMaybe (\p -> Map.lookup p assigned) (peersOf c)))

-- | The oracle over those worlds: satisfaction is a lookup, the universe
-- | is every placement and elimination claim.
oracleFor :: Array Grid -> Oracle Grid SudokuClaim
oracleFor grids =
  { worlds: grids
  , holds: \grid -> case _ of
      Is c d -> Map.lookup c grid == Just d
      Not c d -> Map.lookup c grid /= Just d
  , universe: do
      c <- allCells
      d <- allDigits
      [ Is c d, Not c d ]
  }
