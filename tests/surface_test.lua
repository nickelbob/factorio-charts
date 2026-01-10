-- Surface and chunk management tests
local charts = require("__factorio-charts__/charts")

test("create_surface creates a valid surface", function()
    local surface_data = charts.create_surface("test-surface-1")

    assert.is_table(surface_data)
    assert.is_not_nil(surface_data.surface)
    assert.is_true(surface_data.surface.valid)
    assert.equals("test-surface-1", surface_data.surface.name)
end)

test("allocate_chunk returns valid chunk with lights", function()
    local surface_data = charts.create_surface("test-surface-2")
    local chunk = charts.allocate_chunk(surface_data)

    assert.is_table(chunk)
    assert.is_table(chunk.coord)
    assert.is_number(chunk.coord.x)
    assert.is_number(chunk.coord.y)
    assert.is_table(chunk.light_ids)
    assert.equals(9, #chunk.light_ids) -- 3x3 grid of lights
end)

test("free_chunk destroys lights and returns chunk to freelist", function()
    local surface_data = charts.create_surface("test-surface-3")
    local chunk = charts.allocate_chunk(surface_data)
    local initial_freelist_size = #surface_data.chunk_freelist

    charts.free_chunk(surface_data, chunk)

    -- Chunk should be in freelist
    assert.equals(initial_freelist_size + 1, #surface_data.chunk_freelist)

    -- Lights should be destroyed (invalid)
    for _, light_id in ipairs(chunk.light_ids) do
        assert.is_false(light_id.valid)
    end
end)

test("allocate_chunk reuses freed chunks", function()
    local surface_data = charts.create_surface("test-surface-4")
    local chunk1 = charts.allocate_chunk(surface_data)
    local coord1 = {x = chunk1.coord.x, y = chunk1.coord.y}

    charts.free_chunk(surface_data, chunk1)
    local chunk2 = charts.allocate_chunk(surface_data)

    -- Should reuse the same coordinates
    assert.equals(coord1.x, chunk2.coord.x)
    assert.equals(coord1.y, chunk2.coord.y)
end)

test("get_camera_params calculates correct position with default settings", function()
    local surface_data = charts.create_surface("test-surface-5")
    local chunk = charts.allocate_chunk(surface_data)

    local camera = charts.get_camera_params(chunk, {
        widget_width = 900,
        widget_height = 700,
    })

    -- With matching widget/viewport size and no margin (default), zoom should be 1
    assert.equals(1, camera.zoom)
    -- Position should be center of graph area
    -- Default viewport: 900/32 = 28.125, 700/32 = 21.875
    assert.equals(chunk.coord.x + 28.125 / 2, camera.position.x)
    assert.equals(chunk.coord.y + 21.875 / 2, camera.position.y)
end)

test("get_camera_params with explicit left margin shifts position left", function()
    local surface_data = charts.create_surface("test-surface-5b")
    local chunk = charts.allocate_chunk(surface_data)

    local camera = charts.get_camera_params(chunk, {
        widget_width = 932,  -- 900 + 32 (1 tile margin)
        widget_height = 700,
        left_margin = 1.0,  -- Explicit margin for labels extending past graph
    })

    -- Position should be shifted left by half the margin (0.5 tiles)
    -- Base center = 900/32/2 = 14.0625, shifted left by 0.5 = 13.5625
    assert.equals(chunk.coord.x + 13.5625, camera.position.x)
    assert.equals(chunk.coord.y + 21.875 / 2, camera.position.y)
end)

test("get_camera_params calculates zoom for larger widget", function()
    local surface_data = charts.create_surface("test-surface-6")
    local chunk = charts.allocate_chunk(surface_data)

    local camera = charts.get_camera_params(chunk, {
        viewport_width = 900,
        viewport_height = 700,
        widget_width = 1800,  -- 2x larger
        widget_height = 1400, -- 2x larger
    })

    -- Zoom should be 2 (widget is 2x larger than viewport)
    assert.equals(2, camera.zoom)
end)

test("get_camera_params calculates zoom for smaller widget", function()
    local surface_data = charts.create_surface("test-surface-7")
    local chunk = charts.allocate_chunk(surface_data)

    local camera = charts.get_camera_params(chunk, {
        viewport_width = 900,
        viewport_height = 700,
        widget_width = 450,  -- 0.5x
        widget_height = 350, -- 0.5x
    })

    -- Zoom should be 0.5 (widget is half the viewport size)
    assert.equals(0.5, camera.zoom)
end)

test("get_camera_params fit mode uses minimum zoom for aspect ratio mismatch", function()
    local surface_data = charts.create_surface("test-surface-8")
    local chunk = charts.allocate_chunk(surface_data)

    local camera = charts.get_camera_params(chunk, {
        viewport_width = 900,
        viewport_height = 700,
        widget_width = 1800,  -- 2x width
        widget_height = 700,  -- 1x height
        fit_mode = "fit",
    })

    -- Fit mode should use minimum zoom to show entire graph
    -- zoom_x = 1800/900 = 2, zoom_y = 700/700 = 1
    -- min(2, 1) = 1
    assert.equals(1, camera.zoom)
end)

test("get_camera_params fill mode uses maximum zoom", function()
    local surface_data = charts.create_surface("test-surface-9")
    local chunk = charts.allocate_chunk(surface_data)

    local camera = charts.get_camera_params(chunk, {
        viewport_width = 900,
        viewport_height = 700,
        widget_width = 1800,  -- 2x width
        widget_height = 700,  -- 1x height
        fit_mode = "fill",
    })

    -- Fill mode should use maximum zoom (may crop)
    -- zoom_x = 1800/900 = 2, zoom_y = 700/700 = 1
    -- max(2, 1) = 2
    assert.equals(2, camera.zoom)
end)

test("get_camera_params returns offset for letterboxing", function()
    local surface_data = charts.create_surface("test-surface-10")
    local chunk = charts.allocate_chunk(surface_data)

    local camera = charts.get_camera_params(chunk, {
        viewport_width = 900,
        viewport_height = 700,
        widget_width = 1800,  -- 2x width
        widget_height = 700,  -- 1x height
        fit_mode = "fit",
    })

    -- With zoom=1, graph is 900px wide, widget is 1800px
    -- Offset should be (1800 - 900) / 2 = 450 on x
    assert.equals(450, camera.offset.x)
    assert.equals(0, camera.offset.y)
end)
