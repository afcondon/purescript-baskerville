module Test.Jtms.Main where

import Prelude

import Effect (Effect)
import Effect.Console (log)
import Test.KernelSpec (runKernelTests)

main :: Effect Unit
main = do
  runKernelTests
  log "All jtms-core tests passed."
