module Test.Jtms.Main where

import Prelude

import Effect (Effect)
import Effect.Console (log)
import Test.KernelSpec (runKernelTests)
import Test.OrderLawsSpec (runOrderLawsTests)
import Test.RuleSpec (runRuleTests)

main :: Effect Unit
main = do
  runKernelTests
  runRuleTests
  runOrderLawsTests
  log "All jtms-core tests passed."
