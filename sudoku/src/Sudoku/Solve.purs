-- | The solver facade: givens in, saturated knowledge base out.
module Sudoku.Solve
  ( solve
  , solveGrid
  , valueAt
  , solvedCount
  , isSolved
  ) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe, isJust)
import Jtms.Engine (learn)
import Jtms.Kernel (emptyKB)
import Sudoku.Board (Cell, Digit, Placement, allCells, parseGrid)
import Sudoku.Rules (Given(..), SudokuClaim(..), SudokuKB, engine, placedAt, view)

-- | Assert the givens as axioms and run the rules to fixpoint.
solve :: Array Placement -> SudokuKB
solve givens =
  learn engine (emptyKB unit)
    { source: Given
    , claims: map (\g -> Is g.cell g.digit) givens
    }

solveGrid :: String -> SudokuKB
solveGrid = solve <<< parseGrid

valueAt :: SudokuKB -> Cell -> Maybe Digit
valueAt kb = placedAt (view kb)

solvedCount :: SudokuKB -> Int
solvedCount kb = Array.length (Array.filter (isJust <<< valueAt kb) allCells)

isSolved :: SudokuKB -> Boolean
isSolved kb = solvedCount kb == 81
