-- | A transcript demo (`spago run -p baskerville-sudoku`), or the explain page
-- | (`spago run -p baskerville-sudoku -- page > pages/explain.html`).
module Sudoku.Main (main) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl, maximumBy)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Traversable (for)
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Console (log)
import Baskerville.Explain (axiomsBehind, explain, explainFact)
import Baskerville.Kernel (Why(..), factCount, facts)
import Node.Process (argv)
import Sudoku.Board (Cell(..), renderGrid)
import Baskerville.Conformance (gap, unsound)
import Sudoku.Fixtures (blankColumnsPuzzle, chainPuzzle, diagonalsPuzzle, gapPuzzle)
import Sudoku.Oracle (completions, oracleFor)
import Sudoku.Page (page)
import Sudoku.Rules (SudokuClaim(..), alldifferentEngine, consistent, engine)
import Sudoku.Solve (solve, solveWith, solvedCount, valueAt)

main :: Effect Unit
main = do
  args <- argv
  case Array.drop 2 args of
    [ "page" ] -> printPage
    [ "sizes" ] -> printSizes
    [ "oracle" ] -> printOracle
    [ "hunt" ] -> printHunt
    _ -> transcript

-- | Let the oracle hunt for the completeness-gap exhibit: take a valid
-- | grid (the Nth completion of the empty puzzle), greedily remove givens
-- | while the solution stays unique, and measure what the singles tier
-- | can and cannot see. Tries several base grids and removal orders; the
-- | cyclic pattern grid's subpuzzles all proved singles-complete, so
-- | irregular grids are where the gap hides.
printHunt :: Effect Unit
printHunt = do
  let
    variants = do
      gridIx <- [ 0, 3, 7, 11 ]
      mult <- [ 37, 53 ]
      pure { gridIx, mult }
  results <- for variants \v -> do
    let baseGrids = (completions (v.gridIx + 1) []).grids
    case Array.index baseGrids v.gridIx of
      Nothing -> pure Nothing
      Just grid -> do
        let
          full = Map.toUnfoldable grid <#> \(Tuple c d) -> { cell: c, digit: d }
          order = Array.sortBy
            (comparing (\g -> case g.cell of Cell i -> (i * v.mult) `mod` 81))
            full
          keep acc g =
            let candidate = Array.filter (_ /= g) acc
            in if Array.length (completions 2 candidate).grids == 1 then candidate else acc
          minimal = foldl keep full order
          kb = solve minimal
          oracle = oracleFor (completions 2 minimal).grids
          theGap = gap oracle kb
        log
          ( "grid #" <> show v.gridIx <> " mult " <> show v.mult <> ": "
              <> show (Array.length minimal) <> " givens, singles "
              <> show (solvedCount kb) <> "/81, gap " <> show (Array.length theGap)
          )
        pure (if Array.null theGap then Nothing else Just { minimal, kb, oracle, theGap })
  case Array.head (Array.catMaybes results) of
    Nothing -> log "no gap found in these variants — singles-complete throughout"
    Just found -> do
      log ""
      log ("THE GAP EXHIBIT: " <> show (Array.length found.minimal) <> " givens")
      log (renderGrid \c -> _.digit <$> Array.find (\g -> g.cell == c) found.minimal)
      log
        ( "singles solve " <> show (solvedCount found.kb) <> "/81, unsound "
            <> show (Array.length (unsound found.oracle found.kb))
            <> ", GAP " <> show (Array.length found.theGap)
            <> " (placements: " <> show (Array.length (Array.filter isPlacement found.theGap)) <> ")"
        )
  where
  isPlacement = case _ of
    Is _ _ -> true
    Not _ _ -> false

-- | Measure the singles tier against the model enumeration: world counts,
-- | soundness, and the completeness gap, per fixture.
printOracle :: Effect Unit
printOracle = do
  let
    measure name puzzle = measureWith name engine puzzle
    measureWith name eng puzzle = do
      let enum = completions 2000 puzzle
      let oracle = oracleFor enum.grids
      let kb = solveWith eng puzzle
      log
        ( name <> ": worlds " <> show (Array.length enum.grids)
            <> (if enum.exhaustive then " (exhaustive)" else " (CAPPED)")
            <> ", solved " <> show (solvedCount kb) <> "/81"
            <> ", unsound " <> show (Array.length (unsound oracle kb))
            <> ", gap " <> show (Array.length (gap oracle kb))
        )
  measure "diagonals   " diagonalsPuzzle
  measure "chain       " chainPuzzle
  measure "blankColumns" blankColumnsPuzzle
  measureWith "gap/singles " engine gapPuzzle
  measureWith "gap/regin   " alldifferentEngine gapPuzzle

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
