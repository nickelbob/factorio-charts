-- Harness initialization for factorio-charts tests
-- This file is loaded by factorio-test-harness to register all tests

-- Load test files (they use the global test() and assert provided by harness)
-- Must use full paths with __modname__ prefix since we're loaded from harness context
require("__factorio-charts__/tests/surface_test")
require("__factorio-charts__/tests/line_graph_test")
require("__factorio-charts__/tests/bar_chart_test")
require("__factorio-charts__/tests/edge_cases_test")
require("__factorio-charts__/tests/animation_test")
require("__factorio-charts__/tests/interaction_test")
require("__factorio-charts__/tests/interactive_chart_test")
require("__factorio-charts__/tests/events_test")
