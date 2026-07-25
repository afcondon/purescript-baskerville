-- | The Sudoku client as kernel exercise: soundness against the known
-- | grid, completeness honesty on a stalling puzzle, and the shape of the
-- | proofs.
module Test.SudokuSpec (runSudokuTests, runDagScaleTest) where

import Prelude

import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Effect (Effect)
import Effect.Console (log)
import Baskerville.Explain (axiomsBehind, explain, explainFact)
import Baskerville.Kernel (Why(..), factCount, facts, justificationsFor)
import Sudoku.Board (Cell(..), Digit(..), allCells)
import Sudoku.Fixtures (blankColumnsPuzzle, chainPuzzle, diagonalsPuzzle, patternValue)
import Sudoku.Rules (SudokuClaim(..), SudokuRule(..), consistent)
import Sudoku.Solve (isSolved, solve, solvedCount, valueAt)
import Test.Assert (assert, assertEqual)

runSudokuTests :: Effect Unit
runSudokuTests = do
  log "Sudoku: the diagonals puzzle solves completely on the singles tier"
  do
    let kb = solve diagonalsPuzzle
    assert (isSolved kb)
    assert (consistent kb)
    -- the complete closure: one placement and eight eliminations per cell
    assertEqual { actual: factCount kb, expected: 729 }

  log "Sudoku: soundness — every placement matches the generating grid"
  do
    let kb = solve diagonalsPuzzle
    assert $ allCells # Array.all \c -> valueAt kb c == Just (patternValue c)

  log "Sudoku: the chain puzzle solves fully, and its proofs have layers"
  do
    let kb = solve chainPuzzle
    assert (isSolved kb)
    assert (consistent kb)
    assert $ allCells # Array.all \c -> valueAt kb c == Just (patternValue c)
    -- at least one placement's proof rests on another deduced placement
    let
      proofSizes = facts kb # Array.mapMaybe \f -> case f.claim, f.why of
        Is _ _, ByRule _ -> Just (Array.length (explainFact kb f).nodes)
        _, _ -> Nothing
    assert (Array.any (_ > 17) proofSizes)

  log "Sudoku: honesty — the blank-columns puzzle stalls, soundly"
  do
    let kb = solve blankColumnsPuzzle
    assert (not (isSolved kb))
    assertEqual { actual: solvedCount kb, expected: Array.length blankColumnsPuzzle }
    assert (consistent kb)
    -- what it did derive is still true of the generating grid
    assert $ allCells # Array.all \c -> case valueAt kb c of
      Nothing -> true
      Just d -> d == patternValue c

  log "Sudoku: prune facts are first-class — eliminations carry derivations"
  do
    let kb = solve diagonalsPuzzle
    let
      isPeerPrune fact = case fact.claim, fact.why of
        Not _ _, ByRule d -> d.rule == PeerElimination && Array.length d.premises == 1
        _, _ -> false
    assert (Array.any isPeerPrune (facts kb))

  log "Sudoku: a naked single rests on exactly eight eliminations of its cell"
  do
    let kb = solve diagonalsPuzzle
    let
      nakedSingles = facts kb # Array.filter \fact -> case fact.why of
        ByRule d -> d.rule == NakedSingle
        Axiom _ -> false
    assert (not (Array.null nakedSingles))
    assert $ nakedSingles # Array.all \fact -> case fact.claim, fact.why of
      Is cell _, ByRule d ->
        Array.length d.premises == 8 &&
          ( d.premises # Array.all \p ->
              case Array.find (\f -> f.id == p) (facts kb) of
                Just premise -> case premise.claim of
                  Not c _ -> c == cell
                  Is _ _ -> false
                Nothing -> false
          )
      _, _ -> false

  log "Sudoku: a hidden single rests on eight eliminations across its house"
  do
    let kb = solve diagonalsPuzzle
    let
      hiddenSingles = facts kb # Array.filter \fact -> case fact.why of
        ByRule d -> d.rule == HiddenSingle
        Axiom _ -> false
    assert $ hiddenSingles # Array.all \fact -> case fact.why of
      ByRule d -> Array.length d.premises == 8
      Axiom _ -> false

  log "Sudoku: one elimination, two proofs — SoleDigit and PeerElimination"
  do
    -- r1c2 is a given 2 and its neighbour r1c3 a given 3, so "r1c2 is not
    -- 3" is derivable both from its own placement and from its peer's.
    let kb = solve diagonalsPuzzle
    let cell = Cell 1
    let js = justificationsFor (Not cell (Digit 3)) kb
    assert (Array.length js >= 2)
    let
      rulesSeen = js # Array.mapMaybe case _ of
        ByRule d -> Just d.rule
        Axiom _ -> Nothing
    assert (Array.elem SoleDigit rulesSeen)
    assert (Array.elem PeerElimination rulesSeen)

  log "Sudoku: every deduction is grounded in givens alone"
  do
    let kb = solve diagonalsPuzzle
    let
      deduced = facts kb # Array.filter \fact -> case fact.why of
        ByRule _ -> true
        Axiom _ -> false
    -- spot-check the first and last deductions rather than all 665
    let picks = Array.catMaybes [ Array.head deduced, Array.last deduced ]
    assert (Array.length picks == 2)
    assert $ picks # Array.all \fact ->
      let
        ground = axiomsBehind fact.claim kb
      in
        not (Array.null ground) && Array.all isGiven ground
    where
    isGiven fact = case fact.why of
      Axiom _ -> true
      ByRule _ -> false

runDagScaleTest :: Effect Unit
runDagScaleTest = do
  log "Sudoku: acyclicity and DAG closure hold at 729 facts"
  do
    let kb = solve diagonalsPuzzle
    assert $ facts kb # Array.all \f -> case f.why of
      Axiom _ -> true
      ByRule d -> Array.all (_ < f.id) d.premises
    case Array.last (facts kb) of
      Nothing -> assert false
      Just fact -> case explain fact.claim kb of
        Nothing -> assert false
        Just dag -> do
          let ids = Set.fromFoldable (map _.id dag.nodes)
          assert $ Array.all (\e -> Set.member e.from ids && Set.member e.to ids) dag.edges
