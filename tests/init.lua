-- Test initialization for factorio-charts
-- Supports two test frameworks:
-- 1. factorio-test (FactorioTest) - Interactive in-game testing
-- 2. factorio-test-harness - Automated command-line testing
--
-- For factorio-test-harness: the harness control.lua discovers and loads
-- tests/harness_init.lua directly - we don't need to do anything here.
--
-- For factorio-test: we load the test files via their init system.

if script.active_mods["factorio-test"] then
    -- Use FactorioTest for interactive testing (requires clicking "Run Tests" in GUI)
    require("__factorio-test__/init")({
        "tests/surface_test",
        "tests/line_graph_test",
        "tests/bar_chart_test",
        "tests/edge_cases_test",
    })
end
