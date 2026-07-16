-- | The engine measured against the model enumeration — every number here
-- | was discovered by running the oracle, then pinned.
module Test.OracleSpec (runOracleTests) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Console (log)
import Jtms.Testkit (Refutation(..), explainOr, gap, unsound)
import Sudoku.Board (Cell(..), Digit(..))
import Sudoku.Fixtures (blankColumnsPuzzle, chainPuzzle, gapPuzzle)
import Sudoku.Oracle (completions, oracleFor)
import Sudoku.Rules (SudokuClaim(..))
import Sudoku.Solve (solve, solvedCount)
import Test.Assert (assert, assertEqual)

runOracleTests :: Effect Unit
runOracleTests = do
  log "Oracle: the chain puzzle has one world, and the singles tier is complete on it"
  do
    let enum = completions 2000 chainPuzzle
    assert enum.exhaustive
    assertEqual { actual: Array.length enum.grids, expected: 1 }
    let oracle = oracleFor enum.grids
    let kb = solve chainPuzzle
    assertEqual { actual: unsound oracle kb, expected: [] }
    assertEqual { actual: gap oracle kb, expected: [] }

  log "Oracle: blank-columns has exactly 1728 worlds and the stall was perfect"
  do
    let enum = completions 2000 blankColumnsPuzzle
    assert enum.exhaustive
    assertEqual { actual: Array.length enum.grids, expected: 1728 }
    let oracle = oracleFor enum.grids
    let kb = solve blankColumnsPuzzle
    -- everything entailed was derived; nothing knowable was missed
    assertEqual { actual: unsound oracle kb, expected: [] }
    assertEqual { actual: gap oracle kb, expected: [] }

  log "Oracle: the gap puzzle — unique solution, singles stall, 183 entailed claims unreached"
  do
    let enum = completions 2000 gapPuzzle
    assert enum.exhaustive
    assertEqual { actual: Array.length enum.grids, expected: 1 }
    let oracle = oracleFor enum.grids
    let kb = solve gapPuzzle
    assertEqual { actual: solvedCount kb, expected: 30 }
    assertEqual { actual: unsound oracle kb, expected: [] }
    let theGap = gap oracle kb
    assertEqual { actual: Array.length theGap, expected: 183 }
    let placements = theGap # Array.filter isPlacement
    assertEqual { actual: Array.length placements, expected: 51 }

  log "Oracle: explainOr — a proof, a countermodel, or the honest Underived"
  do
    let enum = completions 2000 gapPuzzle
    let oracle = oracleFor enum.grids
    let kb = solve gapPuzzle
    -- a given proves itself
    case explainOr oracle kb (Is (Cell 2) (Digit 5)) of
      Right dag -> assertEqual { actual: Array.length dag.nodes, expected: 1 }
      Left _ -> assert false
    -- a false claim gets a countermodel
    case explainOr oracle kb (Is (Cell 2) (Digit 1)) of
      Left (Countermodel _) -> assert true
      _ -> assert false
    -- a gap claim gets the honest admission
    case gap oracle kb # Array.filter isPlacement # Array.head of
      Nothing -> assert false
      Just claim -> case explainOr oracle kb claim of
        Left Underived -> assert true
        _ -> assert false
  where
  isPlacement = case _ of
    Is _ _ -> true
    Not _ _ -> false
