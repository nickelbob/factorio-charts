-- Interactive chart module tests
local charts = require("__factorio-charts__/charts")

-- Helper to create test line graph data
local function make_line_graph_data(num_points, series_names)
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

-- Helper to create test bar chart data
local function make_bar_chart_data(num_bars)
	local deliveries = {}
	local phase_colors = {
		loading = {r = 0, g = 1, b = 0},
		travel = {r = 0, g = 0, b = 1},
		unloading = {r = 1, g = 0, b = 0},
	}
	local phase_order = {"loading", "travel", "unloading"}

	for i = 1, num_bars do
		deliveries[i] = {
			loading = math.random(5, 20),
			travel = math.random(10, 50),
			unloading = math.random(5, 15),
		}
	end

	return deliveries, phase_colors, phase_order
end

-- ============================================================================
-- Interactive Line Graph Tests
-- ============================================================================

test("create_interactive_line_graph returns valid state", function()
	local surface_data = charts.create_surface("test-interactive-lg-1")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(50, {"series1", "series2"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 50,
		counts = counts,
		sum = sum,
		ttl = 60,
	})

	assert.is_table(state)
	assert.is_not_nil(state.id)
	assert.equals("line_graph", state.chart_type)
	assert.equals(chunk, state.chunk)
	assert.equals(surface_data.surface, state.surface)
	assert.is_table(state.hit_regions)
	assert.is_table(state.render_ids)
	assert.is_table(state.highlights)
	assert.is_table(state.tooltips)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("create_interactive_line_graph generates hit regions", function()
	local surface_data = charts.create_surface("test-interactive-lg-2")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(20, {"series1"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 20,
		counts = counts,
		sum = sum,
		ttl = 60,
	})

	local hit_regions = charts.get_chart_hit_regions(state)
	assert.is_table(hit_regions)
	assert.is_true(#hit_regions > 0)

	-- Each data point should have a hit region
	assert.equals(20, #hit_regions)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("update_interactive_line_graph updates data", function()
	local surface_data = charts.create_surface("test-interactive-lg-3")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
	})

	local initial_render_count = #state.render_ids

	-- Update with new data
	local new_data, new_counts, new_sum = make_line_graph_data(10, {"series1"})
	charts.update_interactive_line_graph(state, {
		data = new_data,
		counts = new_counts,
		sum = new_sum,
	})

	-- Should have rendered new objects
	assert.is_true(#state.render_ids > 0)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("chart_hit_test finds regions at tile position", function()
	local surface_data = charts.create_surface("test-interactive-lg-4")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
		hit_radius = 0.5,  -- Larger hit radius for easier testing
	})

	-- Get a known hit region position
	local hit_regions = charts.get_chart_hit_regions(state)
	assert.is_true(#hit_regions > 0)

	local first_region = hit_regions[1]
	local center_x = (first_region.tile_bounds.left + first_region.tile_bounds.right) / 2
	local center_y = (first_region.tile_bounds.top + first_region.tile_bounds.bottom) / 2

	-- Hit test at the center of the first region
	local hit = charts.chart_hit_test(state, {x = center_x, y = center_y})
	assert.is_not_nil(hit)
	assert.equals(first_region.id, hit.id)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("chart_on_hover creates highlight and tooltip", function()
	local surface_data = charts.create_surface("test-interactive-lg-5")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local hover_called = false
	local hover_region = nil
	local hover_state = nil
	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
		on_hover = function(region, s)
			hover_called = true
			hover_region = region
			hover_state = s
		end,
	})

	local hit_regions = charts.get_chart_hit_regions(state)
	local region = hit_regions[1]

	-- Trigger hover
	charts.chart_on_hover(state, region.id, nil)

	assert.is_true(hover_called)
	assert.is_not_nil(hover_region)
	assert.equals(state, hover_state)
	assert.equals(region.id, state.hovered_region)
	assert.is_not_nil(state.highlights[region.id])
	assert.is_not_nil(state.tooltips[region.id])

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("chart_on_hover_leave clears highlight and tooltip", function()
	local surface_data = charts.create_surface("test-interactive-lg-6")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
	})

	local hit_regions = charts.get_chart_hit_regions(state)
	local region = hit_regions[1]

	-- Hover then leave
	charts.chart_on_hover(state, region.id, nil)
	assert.is_not_nil(state.highlights[region.id])

	charts.chart_on_hover_leave(state, region.id)
	assert.is_nil(state.highlights[region.id])
	assert.is_nil(state.tooltips[region.id])
	assert.is_nil(state.hovered_region)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("chart_on_click triggers callback", function()
	local surface_data = charts.create_surface("test-interactive-lg-7")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local click_called = false
	local clicked_region = nil
	local clicked_button = nil

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
		on_click = function(region, button, s)
			click_called = true
			clicked_region = region
			clicked_button = button
		end,
	})

	local hit_regions = charts.get_chart_hit_regions(state)
	local region = hit_regions[1]

	charts.chart_on_click(state, region.id, defines.mouse_button_type.left, nil)

	assert.is_true(click_called)
	assert.equals(region.id, clicked_region.id)
	assert.equals(defines.mouse_button_type.left, clicked_button)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("toggle_chart_series updates visibility", function()
	local surface_data = charts.create_surface("test-interactive-lg-8")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1", "series2"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
	})

	-- Initially all series visible (nil means show all)
	assert.is_nil(state.selected_series)

	-- Toggle series1 off
	charts.toggle_chart_series(state, "series1", false)

	assert.is_not_nil(state.selected_series)
	assert.equals(false, state.selected_series["series1"])

	-- Toggle series1 back on
	charts.toggle_chart_series(state, "series1", false)
	assert.equals(true, state.selected_series["series1"])

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("destroy_interactive_chart cleans up resources", function()
	local surface_data = charts.create_surface("test-interactive-lg-9")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
	})

	-- Create some hover state
	local hit_regions = charts.get_chart_hit_regions(state)
	charts.chart_on_hover(state, hit_regions[1].id, nil)

	-- Destroy should clear everything
	charts.destroy_interactive_chart(state)

	assert.equals(0, #state.render_ids)
	assert.is_nil(next(state.highlights))
	assert.is_nil(next(state.tooltips))

	charts.free_chunk(surface_data, chunk)
end)

-- ============================================================================
-- Interactive Bar Chart Tests
-- ============================================================================

test("create_interactive_bar_chart returns valid state", function()
	local surface_data = charts.create_surface("test-interactive-bc-1")
	local chunk = charts.allocate_chunk(surface_data)

	local deliveries, phase_colors, phase_order = make_bar_chart_data(5)

	local state = charts.create_interactive_bar_chart(surface_data.surface, chunk, {
		deliveries = deliveries,
		phase_colors = phase_colors,
		phase_order = phase_order,
		ttl = 60,
	})

	assert.is_table(state)
	assert.is_not_nil(state.id)
	assert.equals("bar_chart", state.chart_type)
	assert.is_table(state.hit_regions)
	assert.is_table(state.render_ids)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("create_interactive_bar_chart generates hit regions for segments", function()
	local surface_data = charts.create_surface("test-interactive-bc-2")
	local chunk = charts.allocate_chunk(surface_data)

	local deliveries, phase_colors, phase_order = make_bar_chart_data(3)

	local state = charts.create_interactive_bar_chart(surface_data.surface, chunk, {
		deliveries = deliveries,
		phase_colors = phase_colors,
		phase_order = phase_order,
		ttl = 60,
	})

	local hit_regions = charts.get_chart_hit_regions(state)

	-- 3 bars x 3 phases = 9 regions
	assert.equals(9, #hit_regions)

	-- All should be bar_segment type
	for _, region in ipairs(hit_regions) do
		assert.equals("bar_segment", region.type)
		assert.is_not_nil(region.data.bar_index)
		assert.is_not_nil(region.data.phase_name)
		assert.is_not_nil(region.data.duration)
	end

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("update_interactive_bar_chart updates data", function()
	local surface_data = charts.create_surface("test-interactive-bc-3")
	local chunk = charts.allocate_chunk(surface_data)

	local deliveries, phase_colors, phase_order = make_bar_chart_data(3)

	local state = charts.create_interactive_bar_chart(surface_data.surface, chunk, {
		deliveries = deliveries,
		phase_colors = phase_colors,
		phase_order = phase_order,
		ttl = 60,
	})

	local initial_region_count = #charts.get_chart_hit_regions(state)

	-- Update with more bars
	local new_deliveries = make_bar_chart_data(5)
	charts.update_interactive_bar_chart(state, {
		deliveries = new_deliveries,
	})

	-- Should have more hit regions now
	local new_region_count = #charts.get_chart_hit_regions(state)
	assert.equals(15, new_region_count)  -- 5 bars x 3 phases

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("bar chart hover shows phase information", function()
	local surface_data = charts.create_surface("test-interactive-bc-4")
	local chunk = charts.allocate_chunk(surface_data)

	local deliveries, phase_colors, phase_order = make_bar_chart_data(2)

	local hovered_phase = nil
	local state = charts.create_interactive_bar_chart(surface_data.surface, chunk, {
		deliveries = deliveries,
		phase_colors = phase_colors,
		phase_order = phase_order,
		ttl = 60,
		on_hover = function(region, s)
			hovered_phase = region.data.phase_name
		end,
	})

	local hit_regions = charts.get_chart_hit_regions(state)

	-- Find a loading phase region
	local loading_region = nil
	for _, region in ipairs(hit_regions) do
		if region.data.phase_name == "loading" then
			loading_region = region
			break
		end
	end

	assert.is_not_nil(loading_region)
	charts.chart_on_hover(state, loading_region.id, nil)
	assert.equals("loading", hovered_phase)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

-- ============================================================================
-- Overlay Button Tests
-- ============================================================================

test("get_chart_overlay_buttons returns button configs", function()
	local surface_data = charts.create_surface("test-interactive-overlay-1")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
	})

	-- Camera positioned at chunk center
	local camera_pos = {x = chunk.coord.x + 16, y = chunk.coord.y + 16}
	local zoom = 1
	local widget_size = {width = 900, height = 700}

	local buttons = charts.get_chart_overlay_buttons(state, camera_pos, zoom, widget_size)

	assert.is_table(buttons)
	-- Should have buttons for visible regions
	assert.is_true(#buttons > 0)

	-- Each button should have required fields
	local button = buttons[1]
	assert.is_not_nil(button.region_id)
	assert.is_not_nil(button.style_mods)
	assert.is_not_nil(button.style_mods.left_margin)
	assert.is_not_nil(button.style_mods.top_margin)
	assert.is_not_nil(button.style_mods.width)
	assert.is_not_nil(button.style_mods.height)
	assert.is_not_nil(button.region)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("chart_hit_test_screen converts screen position to tile and tests", function()
	local surface_data = charts.create_surface("test-interactive-screen-1")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
		hit_radius = 1.0,  -- Large hit radius
	})

	local camera_pos = {x = chunk.coord.x + 16, y = chunk.coord.y + 11}
	local zoom = 1
	local widget_size = {width = 900, height = 700}

	-- Get first region's tile position and convert to screen
	local hit_regions = charts.get_chart_hit_regions(state)
	local region = hit_regions[1]
	local tile_center_x = (region.tile_bounds.left + region.tile_bounds.right) / 2
	local tile_center_y = (region.tile_bounds.top + region.tile_bounds.bottom) / 2

	local screen_pos = charts.tile_to_screen(camera_pos, zoom, widget_size, {x = tile_center_x, y = tile_center_y})

	-- Hit test using screen position
	local hit = charts.chart_hit_test_screen(state, camera_pos, zoom, widget_size, screen_pos)
	assert.is_not_nil(hit)
	assert.equals(region.id, hit.id)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

-- ============================================================================
-- Edge Cases
-- ============================================================================

test("interactive chart handles empty data gracefully", function()
	local surface_data = charts.create_surface("test-interactive-edge-1")
	local chunk = charts.allocate_chunk(surface_data)

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = {},
		index = 0,
		length = 0,
		counts = {},
		sum = {},
		ttl = 60,
	})

	-- Should still create a valid state
	assert.is_table(state)
	assert.equals(0, #charts.get_chart_hit_regions(state))

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("hover on non-existent region is handled gracefully", function()
	local surface_data = charts.create_surface("test-interactive-edge-2")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
	})

	-- Should not error on non-existent region
	charts.chart_on_hover(state, "non_existent_region", nil)
	assert.is_nil(state.hovered_region)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("multiple hover transitions work correctly", function()
	local surface_data = charts.create_surface("test-interactive-edge-3")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
	})

	local hit_regions = charts.get_chart_hit_regions(state)
	local region1 = hit_regions[1]
	local region2 = hit_regions[2]

	-- Hover first region
	charts.chart_on_hover(state, region1.id, nil)
	assert.equals(region1.id, state.hovered_region)
	assert.is_not_nil(state.highlights[region1.id])

	-- Hover second region (should auto-clear first)
	charts.chart_on_hover(state, region2.id, nil)
	assert.equals(region2.id, state.hovered_region)
	assert.is_nil(state.highlights[region1.id])
	assert.is_not_nil(state.highlights[region2.id])

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)

test("custom tooltip formatter is called", function()
	local surface_data = charts.create_surface("test-interactive-edge-4")
	local chunk = charts.allocate_chunk(surface_data)

	local data, counts, sum = make_line_graph_data(10, {"series1"})

	local formatter_called = false
	local state = charts.create_interactive_line_graph(surface_data.surface, chunk, {
		data = data,
		index = 0,
		length = 10,
		counts = counts,
		sum = sum,
		ttl = 60,
		format_tooltip = function(region, lines, s)
			formatter_called = true
			return {"Custom Line 1", "Custom Line 2"}
		end,
	})

	local hit_regions = charts.get_chart_hit_regions(state)
	charts.chart_on_hover(state, hit_regions[1].id, nil)

	assert.is_true(formatter_called)

	charts.destroy_interactive_chart(state)
	charts.free_chunk(surface_data, chunk)
end)
