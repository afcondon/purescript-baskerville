-- | The geometry: cells, digits, units, peers. No inference here.
module Sudoku.Board
  ( Cell(..)
  , Digit(..)
  , allCells
  , allDigits
  , rowOf
  , colOf
  , boxOf
  , units
  , peersOf
  , Placement
  , parseGrid
  , renderGrid
  ) where

import Prelude

import Data.Array as Array
import Data.Int as Int
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.String.CodeUnits (singleton, toCharArray)

-- | 0..80, row-major.
newtype Cell = Cell Int

derive instance Eq Cell
derive instance Ord Cell

instance Show Cell where
  show cell@(Cell i) = "r" <> show (rowOf cell + 1) <> "c" <> show (colOf cell + 1) <> "#" <> show i

-- | 1..9.
newtype Digit = Digit Int

derive instance Eq Digit
derive instance Ord Digit

instance Show Digit where
  show (Digit d) = show d

allCells :: Array Cell
allCells = map Cell (Array.range 0 80)

allDigits :: Array Digit
allDigits = map Digit (Array.range 1 9)

rowOf :: Cell -> Int
rowOf (Cell i) = i / 9

colOf :: Cell -> Int
colOf (Cell i) = i `mod` 9

boxOf :: Cell -> Int
boxOf cell = (rowOf cell / 3) * 3 + (colOf cell / 3)

-- | The 27 houses: 9 rows, 9 columns, 9 boxes.
units :: Array (Array Cell)
units = rows <> cols <> boxes
  where
  rows = map (\r -> Array.filter (\c -> rowOf c == r) allCells) (Array.range 0 8)
  cols = map (\k -> Array.filter (\c -> colOf c == k) allCells) (Array.range 0 8)
  boxes = map (\b -> Array.filter (\c -> boxOf c == b) allCells) (Array.range 0 8)

-- | The 20 cells sharing a house with this one.
peersOf :: Cell -> Array Cell
peersOf cell = Array.filter peer allCells
  where
  peer other =
    other /= cell &&
      (rowOf other == rowOf cell || colOf other == colOf cell || boxOf other == boxOf cell)

type Placement = { cell :: Cell, digit :: Digit }

-- | An 81-character grid, `.` or `0` for blanks, whitespace ignored.
parseGrid :: String -> Array Placement
parseGrid text =
  toCharArray text
    # Array.filter (\ch -> ch /= ' ' && ch /= '\n')
    # Array.mapWithIndex readCell
    # Array.catMaybes
  where
  readCell i ch = case Int.fromString (singleton ch) of
    Just d | d >= 1 && d <= 9 -> Just { cell: Cell i, digit: Digit d }
    _ -> Nothing

renderGrid :: (Cell -> Maybe Digit) -> String
renderGrid valueAt =
  String.joinWith "\n" $ map renderRow (Array.range 0 8)
  where
  renderRow r =
    String.joinWith "" $ Array.range 0 8 <#> \k ->
      case valueAt (Cell (r * 9 + k)) of
        Just (Digit d) -> show d
        Nothing -> "."
