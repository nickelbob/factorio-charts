-- Edge case and regression tests
local charts = require("charts")

test("line graph handles flat data (min == max)", function()
    local surface_data = charts.create_surface("test-edge-1")
    local chunk = charts.allocate_chunk(surface_data)

    -- All values are 50
    local data = {}
    for i = 1, 10 do
        data[i] = {series1 = 50}
    end

    local ordered_sums, line_ids = charts.render_line_graph(
        surface_data.surface, chunk, {
            data = data,
            index = 0,
            length = 10,
            counts = {series1 = 10},
            sum = {series1 = 500},
            ttl = 60,
        }
    )

    -- Should not crash, should return valid results
    assert.is_table(ordered_sums)
    assert.is_table(line_ids)

    charts.free_chunk(surface_data, chunk)
end)

test("line graph handles sparse ring buffer", function()
    local surface_data = charts.create_surface("test-edge-2")
    local chunk = charts.allocate_chunk(surface_data)

    -- Only some slots have data
    local data = {
        [1] = {series1 = 10},
        [5] = {series1 = 50},
        [10] = {series1 = 30},
    }

    local ordered_sums, line_ids = charts.render_line_graph(
        surface_data.surface, chunk, {
            data = data,
            index = 0,
            length = 10,
            counts = {series1 = 3},
            sum = {series1 = 90},
            ttl = 60,
        }
    )

    assert.is_table(ordered_sums)
    charts.free_chunk(surface_data, chunk)
end)

test("bar chart handles zero durations", function()
    local surface_data = charts.create_surface("test-edge-3")
    local chunk = charts.allocate_chunk(surface_data)

    local deliveries = {
        {loading = 0, travel = 0, unloading = 0},
    }

    local line_ids = charts.render_stacked_bars(
        surface_data.surface, chunk, {
            deliveries = deliveries,
            phase_colors = {
                loading = {r = 0, g = 1, b = 0},
                travel = {r = 0, g = 0, b = 1},
                unloading = {r = 1, g = 0, b = 0},
            },
            phase_order = {"loading", "travel", "unloading"},
            ttl = 60,
        }
    )

    -- Should handle gracefully (max_total becomes 1)
    assert.is_table(line_ids)
    charts.free_chunk(surface_data, chunk)
end)

test("colors wrap correctly for > 12 series", function()
    local c1 = charts.get_series_color(1)
    local c13 = charts.get_series_color(13)
    local c25 = charts.get_series_color(25)

    assert.same(c1, c13)
    assert.same(c1, c25)
end)

test("format utilities handle edge values", function()
    -- Zero values
    assert.equals("0s", charts.format_time_label(0))
    assert.equals("0%", charts.format_percent_label(0))

    -- Boundary values
    assert.equals("59s", charts.format_time_label(59))
    assert.equals("1m", charts.format_time_label(60))
    assert.equals("59m", charts.format_time_label(3540))
    assert.equals("1.0h", charts.format_time_label(3600))

    -- Large values
    assert.equals("100%", charts.format_percent_label(100))
end)
