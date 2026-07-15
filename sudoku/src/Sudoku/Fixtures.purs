-- | Test and demo fixtures, generated — never hand-transcribed — from the
-- | classic shifted pattern grid, which is valid by construction.
module Sudoku.Fixtures
  ( patternValue
  , puzzleBlanking
  , diagonalsPuzzle
  , chainPuzzle
  , blankColumnsPuzzle
  ) where

import Prelude

import Data.Array as Array
import Sudoku.Board (Cell, Digit(..), Placement, allCells, colOf, rowOf)

-- | value(r,c) = ((3r + r/3 + c) mod 9) + 1 — rows shift by 3 within a
-- | band, by 1 across bands. Every row, column, and box is a permutation.
patternValue :: Cell -> Digit
patternValue c = Digit ((rowOf c * 3 + rowOf c / 3 + colOf c) `mod` 9 + 1)

-- | The pattern grid with the cells matching a predicate removed.
puzzleBlanking :: (Cell -> Boolean) -> Array Placement
puzzleBlanking blank =
  allCells
    # Array.filter (not <<< blank)
    # map (\c -> { cell: c, digit: patternValue c })

-- | Both diagonals blanked: 64 givens, singles-solvable but in waves.
diagonalsPuzzle :: Array Placement
diagonalsPuzzle = puzzleBlanking \c ->
  rowOf c == colOf c || rowOf c + colOf c == 8

-- | Both diagonals plus the subdiagonal blanked: fewer givens, so some
-- | placements can only be proved through earlier *deduced* placements —
-- | the proofs grow layers. (Whether it stays singles-solvable is an
-- | empirical fact the tests pin.)
chainPuzzle :: Array Placement
chainPuzzle = puzzleBlanking \c ->
  rowOf c == colOf c || rowOf c + colOf c == 8 || rowOf c == colOf c + 1

-- | Columns 1, 4, and 7 fully blanked: 54 givens, but every blank cell
-- | keeps three candidates and no house has a hidden single — the singles
-- | tier stalls immediately. (The puzzle is genuinely underdetermined, so
-- | stalling here is soundness, not weakness.)
blankColumnsPuzzle :: Array Placement
blankColumnsPuzzle = puzzleBlanking \c -> colOf c `mod` 3 == 0
