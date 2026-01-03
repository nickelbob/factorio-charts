-- Test initialization for factorio-charts
-- Only runs if factorio-test mod is active

if script.active_mods["factorio-test"] then
    require("__factorio-test__/init")({
        "tests/surface_test",
        "tests/line_graph_test",
        "tests/bar_chart_test",
        "tests/edge_cases_test",
    })
end
