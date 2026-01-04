-- Bar chart rendering tests
local charts = require("__factorio-charts__/charts")

test("render_stacked_bars with valid data returns render IDs", function()
    local surface_data = charts.create_surface("test-bar-1")
    local chunk = charts.allocate_chunk(surface_data)

    local deliveries = {
        {loading = 30, travel = 45, unloading = 20},
        {loading = 25, travel = 50, unloading = 15},
        {loading = 40, travel = 35, unloading = 25},
    }

    local phase_colors = {
        loading = {r = 0, g = 1, b = 0},
        travel = {r = 0, g = 0, b = 1},
        unloading = {r = 1, g = 0, b = 0},
    }

    local line_ids = charts.render_stacked_bars(
        surface_data.surface, chunk, {
            deliveries = deliveries,
            phase_colors = phase_colors,
            phase_order = {"loading", "travel", "unloading"},
            ttl = 60,
        }
    )

    assert.is_table(line_ids)
    assert.is_true(#line_ids > 0)

    charts.free_chunk(surface_data, chunk)
end)

test("render_stacked_bars with empty deliveries returns nil", function()
    local surface_data = charts.create_surface("test-bar-2")
    local chunk = charts.allocate_chunk(surface_data)

    local result = charts.render_stacked_bars(
        surface_data.surface, chunk, {
            deliveries = {},
            phase_colors = {},
            phase_order = {},
            ttl = 60,
        }
    )

    assert.is_nil(result)
    charts.free_chunk(surface_data, chunk)
end)
