module Test.Jtms.Main where

import Prelude

import Effect (Effect)
import Effect.Console (log)
import Test.KernelSpec (runKernelTests)
import Test.RuleSpec (runRuleTests)

main :: Effect Unit
main = do
  runKernelTests
  runRuleTests
  log "All jtms-core tests passed."
