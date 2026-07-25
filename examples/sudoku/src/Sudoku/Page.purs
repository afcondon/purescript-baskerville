-- | The first visual artifact: one deduction's derivation DAG as a
-- | self-contained HTML page. Depth-layered proof rendering left-to-right
-- | (givens at depth 0, the conclusion at the far right), plus the proof's
-- | footprint on the grid itself.
module Sudoku.Page (page) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl, maximum)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set (Set)
import Data.Set as Set
import Data.String (joinWith)
import Data.Tuple (Tuple(..))
import Baskerville.Explain (DerivationDag, depthOf, explainFact)
import Baskerville.Kernel (Fact, FactId, Why(..), facts)
import Sudoku.Board (Cell(..), Digit(..), colOf, rowOf)
import Sudoku.Rules (Given, SudokuClaim(..), SudokuKB, SudokuRule(..))

type SudokuFact = Fact SudokuClaim SudokuRule Given

type SudokuDag = DerivationDag SudokuClaim SudokuRule Given

colWidth :: Int
colWidth = 168

nodeWidth :: Int
nodeWidth = 118

rowHeight :: Int
rowHeight = 30

page :: SudokuFact -> SudokuKB -> String
page root kb = pageFor kb (explainFact kb root)

pageFor :: SudokuKB -> SudokuDag -> String
pageFor kb dag =
  let
    depths = depthOf kb
    depthFor :: SudokuFact -> Int
    depthFor f = fromMaybe 0 (Map.lookup f.id depths)

    columns :: Map Int (Array SudokuFact)
    columns = foldl (\m f -> Map.insertWith (<>) (depthFor f) [ f ] m) Map.empty dag.nodes

    position :: Map FactId { x :: Int, y :: Int }
    position = foldl placeColumn Map.empty
      (Map.toUnfoldable columns :: Array (Tuple Int (Array SudokuFact)))
      where
      placeColumn acc (Tuple d column) =
        foldl
          ( \m (Tuple i f) ->
              Map.insert f.id { x: 30 + d * colWidth, y: 64 + i * rowHeight } m
          )
          acc
          (Array.mapWithIndex Tuple column)

    posFor id = fromMaybe { x: 0, y: 0 } (Map.lookup id position)

    maxDepth = fromMaybe 0 (maximum (map depthFor dag.nodes))
    tallest = fromMaybe 1
      (maximum (map Array.length (Array.fromFoldable (Map.values columns))))
    width = 60 + (maxDepth + 1) * colWidth
    height = 100 + tallest * rowHeight

    rootFact = Array.find (\f -> f.id == dag.root) dag.nodes

    svgNodes = dag.nodes # map \f ->
      let
        p = posFor f.id
        isRoot = f.id == dag.root
        extras = Array.length f.alsoWhy
      in
        "<g><rect x='" <> show p.x <> "' y='" <> show p.y
          <> "' width='" <> show nodeWidth <> "' height='22' rx='3'"
          <> " fill='" <> fillFor f <> "' stroke='" <> strokeFor f
          <> "' stroke-width='" <> (if isRoot then "2.5" else "1") <> "'/>"
          <> "<text x='" <> show (p.x + 8) <> "' y='" <> show (p.y + 15)
          <> "' class='claim'>" <> claimLabel f.claim
          <> (if extras > 0 then " <tspan class='also'>+" <> show extras <> "</tspan>" else "")
          <> "</text></g>"

    svgEdges = dag.edges # map \e ->
      let
        from = posFor e.from
        to = posFor e.to
      in
        "<line x1='" <> show (from.x + nodeWidth) <> "' y1='" <> show (from.y + 11)
          <> "' x2='" <> show to.x <> "' y2='" <> show (to.y + 11)
          <> "' stroke='#c9c9c9' stroke-width='1'/>"

    givens = dag.nodes # Array.filter \f -> case f.why of
      Axiom _ -> true
      ByRule _ -> false

    multi = dag.nodes # Array.filter (\f -> not (Array.null f.alsoWhy)) # Array.length

    headline = case rootFact of
      Just f -> claimLabel f.claim <> lastRule f
      Nothing -> "a deduction"

    title = fromMaybe "proof" (rootFact <#> \f -> claimLabel f.claim)
  in
    joinWith "\n"
      [ "<!doctype html><html><head><meta charset='utf-8'>"
      , "<title>" <> title <> " — a proof</title>"
      , "<style>"
      , "body{font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;background:#fff;color:#111;"
      , "  max-width:" <> show (max 760 (width + 60)) <> "px;margin:48px auto;padding:0 24px}"
      , "h1{font-size:44px;font-weight:700;letter-spacing:-0.02em;margin:0}"
      , "p.sub{color:#666;font-size:15px;margin:8px 0 40px}"
      , "h2{font-size:13px;text-transform:uppercase;letter-spacing:0.12em;color:#999;margin:48px 0 12px}"
      , ".claim{font:11px 'Helvetica Neue',Helvetica,sans-serif;fill:#111}"
      , ".also{fill:#d64541;font-weight:700}"
      , ".legend{font-size:12px;color:#666;margin-top:16px}"
      , ".legend span{display:inline-block;margin-right:18px}"
      , ".legend i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:6px}"
      , "</style></head><body>"
      , "<h1>" <> headline <> "</h1>"
      , "<p class='sub'>a proof of " <> show (Array.length dag.nodes) <> " facts and "
          <> show (Array.length dag.edges) <> " premise edges, resting on "
          <> show (Array.length givens) <> " givens · "
          <> show multi
          <> " of its facts are independently rederivable (marked <b style='color:#d64541'>+n</b>)</p>"
      , "<h2>The derivation, by depth</h2>"
      , "<svg width='" <> show width <> "' height='" <> show height <> "'>"
      , joinWith "\n" svgEdges
      , joinWith "\n" svgNodes
      , "</svg>"
      , "<div class='legend'>"
      , legendEntry "#f2f2f2" "#999999" "given"
      , legendEntry "#e8f0f6" "#7aa6c2" "sole digit"
      , legendEntry "#eef3ee" "#7fa87f" "peer elimination"
      , legendEntry "#fdeeed" "#d64541" "naked single"
      , legendEntry "#ececf4" "#5b5ba6" "hidden single"
      , legendEntry "#fff4e5" "#e08b2d" "alldifferent (Régin)"
      , "</div>"
      , "<h2>Where the proof lives on the grid</h2>"
      , footprintGrid kb dag
      , "<p class='legend'>shaded: cells the proof touches · outlined: the concluded cell</p>"
      , "</body></html>"
      ]
  where
  legendEntry fill stroke label =
    "<span><i style='background:" <> fill <> ";border:1px solid " <> stroke <> "'></i>"
      <> label
      <> "</span>"

  lastRule f = case f.why of
    ByRule d -> ", by " <> ruleName d.rule
    Axiom _ -> ", a given"

claimLabel :: SudokuClaim -> String
claimLabel = case _ of
  Is c d -> cellName c <> " = " <> digitLabel d
  Not c d -> cellName c <> " ≠ " <> digitLabel d

digitLabel :: Digit -> String
digitLabel (Digit d) = show d

cellName :: Cell -> String
cellName c = "r" <> show (rowOf c + 1) <> "c" <> show (colOf c + 1)

ruleName :: SudokuRule -> String
ruleName = case _ of
  SoleDigit -> "sole digit"
  PeerElimination -> "peer elimination"
  NakedSingle -> "naked single"
  HiddenSingle -> "hidden single"
  Alldifferent -> "alldifferent (Régin)"

fillFor :: SudokuFact -> String
fillFor f = case f.why of
  Axiom _ -> "#f2f2f2"
  ByRule d -> case d.rule of
    SoleDigit -> "#e8f0f6"
    PeerElimination -> "#eef3ee"
    NakedSingle -> "#fdeeed"
    HiddenSingle -> "#ececf4"
    Alldifferent -> "#fff4e5"

strokeFor :: SudokuFact -> String
strokeFor f = case f.why of
  Axiom _ -> "#999999"
  ByRule d -> case d.rule of
    SoleDigit -> "#7aa6c2"
    PeerElimination -> "#7fa87f"
    NakedSingle -> "#d64541"
    HiddenSingle -> "#5b5ba6"
    Alldifferent -> "#e08b2d"

-- | The 9×9 grid with the proof's cells shaded and the conclusion outlined.
footprintGrid :: SudokuKB -> SudokuDag -> String
footprintGrid kb dag =
  let
    cellPx = 30

    touched :: Set Cell
    touched = Set.fromFoldable (dag.nodes <#> \f -> cellOf f.claim)

    rootCell = dag.nodes # Array.find (\f -> f.id == dag.root) <#> \f -> cellOf f.claim

    valueOf :: Cell -> Maybe Digit
    valueOf c = facts kb # Array.findMap \f -> case f.claim of
      Is c' d | c' == c -> Just d
      Is _ _ -> Nothing
      Not _ _ -> Nothing

    squares = do
      r <- Array.range 0 8
      k <- Array.range 0 8
      let c = Cell (r * 9 + k)
      let x = k * cellPx + 1
      let y = r * cellPx + 1
      let
        fill
          | Just c == rootCell = "#fdeeed"
          | Set.member c touched = "#efefef"
          | otherwise = "#ffffff"
      let
        border
          | Just c == rootCell = "stroke='#d64541' stroke-width='2'"
          | otherwise = "stroke='#dddddd' stroke-width='0.5'"
      pure $
        "<rect x='" <> show x <> "' y='" <> show y <> "' width='" <> show cellPx
          <> "' height='" <> show cellPx <> "' fill='" <> fill <> "' " <> border <> "/>"
          <> case valueOf c of
            Just d ->
              "<text x='" <> show (x + 11) <> "' y='" <> show (y + 20)
                <> "' class='claim'>" <> digitLabel d <> "</text>"
            Nothing -> ""

    boxLines = do
      i <- [ 0, 3, 6, 9 ]
      [ "<line x1='" <> show (i * cellPx + 1) <> "' y1='1' x2='" <> show (i * cellPx + 1)
          <> "' y2='" <> show (9 * cellPx + 1) <> "' stroke='#999' stroke-width='1.5'/>"
      , "<line x1='1' y1='" <> show (i * cellPx + 1) <> "' x2='" <> show (9 * cellPx + 1)
          <> "' y2='" <> show (i * cellPx + 1) <> "' stroke='#999' stroke-width='1.5'/>"
      ]
  in
    "<svg width='" <> show (9 * cellPx + 2) <> "' height='" <> show (9 * cellPx + 2) <> "'>"
      <> joinWith "" squares
      <> joinWith "" boxLines
      <> "</svg>"
  where
  cellOf = case _ of
    Is c _ -> c
    Not c _ -> c
