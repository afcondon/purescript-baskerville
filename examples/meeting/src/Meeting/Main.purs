-- | The what-can-you-do example: five people, twenty candidate slots,
-- | one survivor — and the announcement carries the reason every other
-- | slot died. The smallest complete client of the kernel; the appendix
-- | of docs/what-can-you-do.md walks through this file.
module Meeting.Main (main) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl, for_, traverse_)
import Data.Maybe (Maybe(..))
import Data.String (joinWith)
import Effect (Effect)
import Effect.Console (log)
import Baskerville.Engine (Engine, learn)
import Baskerville.Explain (axiomsBehind)
import Baskerville.Kernel (Fact, KB, Why(..), emptyKB, factById, factFor, facts)
import Baskerville.Rule (absent, each, matches, require, rule)

-- The vocabulary: what a claim can say ------------------------------------

data Day = Mon | Tue | Wed | Thu | Fri

derive instance Eq Day
derive instance Ord Day

data Person = Alice | Bob | Carol | Dana

derive instance Eq Person
derive instance Ord Person

-- | A candidate slot: day and hour, 24h clock.
data Slot = Slot Day Int

derive instance Eq Slot
derive instance Ord Slot

allSlots :: Array Slot
allSlots = do
  day <- [ Mon, Tue, Wed, Thu, Fri ]
  hour <- [ 9, 10, 14, 16 ]
  pure (Slot day hour)

data Claim
  = CantMake Person Slot -- observed: this person can't do this slot
  | RoomBusy Slot -- observed: the room is taken
  | Dead Slot -- derived: this slot is impossible
  | MeetAt Slot -- derived: the answer

derive instance Eq Claim
derive instance Ord Claim

-- | Rule names, so the explanation can say which rule spoke.
data MeetingRule
  = SomeoneCant
  | NoRoom
  | LastSlotStanding

derive instance Eq MeetingRule

-- | Anchors are the human-readable evidence source ("Alice's
-- | out-of-office"); claims stamped with it all the way down.
type MeetingKB = KB Unit Claim MeetingRule String

-- The rules ----------------------------------------------------------------

engine :: Engine Unit Claim MeetingRule String
engine =
  { rules:
      [ rule SomeoneCant do
          slot <- matches case _ of
            CantMake _ slot -> Just slot
            _ -> Nothing
          pure (Dead slot)
      , rule NoRoom do
          slot <- matches case _ of
            RoomBusy slot -> Just slot
            _ -> Nothing
          pure (Dead slot)
      , rule LastSlotStanding do
          slot <- each allSlots
          absent (Dead slot)
          traverse_ (\other -> require (Dead other))
            (Array.filter (_ /= slot) allSlots)
          pure (MeetAt slot)
      ]
  , refine: \_ -> identity
  }

-- The evidence, as it trickled in ------------------------------------------

observations :: Array { source :: String, claims :: Array Claim }
observations =
  [ { source: "Alice's out-of-office"
    , claims: map (CantMake Alice)
        (Array.filter (\(Slot d _) -> d == Mon || d == Tue) allSlots)
    }
  , { source: "Bob's recurring standup"
    , claims: map (CantMake Bob)
        (Array.filter (\(Slot _ h) -> h == 10) allSlots)
    }
  , { source: "Carol's working hours (UTC+8)"
    , claims: map (CantMake Carol)
        (Array.filter (\(Slot _ h) -> h < 12) allSlots)
    }
  , { source: "Dana's calendar"
    , claims: [ Wed, Thu ] >>= \d -> [ 14, 16 ] <#> \h -> CantMake Dana (Slot d h)
    }
  , { source: "Room booking system"
    , claims: [ 9, 10, 14 ] <#> \h -> RoomBusy (Slot Fri h)
    }
  ]

-- Run, and read the answer back out ----------------------------------------

main :: Effect Unit
main = do
  let kb = foldl (learn engine) (emptyKB unit) observations
  case Array.findMap answer (facts kb) of
    Nothing -> log "No slot works for everyone."
    Just slot -> do
      log (slotName slot <> " — the only slot left standing. The other nineteen:")
      for_ (Array.filter (_ /= slot) allSlots) \s ->
        for_ (factFor (Dead s) kb) \deadFact ->
          log ("  " <> slotName s <> ": " <> joinWith "; " (reasons kb deadFact))
      let evidence = axiomsBehind (MeetAt slot) kb
      log ("Resting on " <> show (Array.length evidence) <> " calendar facts.")
  where
  answer fact = case fact.claim of
    MeetAt slot -> Just slot
    _ -> Nothing

-- | Every recorded reason a slot died — the primary justification and
-- | every later rederivation, each resolved to its observed conflict and
-- | the evidence source that reported it.
reasons :: MeetingKB -> Fact Claim MeetingRule String -> Array String
reasons kb fact =
  Array.cons fact.why fact.alsoWhy
    # Array.concatMap premisesOf
    # Array.mapMaybe (\id -> factById id kb)
    # map describe
  where
  premisesOf = case _ of
    Axiom _ -> []
    ByRule r -> r.premises

  describe conflict = conflictText conflict.claim <> sourceText conflict.why

  conflictText = case _ of
    CantMake p _ -> personName p <> " can't make it"
    RoomBusy _ -> "the room is booked"
    _ -> "eliminated"

  sourceText = case _ of
    Axiom src -> " (" <> src <> ")"
    ByRule _ -> ""

-- Naming things for humans ---------------------------------------------------

slotName :: Slot -> String
slotName (Slot d h) = dayName d <> " " <> hourName h

dayName :: Day -> String
dayName = case _ of
  Mon -> "Mon"
  Tue -> "Tue"
  Wed -> "Wed"
  Thu -> "Thu"
  Fri -> "Fri"

hourName :: Int -> String
hourName h = if h < 12 then show h <> "am" else show (h - 12) <> "pm"

personName :: Person -> String
personName = case _ of
  Alice -> "Alice"
  Bob -> "Bob"
  Carol -> "Carol"
  Dana -> "Dana"
