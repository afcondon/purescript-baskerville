-- | The two graph algorithms Régin's alldifferent filtering needs, kept
-- | self-contained so the library repo stays free of hylograph
-- | dependencies (per the sketch's repo policy). The general-ecosystem
-- | versions belong in hylograph-graph (Marginalia #59 carries the
-- | feature request); when the demos-repo validation exercises that
-- | composition, this module is what it replaces.
module Sudoku.Matching
  ( maximumMatching
  , sccIds
  ) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set (Set)
import Data.Set as Set
import Data.Tuple (Tuple(..))

-- | Maximum bipartite matching by Kuhn's augmenting paths, O(V·E) — right
-- | for the small dense graphs of a constraint house. Returns the matching
-- | right-to-left (each matched `b` with its `a`).
maximumMatching :: forall a b. Ord a => Ord b => Map a (Set b) -> Map b a
maximumMatching adjacency =
  foldl tryAugment Map.empty (Map.keys adjacency # Set.toUnfoldable :: Array a)
  where
  tryAugment matching a = case augment a Set.empty matching of
    Right matched -> matched
    Left _ -> matching

  -- Left: failed, with the visited set enlarged (threaded through the
  -- whole attempt — the essence of Kuhn's). Right: augmented matching.
  augment a visited matching =
    foldl step (Left visited) (neighbours a)
    where
    step (Right m) _ = Right m
    step (Left vis) b
      | Set.member b vis = Left vis
      | otherwise =
          let
            vis' = Set.insert b vis
          in
            case Map.lookup b matching of
              Nothing -> Right (Map.insert b a matching)
              Just a' -> case augment a' vis' matching of
                Right m' -> Right (Map.insert b a m')
                Left vis'' -> Left vis''

  neighbours a = fromMaybe [] (Set.toUnfoldable <$> Map.lookup a adjacency)

-- | Strongly connected components (Kosaraju): each node mapped to a
-- | component id. Two nodes share an id iff they lie on a common cycle.
sccIds :: forall n. Ord n => Map n (Array n) -> Map n Int
sccIds graph =
  let
    order = foldl (\st n -> finishOrder n st) { seen: Set.empty, out: [] } nodes
    grouped = foldl assign { seen: Set.empty, comp: Map.empty, next: 0 }
      (Array.reverse order.out)
  in
    grouped.comp
  where
  nodes :: Array n
  nodes = Set.toUnfoldable (Map.keys graph)

  succsIn g n = fromMaybe [] (Map.lookup n g)

  -- first pass: DFS finish order on the forward graph
  finishOrder n st
    | Set.member n st.seen = st
    | otherwise =
        let
          descended = foldl (\s m -> finishOrder m s)
            (st { seen = Set.insert n st.seen })
            (succsIn graph n)
        in
          descended { out = Array.snoc descended.out n }

  transposed :: Map n (Array n)
  transposed = foldl
    ( \acc (Tuple n succs) ->
        foldl (\a m -> Map.insertWith (<>) m [ n ] a) acc succs
    )
    Map.empty
    (Map.toUnfoldable graph :: Array (Tuple n (Array n)))

  -- second pass: sweep the reverse graph in reverse finish order
  assign st n
    | Set.member n st.seen = st
    | otherwise =
        let
          filled = fill n (st { seen = Set.insert n st.seen })
        in
          filled { next = st.next + 1 }
    where
    fill m s =
      foldl
        ( \acc m' ->
            if Set.member m' acc.seen then acc
            else fill m' (acc { seen = Set.insert m' acc.seen })
        )
        (s { comp = Map.insert m st.next s.comp })
        (succsIn transposed m)
