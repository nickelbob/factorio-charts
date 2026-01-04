-- Line graph rendering tests
local charts = require("__factorio-charts__/charts")

-- Helper to create test data
local function make_test_data(num_points, series_names)
    local data = {}
    local counts = {}
    local sum = {}

    for _, name in ipairs(series_names) do
        counts[name] = num_points
        sum[name] = 0
    end

    for i = 1, num_points do
        data[i] = {}
        for _, name in ipairs(series_names) do
            local value = math.random(0, 100)
            data[i][name] = value
            sum[name] = sum[name] + value
        end
    end

    return data, counts, sum
end

test("render_line_graph with valid data returns render IDs", function()
    local surface_data = charts.create_surface("test-line-1")
    local chunk = charts.allocate_chunk(surface_data)

    local data, counts, sum = make_test_data(100, {"series1", "series2"})

    local ordered_sums, line_ids = charts.render_line_graph(
        surface_data.surface, chunk, {
            data = data,
            index = 0,
            length = 100,
            counts = counts,
            sum = sum,
            ttl = 60,
        }
    )

    assert.is_table(ordered_sums)
    assert.is_table(line_ids)
    assert.is_true(#line_ids > 0)

    charts.free_chunk(surface_data, chunk)
end)

test("render_line_graph with empty data returns nil", function()
    local surface_data = charts.create_surface("test-line-2")
    local chunk = charts.allocate_chunk(surface_data)

    local result = charts.render_line_graph(
        surface_data.surface, chunk, {
            data = {},
            index = 0,
            length = 0,
            counts = {},
            sum = {},
            ttl = 60,
        }
    )

    assert.is_nil(result)
    charts.free_chunk(surface_data, chunk)
end)

test("render_line_graph with nil chunk returns nil", function()
    local surface_data = charts.create_surface("test-line-3")

    local result = charts.render_line_graph(
        surface_data.surface, nil, {
            data = {},
            index = 0,
            length = 0,
            counts = {},
            sum = {},
        }
    )

    assert.is_nil(result)
end)
