-- | A transcript demo: solve a puzzle and explain one deduction.
module Sudoku.Main (main) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Console (log)
import Jtms.Explain (axiomsBehind, explain)
import Jtms.Kernel (Why(..), factCount, facts)
import Sudoku.Board (renderGrid)
import Sudoku.Fixtures (diagonalsPuzzle)
import Sudoku.Rules (SudokuClaim(..), consistent)
import Sudoku.Solve (solve, solvedCount, valueAt)

main :: Effect Unit
main = do
  let givens = diagonalsPuzzle
  let kb = solve givens
  log "puzzle:"
  log (renderGrid \c -> _.digit <$> Array.find (\g -> g.cell == c) givens)
  log ""
  log "solved:"
  log (renderGrid (valueAt kb))
  log ""
  log
    ( show (Array.length givens) <> " givens -> "
        <> show (solvedCount kb)
        <> "/81 placed, "
        <> show (factCount kb)
        <> " facts on the feed, consistent: "
        <> show (consistent kb)
    )
  case Array.find isDeducedPlacement (facts kb) of
    Nothing -> log "(no deduced placement found)"
    Just fact -> do
      log ""
      log ("first deduced placement: " <> show fact.claim <> ", " <> whyName fact.why)
      case explain fact.claim kb of
        Nothing -> pure unit
        Just dag -> do
          let ground = axiomsBehind fact.claim kb
          log
            ( "its proof: " <> show (Array.length dag.nodes) <> " facts, "
                <> show (Array.length dag.edges)
                <> " premise edges, resting on "
                <> show (Array.length ground)
                <> " givens"
            )
  where
  isDeducedPlacement fact = case fact.claim, fact.why of
    Is _ _, ByRule _ -> true
    _, _ -> false

  whyName = case _ of
    Axiom _ -> "a given"
    ByRule d -> "by " <> show d.rule
