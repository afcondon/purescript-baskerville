module Test.Sudoku.Main where

import Prelude

import Effect (Effect)
import Effect.Console (log)
import Test.OracleSpec (runOracleTests)
import Test.SudokuSpec (runDagScaleTest, runSudokuTests)

main :: Effect Unit
main = do
  runSudokuTests
  runDagScaleTest
  runOracleTests
  log "All jtms-sudoku tests passed."
