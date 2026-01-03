-- Surface and chunk management tests
local charts = require("charts")

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
