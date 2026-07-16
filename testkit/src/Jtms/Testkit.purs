-- | The ⊨ side of the seam: measure a rule system (⊢) against a model
-- | enumeration.
-- |
-- | The client supplies the `Oracle` — the finite set of worlds consistent
-- | with its *observations* (not with the engine's conclusions: the oracle
-- | must be independent of the thing it judges), a satisfaction relation,
-- | and the finite claim universe. Everything else is counting, which is
-- | the lesson the bettor taught: for finite universes the semantic side
-- | needs no solver.
-- |
-- | The instruments:
-- |
-- |   * `unsound`  — claims the engine believes that some world refutes.
-- |     Always empty for a sound rule set; a non-empty result is a bug
-- |     (or contradictory observations, which `worlds == []` exposes).
-- |   * `gap`      — claims true in every world that the engine has not
-- |     derived: the completeness gap, the honest number kibitzer
-- |     measured against Z3 and any client can now measure natively.
-- |   * `explainOr` — the seam made into a function: a proof, or a
-- |     countermodel, or `Underived` (the gap, pointed at one claim).
module Jtms.Testkit
  ( Oracle
  , entailed
  , countermodel
  , unsound
  , gap
  , Refutation(..)
  , explainOr
  ) where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Jtms.Explain (DerivationDag, explain)
import Jtms.Kernel (KB, isKnown, knownClaims)

type Oracle world claim =
  { worlds :: Array world
  , holds :: world -> claim -> Boolean
  , universe :: Array claim
  }

-- | True in every world. An empty world set entails nothing (rather than
-- | everything): contradictory observations should read as "no possible
-- | world", not as universal truth.
entailed :: forall world claim. Oracle world claim -> claim -> Boolean
entailed oracle claim =
  not (Array.null oracle.worlds)
    && Array.all (\w -> oracle.holds w claim) oracle.worlds

-- | A world where the claim fails, if one survives.
countermodel :: forall world claim. Oracle world claim -> claim -> Maybe world
countermodel oracle claim = Array.find (\w -> not (oracle.holds w claim)) oracle.worlds

-- | Claims the engine believes that the oracle refutes. Soundness means
-- | this is empty, on every stream, at every position.
unsound
  :: forall res world claim rule ax
   . Ord claim
  => Oracle world claim
  -> KB res claim rule ax
  -> Array claim
unsound oracle kb =
  Set.toUnfoldable (knownClaims kb)
    # Array.filter (not <<< entailed oracle)

-- | Claims true in every world that the engine has not derived — the
-- | completeness gap.
gap
  :: forall res world claim rule ax
   . Ord claim
  => Oracle world claim
  -> KB res claim rule ax
  -> Array claim
gap oracle kb =
  oracle.universe
    # Array.filter (\c -> entailed oracle c && not (isKnown c kb))

data Refutation world
  = Countermodel world
  -- | Entailed by every world, underivable by the rules: the gap,
  -- | pointed at one claim.
  | Underived
  -- | No world survives the observations at all — they contradict.
  | NoWorlds

-- | The seam: ⊢ if the engine can, else what ⊨ has to say about it.
explainOr
  :: forall res world claim rule ax
   . Ord claim
  => Oracle world claim
  -> KB res claim rule ax
  -> claim
  -> Either (Refutation world) (DerivationDag claim rule ax)
explainOr oracle kb claim = case explain claim kb of
  Just dag -> Right dag
  Nothing
    | Array.null oracle.worlds -> Left NoWorlds
    | otherwise -> Left case countermodel oracle claim of
        Just world -> Countermodel world
        Nothing -> Underived
