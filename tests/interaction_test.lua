-- Interaction module tests
local charts = require("__factorio-charts__/charts")

test("tile_to_screen converts coordinates correctly", function()
	local camera_pos = {x = 0, y = 0}
	local zoom = 1
	local widget_size = {width = 320, height = 320}

	-- Center of camera should map to center of widget
	local result = charts.tile_to_screen(camera_pos, zoom, widget_size, {x = 0, y = 0})
	assert.equals(160, result.x)
	assert.equals(160, result.y)

	-- One tile right should be 32 pixels right at zoom 1
	result = charts.tile_to_screen(camera_pos, zoom, widget_size, {x = 1, y = 0})
	assert.equals(192, result.x)
	assert.equals(160, result.y)
end)

test("tile_to_screen handles zoom", function()
	local camera_pos = {x = 0, y = 0}
	local zoom = 2
	local widget_size = {width = 320, height = 320}

	-- At zoom 2, one tile should be 64 pixels
	local result = charts.tile_to_screen(camera_pos, zoom, widget_size, {x = 1, y = 0})
	assert.equals(224, result.x)  -- 160 + 64
end)

test("screen_to_tile is inverse of tile_to_screen", function()
	local camera_pos = {x = 5, y = 10}
	local zoom = 1.5
	local widget_size = {width = 640, height = 480}
	local original_tile = {x = 7, y = 12}

	local screen_pos = charts.tile_to_screen(camera_pos, zoom, widget_size, original_tile)
	local back_to_tile = charts.screen_to_tile(camera_pos, zoom, widget_size, screen_pos)

	-- Should round-trip correctly (within floating point tolerance)
	assert.is_true(math.abs(original_tile.x - back_to_tile.x) < 0.001)
	assert.is_true(math.abs(original_tile.y - back_to_tile.y) < 0.001)
end)

test("hit_test finds region containing point", function()
	local regions = {
		{
			id = "region1",
			tile_bounds = {left = 0, top = 0, right = 5, bottom = 5},
			type = "test",
			data = {},
		},
		{
			id = "region2",
			tile_bounds = {left = 10, top = 10, right = 15, bottom = 15},
			type = "test",
			data = {},
		},
	}

	-- Point inside region1
	local hit = charts.hit_test(regions, {x = 2.5, y = 2.5})
	assert.is_not_nil(hit)
	assert.equals("region1", hit.id)

	-- Point inside region2
	hit = charts.hit_test(regions, {x = 12, y = 12})
	assert.is_not_nil(hit)
	assert.equals("region2", hit.id)

	-- Point outside both
	hit = charts.hit_test(regions, {x = 7, y = 7})
	assert.is_nil(hit)
end)

test("hit_test returns topmost region for overlapping regions", function()
	local regions = {
		{
			id = "bottom",
			tile_bounds = {left = 0, top = 0, right = 10, bottom = 10},
			type = "test",
			data = {},
		},
		{
			id = "top",
			tile_bounds = {left = 5, top = 5, right = 15, bottom = 15},
			type = "test",
			data = {},
		},
	}

	-- Point in overlap area - should return topmost (last added)
	local hit = charts.hit_test(regions, {x = 7, y = 7})
	assert.equals("top", hit.id)
end)

test("hit_test_all returns all regions containing point", function()
	local regions = {
		{
			id = "region1",
			tile_bounds = {left = 0, top = 0, right = 10, bottom = 10},
			type = "test",
			data = {},
		},
		{
			id = "region2",
			tile_bounds = {left = 5, top = 5, right = 15, bottom = 15},
			type = "test",
			data = {},
		},
	}

	-- Point in overlap area
	local hits = charts.hit_test_all(regions, {x = 7, y = 7})
	assert.equals(2, #hits)
end)

test("generate_overlay_buttons creates buttons for visible regions", function()
	local camera_pos = {x = 5, y = 5}
	local zoom = 1
	local widget_size = {width = 320, height = 320}

	local regions = {
		{
			id = "visible",
			tile_bounds = {left = 4, top = 4, right = 6, bottom = 6},
			type = "test",
			data = {},
		},
		{
			id = "offscreen",
			tile_bounds = {left = 100, top = 100, right = 102, bottom = 102},
			type = "test",
			data = {},
		},
	}

	local buttons = charts.generate_overlay_buttons(camera_pos, zoom, widget_size, regions)

	-- Only the visible region should have a button
	assert.equals(1, #buttons)
	assert.equals("visible", buttons[1].region_id)
end)

test("create_line_graph_hit_regions creates regions for points", function()
	local surface_data = charts.create_surface("test-interaction-1")
	local chunk = charts.allocate_chunk(surface_data)

	-- Create simple test data
	local data = {}
	local counts = {series1 = 10}
	local sum = {series1 = 500}
	for i = 1, 10 do
		data[i] = {series1 = i * 10}
	end

	local ordered_sums, line_ids, metadata = charts.render_line_graph_with_metadata(
		surface_data.surface, chunk, {
			data = data,
			index = 0,
			length = 10,
			counts = counts,
			sum = sum,
			ttl = 60,
		}
	)

	assert.is_not_nil(metadata)
	assert.is_not_nil(metadata.point_positions)

	local hit_regions = charts.create_line_graph_hit_regions(chunk, metadata)
	assert.is_table(hit_regions)
	assert.is_true(#hit_regions > 0)

	-- Check first region has expected structure
	local region = hit_regions[1]
	assert.is_not_nil(region.id)
	assert.is_not_nil(region.tile_bounds)
	assert.is_not_nil(region.type)
	assert.equals("data_point", region.type)
	assert.is_not_nil(region.data.series_name)
	assert.is_not_nil(region.data.value)

	charts.free_chunk(surface_data, chunk)
end)

test("create_bar_chart_hit_regions creates regions for segments", function()
	local surface_data = charts.create_surface("test-interaction-2")
	local chunk = charts.allocate_chunk(surface_data)

	local deliveries = {
		{loading = 10, travel = 20, unloading = 15},
		{loading = 5, travel = 30, unloading = 10},
	}
	local phase_colors = {
		loading = {r = 0, g = 1, b = 0},
		travel = {r = 0, g = 0, b = 1},
		unloading = {r = 1, g = 0, b = 0},
	}
	local phase_order = {"loading", "travel", "unloading"}

	local line_ids, metadata = charts.render_stacked_bars_with_metadata(
		surface_data.surface, chunk, {
			deliveries = deliveries,
			phase_colors = phase_colors,
			phase_order = phase_order,
			ttl = 60,
		}
	)

	assert.is_not_nil(metadata)
	assert.is_not_nil(metadata.segment_bounds)

	local hit_regions = charts.create_bar_chart_hit_regions(chunk, metadata)
	assert.is_table(hit_regions)
	assert.is_true(#hit_regions > 0)

	-- Should have 6 regions (2 bars x 3 phases)
	assert.equals(6, #hit_regions)

	-- Check region structure
	local region = hit_regions[1]
	assert.equals("bar_segment", region.type)
	assert.is_not_nil(region.data.bar_index)
	assert.is_not_nil(region.data.phase_name)
	assert.is_not_nil(region.data.duration)

	charts.free_chunk(surface_data, chunk)
end)

-- ============================================================================
-- Extended Interaction Tests
-- ============================================================================

test("tile_to_screen handles camera offset from origin", function()
	local camera_pos = {x = 100, y = 100}
	local zoom = 1
	local widget_size = {width = 320, height = 320}

	-- Tile at camera center should map to widget center
	local result = charts.tile_to_screen(camera_pos, zoom, widget_size, {x = 100, y = 100})
	assert.equals(160, result.x)
	assert.equals(160, result.y)

	-- Tile 5 units away should be 160 pixels away
	result = charts.tile_to_screen(camera_pos, zoom, widget_size, {x = 105, y = 100})
	assert.equals(320, result.x)  -- 160 + 5*32
end)

test("tile_to_screen handles fractional zoom", function()
	local camera_pos = {x = 0, y = 0}
	local zoom = 0.5
	local widget_size = {width = 320, height = 320}

	-- At zoom 0.5, one tile is 16 pixels
	local result = charts.tile_to_screen(camera_pos, zoom, widget_size, {x = 1, y = 0})
	assert.equals(176, result.x)  -- 160 + 16
end)

test("screen_to_tile handles edge of widget", function()
	local camera_pos = {x = 0, y = 0}
	local zoom = 1
	local widget_size = {width = 320, height = 320}

	-- Top-left corner of widget
	local result = charts.screen_to_tile(camera_pos, zoom, widget_size, {x = 0, y = 0})
	assert.equals(-5, result.x)  -- -160/32
	assert.equals(-5, result.y)

	-- Bottom-right corner
	result = charts.screen_to_tile(camera_pos, zoom, widget_size, {x = 320, y = 320})
	assert.equals(5, result.x)
	assert.equals(5, result.y)
end)

test("hit_test with empty regions returns nil", function()
	local hit = charts.hit_test({}, {x = 5, y = 5})
	assert.is_nil(hit)
end)

test("hit_test boundary conditions - point on edge", function()
	local regions = {
		{
			id = "region1",
			tile_bounds = {left = 0, top = 0, right = 10, bottom = 10},
			type = "test",
			data = {},
		},
	}

	-- Point exactly on left edge
	local hit = charts.hit_test(regions, {x = 0, y = 5})
	assert.is_not_nil(hit)

	-- Point exactly on right edge
	hit = charts.hit_test(regions, {x = 10, y = 5})
	assert.is_not_nil(hit)

	-- Point exactly on top edge
	hit = charts.hit_test(regions, {x = 5, y = 0})
	assert.is_not_nil(hit)

	-- Point exactly on bottom edge
	hit = charts.hit_test(regions, {x = 5, y = 10})
	assert.is_not_nil(hit)

	-- Point exactly on corner
	hit = charts.hit_test(regions, {x = 0, y = 0})
	assert.is_not_nil(hit)
end)

test("hit_test boundary conditions - point just outside", function()
	local regions = {
		{
			id = "region1",
			tile_bounds = {left = 0, top = 0, right = 10, bottom = 10},
			type = "test",
			data = {},
		},
	}

	-- Point just outside left
	local hit = charts.hit_test(regions, {x = -0.001, y = 5})
	assert.is_nil(hit)

	-- Point just outside right
	hit = charts.hit_test(regions, {x = 10.001, y = 5})
	assert.is_nil(hit)

	-- Point just outside top
	hit = charts.hit_test(regions, {x = 5, y = -0.001})
	assert.is_nil(hit)

	-- Point just outside bottom
	hit = charts.hit_test(regions, {x = 5, y = 10.001})
	assert.is_nil(hit)
end)

test("hit_test_all with empty regions returns empty array", function()
	local hits = charts.hit_test_all({}, {x = 5, y = 5})
	assert.is_table(hits)
	assert.equals(0, #hits)
end)

test("hit_test_all returns regions in order", function()
	local regions = {
		{id = "first", tile_bounds = {left = 0, top = 0, right = 10, bottom = 10}, type = "test", data = {}},
		{id = "second", tile_bounds = {left = 0, top = 0, right = 10, bottom = 10}, type = "test", data = {}},
		{id = "third", tile_bounds = {left = 0, top = 0, right = 10, bottom = 10}, type = "test", data = {}},
	}

	local hits = charts.hit_test_all(regions, {x = 5, y = 5})
	assert.equals(3, #hits)
	assert.equals("first", hits[1].id)
	assert.equals("second", hits[2].id)
	assert.equals("third", hits[3].id)
end)

test("generate_overlay_buttons filters offscreen regions correctly", function()
	local camera_pos = {x = 0, y = 0}
	local zoom = 1
	local widget_size = {width = 320, height = 320}  -- Shows -5 to +5 tiles

	local regions = {
		-- Fully visible (center)
		{id = "visible_center", tile_bounds = {left = -2, top = -2, right = 2, bottom = 2}, type = "test", data = {}},
		-- Partially visible (straddles right edge)
		{id = "visible_partial", tile_bounds = {left = 3, top = -2, right = 7, bottom = 2}, type = "test", data = {}},
		-- Fully offscreen (far right)
		{id = "offscreen_right", tile_bounds = {left = 10, top = -2, right = 12, bottom = 2}, type = "test", data = {}},
		-- Fully offscreen (far left)
		{id = "offscreen_left", tile_bounds = {left = -12, top = -2, right = -10, bottom = 2}, type = "test", data = {}},
	}

	local buttons = charts.generate_overlay_buttons(camera_pos, zoom, widget_size, regions)

	-- Should have 2 buttons (center and partial)
	assert.equals(2, #buttons)

	local button_ids = {}
	for _, btn in ipairs(buttons) do
		button_ids[btn.region_id] = true
	end

	assert.is_true(button_ids["visible_center"])
	assert.is_true(button_ids["visible_partial"])
	assert.is_nil(button_ids["offscreen_right"])
	assert.is_nil(button_ids["offscreen_left"])
end)

test("calculate_button_style computes correct dimensions", function()
	local camera_pos = {x = 0, y = 0}
	local zoom = 1
	local widget_size = {width = 320, height = 320}

	local region = {
		tile_bounds = {left = -1, top = -1, right = 1, bottom = 1},  -- 2x2 tile region
	}

	local style = charts.calculate_button_style(camera_pos, zoom, widget_size, region)

	-- Region is 2 tiles wide/tall = 64 pixels at zoom 1
	assert.equals(64, style.width)
	assert.equals(64, style.height)

	-- Top-left of region is at tile (-1, -1) = screen (128, 128) at zoom 1 centered at (160, 160)
	assert.equals(128, style.left_margin)
	assert.equals(128, style.top_margin)
end)

test("calculate_button_style handles zoom", function()
	local camera_pos = {x = 0, y = 0}
	local zoom = 2
	local widget_size = {width = 320, height = 320}

	local region = {
		tile_bounds = {left = 0, top = 0, right = 1, bottom = 1},  -- 1x1 tile region
	}

	local style = charts.calculate_button_style(camera_pos, zoom, widget_size, region)

	-- At zoom 2, 1 tile = 64 pixels
	assert.equals(64, style.width)
	assert.equals(64, style.height)
end)

test("create_line_graph_hit_regions with custom point radius", function()
	local surface_data = charts.create_surface("test-interaction-3")
	local chunk = charts.allocate_chunk(surface_data)

	local data = {}
	local counts = {series1 = 5}
	local sum = {series1 = 250}
	for i = 1, 5 do
		data[i] = {series1 = i * 10}
	end

	local ordered_sums, line_ids, metadata = charts.render_line_graph_with_metadata(
		surface_data.surface, chunk, {
			data = data,
			index = 0,
			length = 5,
			counts = counts,
			sum = sum,
			ttl = 60,
		}
	)

	-- Default radius
	local hit_regions_default = charts.create_line_graph_hit_regions(chunk, metadata)
	local first_default = hit_regions_default[1]
	local default_width = first_default.tile_bounds.right - first_default.tile_bounds.left

	-- Custom larger radius
	local hit_regions_large = charts.create_line_graph_hit_regions(chunk, metadata, {point_radius = 1.0})
	local first_large = hit_regions_large[1]
	local large_width = first_large.tile_bounds.right - first_large.tile_bounds.left

	assert.is_true(large_width > default_width)
	assert.equals(2.0, large_width)  -- radius 1.0 means width 2.0

	charts.free_chunk(surface_data, chunk)
end)

test("create_line_graph_hit_regions with nil metadata returns empty", function()
	local chunk = {coord = {x = 0, y = 0}}
	local hit_regions = charts.create_line_graph_hit_regions(chunk, nil)
	assert.is_table(hit_regions)
	assert.equals(0, #hit_regions)
end)

test("create_bar_chart_hit_regions with nil metadata returns empty", function()
	local chunk = {coord = {x = 0, y = 0}}
	local hit_regions = charts.create_bar_chart_hit_regions(chunk, nil)
	assert.is_table(hit_regions)
	assert.equals(0, #hit_regions)
end)

test("create_line_graph_hit_regions includes chunk offset in bounds", function()
	local surface_data = charts.create_surface("test-interaction-4")
	local chunk = charts.allocate_chunk(surface_data)

	local data = {}
	local counts = {series1 = 5}
	local sum = {series1 = 250}
	for i = 1, 5 do
		data[i] = {series1 = i * 10}
	end

	local ordered_sums, line_ids, metadata = charts.render_line_graph_with_metadata(
		surface_data.surface, chunk, {
			data = data,
			index = 0,
			length = 5,
			counts = counts,
			sum = sum,
			ttl = 60,
		}
	)

	local hit_regions = charts.create_line_graph_hit_regions(chunk, metadata)
	local first_region = hit_regions[1]

	-- Bounds should include chunk offset
	assert.is_true(first_region.tile_bounds.left >= chunk.coord.x)
	assert.is_true(first_region.tile_bounds.top >= chunk.coord.y)

	charts.free_chunk(surface_data, chunk)
end)

test("hit regions contain correct data values", function()
	local surface_data = charts.create_surface("test-interaction-5")
	local chunk = charts.allocate_chunk(surface_data)

	local data = {
		{series1 = 10},
		{series1 = 20},
		{series1 = 30},
	}
	local counts = {series1 = 3}
	local sum = {series1 = 60}

	local ordered_sums, line_ids, metadata = charts.render_line_graph_with_metadata(
		surface_data.surface, chunk, {
			data = data,
			index = 0,
			length = 3,
			counts = counts,
			sum = sum,
			ttl = 60,
		}
	)

	local hit_regions = charts.create_line_graph_hit_regions(chunk, metadata)

	-- Find regions and verify values (they may not be in order due to ring buffer iteration)
	local values_found = {}
	for _, region in ipairs(hit_regions) do
		values_found[region.data.value] = true
		assert.equals("series1", region.data.series_name)
		assert.is_not_nil(region.data.data_index)
	end

	assert.is_true(values_found[10])
	assert.is_true(values_found[20])
	assert.is_true(values_found[30])

	charts.free_chunk(surface_data, chunk)
end)

test("create_highlight returns valid render object", function()
	local surface_data = charts.create_surface("test-interaction-6")
	local chunk = charts.allocate_chunk(surface_data)

	local region = {
		id = "test_region",
		tile_bounds = {
			left = chunk.coord.x + 5,
			top = chunk.coord.y + 5,
			right = chunk.coord.x + 10,
			bottom = chunk.coord.y + 10,
		},
		type = "test",
		data = {},
	}

	local highlight = charts.create_highlight(surface_data.surface, region, {
		color = {r = 1, g = 1, b = 0, a = 0.5},
		ttl = 60,
	})

	assert.is_not_nil(highlight)
	assert.is_true(highlight.valid)

	charts.free_chunk(surface_data, chunk)
end)

test("create_highlight_filled returns filled rectangle", function()
	local surface_data = charts.create_surface("test-interaction-7")
	local chunk = charts.allocate_chunk(surface_data)

	local region = {
		id = "test_region",
		tile_bounds = {
			left = chunk.coord.x + 5,
			top = chunk.coord.y + 5,
			right = chunk.coord.x + 10,
			bottom = chunk.coord.y + 10,
		},
		type = "test",
		data = {},
	}

	local highlight = charts.create_highlight_filled(surface_data.surface, region)

	assert.is_not_nil(highlight)
	assert.is_true(highlight.valid)

	charts.free_chunk(surface_data, chunk)
end)

test("create_tooltip returns array of render objects", function()
	local surface_data = charts.create_surface("test-interaction-8")
	local chunk = charts.allocate_chunk(surface_data)

	local tile_pos = {x = chunk.coord.x + 10, y = chunk.coord.y + 10}
	local lines = {"Line 1", "Line 2", "Line 3"}

	local tooltip = charts.create_tooltip(surface_data.surface, tile_pos, lines, {ttl = 60})

	assert.is_table(tooltip)
	assert.equals(3, #tooltip)  -- One render object per line

	for _, obj in ipairs(tooltip) do
		assert.is_true(obj.valid)
	end

	charts.free_chunk(surface_data, chunk)
end)

test("destroy_render_objects cleans up objects", function()
	local surface_data = charts.create_surface("test-interaction-9")
	local chunk = charts.allocate_chunk(surface_data)

	local tile_pos = {x = chunk.coord.x + 10, y = chunk.coord.y + 10}
	local tooltip = charts.create_tooltip(surface_data.surface, tile_pos, {"Test"}, {ttl = 600})

	assert.is_true(tooltip[1].valid)

	charts.destroy_render_objects(tooltip)

	-- After destruction, objects should be invalid
	assert.is_false(tooltip[1].valid)

	charts.free_chunk(surface_data, chunk)
end)

test("destroy_render_objects handles already-destroyed objects", function()
	local surface_data = charts.create_surface("test-interaction-10")
	local chunk = charts.allocate_chunk(surface_data)

	local tile_pos = {x = chunk.coord.x + 10, y = chunk.coord.y + 10}
	local tooltip = charts.create_tooltip(surface_data.surface, tile_pos, {"Test"}, {ttl = 600})

	-- Manually destroy first
	tooltip[1].destroy()

	-- Should not error when calling destroy_render_objects
	charts.destroy_render_objects(tooltip)

	charts.free_chunk(surface_data, chunk)
end)

test("create_legend_hit_regions creates regions for legend items", function()
	local chunk = {coord = {x = 0, y = 0}}

	local legend_positions = {
		{name = "series1", x = 1, y = 1, width = 2, height = 0.5},
		{name = "series2", x = 1, y = 2, width = 2, height = 0.5},
	}

	local hit_regions = charts.create_legend_hit_regions(chunk, legend_positions)

	assert.equals(2, #hit_regions)

	local region1 = hit_regions[1]
	assert.equals("legend_series1", region1.id)
	assert.equals("legend_item", region1.type)
	assert.equals("series1", region1.data.series_name)
	assert.equals(1, region1.tile_bounds.left)
	assert.equals(1, region1.tile_bounds.top)
	assert.equals(3, region1.tile_bounds.right)
	assert.equals(1.5, region1.tile_bounds.bottom)
end)
