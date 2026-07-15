-- | A transcript demo (`spago run -p jtms-sudoku`), or the explain page
-- | (`spago run -p jtms-sudoku -- page > pages/explain.html`).
module Sudoku.Main (main) where

import Prelude

import Data.Array as Array
import Data.Foldable (maximumBy)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Console (log)
import Jtms.Explain (axiomsBehind, explain, explainFact)
import Jtms.Kernel (Why(..), factCount, facts)
import Node.Process (argv)
import Sudoku.Board (renderGrid)
import Sudoku.Fixtures (chainPuzzle, diagonalsPuzzle)
import Sudoku.Page (page)
import Sudoku.Rules (SudokuClaim(..), consistent)
import Sudoku.Solve (solve, solvedCount, valueAt)

main :: Effect Unit
main = do
  args <- argv
  case Array.drop 2 args of
    [ "page" ] -> printPage
    [ "sizes" ] -> printSizes
    _ -> transcript

-- | The proof-size distribution over all deduced placements — the picker's
-- | instrument panel.
printSizes :: Effect Unit
printSizes = do
  let kb = solve chainPuzzle
  let
    sizes = facts kb # Array.mapMaybe \f -> case f.claim, f.why of
      Is _ _, ByRule _ -> Just (Array.length (explainFact kb f).nodes)
      _, _ -> Nothing
  log (show (Array.sort sizes))

-- | The most interesting explainable placement: the deduced `Is` whose
-- | proof is largest while still labelable (≤ 60 facts).
printPage :: Effect Unit
printPage = do
  let kb = solve chainPuzzle
  let
    deduced = facts kb # Array.filter \f -> case f.claim, f.why of
      Is _ _, ByRule _ -> true
      _, _ -> false
    sized = deduced <#> \f -> { f, n: Array.length (explainFact kb f).nodes }
    pick = case maximumBy (comparing _.n) (Array.filter (\s -> s.n <= 60) sized) of
      Just best -> Just best.f
      Nothing -> _.f <$> Array.head sized
  case pick of
    Nothing -> log "no deduced placement to explain"
    Just f -> log (page f kb)

transcript :: Effect Unit
transcript = do
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
