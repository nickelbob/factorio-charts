-- Crosshair hover tests: hover regions, per-player crosshair rendering, tooltips, GUI hover dispatch
local charts = require("__factorio-charts__/charts")
local crosshair = require("__factorio-charts__/interaction/crosshair")

local CHUNK = {coord = {x = 0, y = 0}}

-- Headless benchmark runs have no player; the GUI and per-player rendering tests then only run under --gui.
local function skip_without_player()
	log("crosshair_test: no player, test body skipped")
end

-- Two series over two columns, plot 2..4 x 1..11. Column 1: a at y=3, b at y=7. Column 2: b at y=4, a at y=5.
-- Same shape as line_graph metadata; series_order is bottom-most first, so a is drawn on top.
local function two_by_two_metadata()
	return {
		plot = {left = 2, top = 1, right = 4, bottom = 11},
		columns = 2,
		x_positions = {2, 4},
		series_order = {{name = "b", color_index = 2}, {name = "a", color_index = 1}},
		dx = 2,
		point_positions = {
			a = {{x = 2, y = 3, value = 80, data_index = 1}, {x = 4, y = 5, value = 60, data_index = 2}},
			b = {{x = 2, y = 7, value = 40, data_index = 1}, {x = 4, y = 4, value = 70, data_index = 2}},
		},
	}
end


local function regions_by_column(regions)
	local out = {}
	for _, region in ipairs(regions) do
		local column = region.data.column
		out[column] = out[column] or {}
		out[column][#out[column] + 1] = region
	end
	return out
end

local function wide_metadata(columns, series_count)
	local points = {}
	local order = {}
	local x_positions = {}
	for c = 1, columns do
		x_positions[c] = 2 + (c - 1) * 0.1
	end
	for s = 1, series_count do
		order[s] = {name = "s" .. s, color_index = s}
		local list = {}
		for c = 1, columns do
			list[c] = {x = 2 + (c - 1) * 0.1, y = 1 + s + (c % 3) * 0.1, value = s * 10 + c, data_index = c}
		end
		points["s" .. s] = list
	end
	return {
		plot = {left = 2, top = 1, right = 2 + (columns - 1) * 0.1, bottom = 20},
		columns = columns,
		x_positions = x_positions,
		series_order = order,
		dx = 0.1,
		point_positions = points,
	}
end

local function make_line_data(num_points, series_names)
	local data, counts, sum = {}, {}, {}
	for _, name in ipairs(series_names) do
		counts[name] = num_points
		sum[name] = 0
	end
	for i = 1, num_points do
		data[i] = {}
		for s, name in ipairs(series_names) do
			local value = 10 * s + (i % 7)
			data[i][name] = value
			sum[name] = sum[name] + value
		end
	end
	return data, counts, sum
end

local function make_state(surface_name, extra)
	local surface_data = charts.surface.create(surface_name)
	local chunk = charts.surface.allocate_chunk(surface_data)
	local data, counts, sum = make_line_data(20, {"iron", "copper"})
	-- Hover needs an explicit id; tests that check the generated-id path pass id = false.
	local options = {data = data, index = 0, length = 20, counts = counts, sum = sum, ttl = 600, id = surface_name}
	for k, v in pairs(extra or {}) do
		options[k] = v
	end
	if options.id == false then
		options.id = nil
	end
	return charts.interactive.create_line_graph(surface_data.surface, chunk, options), surface_data
end

local function all_valid(objects)
	for _, obj in ipairs(objects) do
		if not obj.valid then
			return false
		end
	end
	return true
end

local function none_valid(objects)
	for _, obj in ipairs(objects) do
		if obj.valid then
			return false
		end
	end
	return true
end

-- ============================================================================
-- Regions
-- ============================================================================

test("hover regions: cells partition each column's plot height", function()
	local regions = charts.interaction.create_line_graph_hover_regions(CHUNK, two_by_two_metadata())
	assert.equals(4, #regions)
	local by_column = regions_by_column(regions)
	for column = 1, 2 do
		local cells = by_column[column]
		assert.equals(2, #cells)
		table.sort(cells, function(x, y) return x.tile_bounds.top < y.tile_bounds.top end)
		assert.equals(1, cells[1].tile_bounds.top)
		assert.equals(cells[1].tile_bounds.bottom, cells[2].tile_bounds.top)
		assert.equals(11, cells[2].tile_bounds.bottom)
		for _, cell in ipairs(cells) do
			assert.equals("crosshair_cell", cell.type)
		end
	end
	-- Column 1 boundary is the midpoint of 3 and 7, column 2 of 4 and 5.
	table.sort(by_column[1], function(x, y) return x.tile_bounds.top < y.tile_bounds.top end)
	table.sort(by_column[2], function(x, y) return x.tile_bounds.top < y.tile_bounds.top end)
	assert.equals(5, by_column[1][1].tile_bounds.bottom)
	assert.equals(4.5, by_column[2][1].tile_bounds.bottom)
	-- Adjacent columns meet halfway between their x positions, clamped to the plot.
	assert.equals(2, by_column[1][1].tile_bounds.left)
	assert.equals(3, by_column[1][1].tile_bounds.right)
	assert.equals(3, by_column[2][1].tile_bounds.left)
	assert.equals(4, by_column[2][1].tile_bounds.right)
end)

test("hover regions: the cell under a point belongs to the series nearest in y", function()
	local metadata = two_by_two_metadata()
	local regions = charts.interaction.create_line_graph_hover_regions(CHUNK, metadata)
	local ys = {1.2, 3, 4.4, 4.6, 4.9, 5.1, 6.9, 10.9}
	local column_x = {2.5, 3.5}
	for column = 1, 2 do
		for _, y in ipairs(ys) do
			local hit = charts.interaction.hit_test(regions, {x = column_x[column], y = y})
			assert.is_not_nil(hit)
			local best, best_distance = nil, math.huge
			for name, points in pairs(metadata.point_positions) do
				local distance = math.abs(points[column].y - y)
				if distance < best_distance then
					best, best_distance = name, distance
				end
			end
			assert.equals(best, hit.data.series_name)
			assert.equals(column, hit.data.column)
		end
	end
end)

test("hover regions: cell data carries value, position, colour and stable id", function()
	local metadata = two_by_two_metadata()
	metadata.seconds_ago = {2, 0}
	local regions = charts.interaction.create_line_graph_hover_regions(CHUNK, metadata)
	local cell
	for _, region in ipairs(regions) do
		if region.data.column == 2 and region.data.series_name == "b" then
			cell = region
		end
	end
	assert.is_not_nil(cell)
	assert.equals("xh_2_b", cell.id)
	assert.equals(70, cell.data.value)
	assert.equals(4, cell.data.graph_x)
	assert.equals(4, cell.data.graph_y)
	assert.equals(0, cell.data.seconds_ago)
	assert.same(charts.colors.get_series_color(2), cell.data.color)
end)

test("hover regions: chunk offset moves the bounds", function()
	local regions = charts.interaction.create_line_graph_hover_regions({coord = {x = 64, y = -32}}, two_by_two_metadata())
	for _, region in ipairs(regions) do
		assert.is_true(region.tile_bounds.left >= 66 and region.tile_bounds.right <= 68)
		assert.is_true(region.tile_bounds.top >= -31 and region.tile_bounds.bottom <= -21)
	end
end)

test("hover regions: equal y values do not create empty cells", function()
	local metadata = two_by_two_metadata()
	metadata.point_positions.b[1].y = 3
	local regions = charts.interaction.create_line_graph_hover_regions(CHUNK, metadata)
	local column1 = regions_by_column(regions)[1]
	assert.equals(1, #column1)
	-- The tie goes to a, which is drawn on top.
	assert.equals("a", column1[1].data.series_name)
end)

test("hover regions: budget groups adjacent columns", function()
	local metadata = wide_metadata(100, 4)
	local regions = charts.interaction.create_line_graph_hover_regions(CHUNK, metadata, {max_buttons = 100})
	assert.equals(4, crosshair.group_size(100, 4, 100))
	assert.is_true(#regions <= 100)
	assert.equals(100, #regions)
	for _, region in ipairs(regions) do
		assert.equals(4, region.data.last_column - region.data.first_column + 1)
		assert.equals(math.floor((region.data.first_column + region.data.last_column) / 2), region.data.column)
	end
	-- Groups tile the x range without gaps.
	local by_column = regions_by_column(regions)
	local previous_right = nil
	for column = 1, 100 do
		if by_column[column] then
			local bounds = by_column[column][1].tile_bounds
			if previous_right then
				assert.is_true(math.abs(bounds.left - previous_right) < 1e-9)
			end
			previous_right = bounds.right
		end
	end
end)

test("hover regions: default budget is 400 buttons", function()
	local regions = charts.interaction.create_line_graph_hover_regions(CHUNK, wide_metadata(300, 6))
	assert.is_true(#regions <= 400)
	assert.equals(5, crosshair.group_size(300, 6))
end)

test("hover regions: column mode makes one full-height region per column", function()
	local regions = charts.interaction.create_line_graph_hover_regions(CHUNK, two_by_two_metadata(), {mode = "column"})
	assert.equals(2, #regions)
	for _, region in ipairs(regions) do
		assert.equals("crosshair_column", region.type)
		assert.equals(1, region.tile_bounds.top)
		assert.equals(11, region.tile_bounds.bottom)
		assert.equals(2, #region.data.values)
		assert.equals("a", region.data.values[1].series_name)
	end
end)

test("hover regions: missing samples leave the column to the series that have one", function()
	local metadata = two_by_two_metadata()
	table.remove(metadata.point_positions.a, 2)
	local regions = charts.interaction.create_line_graph_hover_regions(CHUNK, metadata)
	local column2 = regions_by_column(regions)[2]
	assert.equals(1, #column2)
	assert.equals("b", column2[1].data.series_name)
	assert.equals(1, column2[1].tile_bounds.top)
	assert.equals(11, column2[1].tile_bounds.bottom)
end)

test("hover regions: nil metadata gives no regions", function()
	assert.equals(0, #charts.interaction.create_line_graph_hover_regions(CHUNK, nil))
end)

test("a grouped cell whose centre column has no points reports the nearest column with points", function()
	local metadata = wide_metadata(300, 6)
	-- k = 5: the first group is columns 1..5 with centre 3. Remove every series there, and one series at the
	-- centre of the second group (columns 6..10, centre 8).
	for s = 1, 6 do
		table.remove(metadata.point_positions["s" .. s], 3)
	end
	local s1 = metadata.point_positions.s1
	for i = #s1, 1, -1 do
		if s1[i].data_index == 8 then
			table.remove(s1, i)
		end
	end
	local by_column = regions_by_column(charts.interaction.create_line_graph_hover_regions(CHUNK, metadata))
	assert.is_nil(by_column[3])
	local first_group = by_column[2] or by_column[4]
	assert.is_not_nil(first_group)
	assert.equals(1, first_group[1].data.first_column)
	assert.equals(5, first_group[1].data.last_column)
	assert.is_true(math.abs(first_group[1].tile_bounds.left - 2) < 1e-9)
	assert.is_not_nil(by_column[8])
	assert.equals(5, #by_column[8])
end)

test("hover regions from a real render use the rendered point positions", function()
	local state = make_state("test-crosshair-real")
	local regions = charts.interactive.get_hover_regions(state)
	assert.is_true(#regions > 0)
	local columns = {}
	for _, region in ipairs(regions) do
		columns[region.data.column] = true
		local points = state.metadata.point_positions[region.data.series_name]
		local found = false
		for _, point in ipairs(points) do
			if point.x == region.data.graph_x and point.y == region.data.graph_y then
				found = true
			end
		end
		assert.is_true(found)
	end
	local count = 0
	for _ in pairs(columns) do count = count + 1 end
	assert.equals(20, count)
	charts.interactive.destroy(state)
end)

test("hover regions on a real render cover the plot from plot.left to plot.right", function()
	for _, mode in ipairs({"cell", "column"}) do
		local state = make_state("test-crosshair-cover-" .. mode)
		charts.interactive.get_hover_buttons(state, {position = {x = 14, y = 11}, zoom = 1, widget_width = 900, widget_height = 700}, {mode = mode, gui_zoom = 1})
		local plot = state.metadata.plot
		local min_left, max_right = math.huge, -math.huge
		for _, region in ipairs(charts.interactive.get_hover_regions(state)) do
			min_left = math.min(min_left, region.tile_bounds.left - state.chunk.coord.x)
			max_right = math.max(max_right, region.tile_bounds.right - state.chunk.coord.x)
			if region.data.column == 1 then
				assert.is_true(math.abs(region.tile_bounds.left - state.chunk.coord.x - plot.left) < 1e-9)
			end
		end
		assert.is_true(math.abs(min_left - plot.left) < 1e-9)
		assert.is_true(math.abs(max_right - plot.right) < 1e-9)
		charts.interactive.destroy(state)
	end
end)

test("hover regions on an axes render carry seconds_ago and an si tooltip", function()
	local state = make_state("test-crosshair-axes", {
		x_axis = {ticks_per_point = 120},
		label_format = "si",
		y_range = "zero",
	})
	local configs = charts.interactive.get_hover_buttons(state, {position = {x = 14, y = 11}, zoom = 1, widget_width = 900, widget_height = 700}, {gui_zoom = 1})
	local newest
	for _, config in ipairs(configs) do
		if config.region.data.column == 20 and config.region.data.series_name == "copper" then
			newest = config
		end
	end
	assert.is_not_nil(newest)
	assert.equals(0, newest.region.data.seconds_ago)
	local value = newest.region.data.value
	assert.same({"", "copper", "\n", charts.format.si_label(value), " - ", "0 seconds ago"}, newest.tooltip)
	for _, config in ipairs(configs) do
		if config.region.data.column == 1 then
			assert.equals(38, config.region.data.seconds_ago)
		end
	end
	charts.interactive.destroy(state)
end)

-- ============================================================================
-- Crosshair rendering
-- ============================================================================

test("set_hover draws for that player only and clear_hover removes it", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local state = make_state("test-crosshair-hover")
	local before = #state.render_ids
	local region = charts.interactive.get_hover_regions(state)[1]

	charts.interactive.set_hover(state, player, region)
	local entry = state.hover[player.index]
	assert.is_not_nil(entry)
	assert.equals(region.id, entry.region_id)
	-- vertical + horizontal + marker + 19 thick segments
	assert.equals(22, #entry.objects)
	assert.is_true(all_valid(entry.objects))
	for _, obj in ipairs(entry.objects) do
		local players = obj.players
		assert.equals(1, #players)
		assert.equals(player.index, players[1].index)
	end
	assert.equals(before, #state.render_ids)

	local objects = entry.objects
	charts.interactive.clear_hover(state, player)
	assert.is_nil(state.hover[player.index])
	assert.is_true(none_valid(objects))
	charts.interactive.destroy(state)
end)

test("set_hover replaces the previous crosshair of the same player", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local state = make_state("test-crosshair-replace")
	local regions = charts.interactive.get_hover_regions(state)
	charts.interactive.set_hover(state, player, regions[1])
	local first = state.hover[player.index].objects
	charts.interactive.set_hover(state, player, regions[#regions])
	assert.is_true(none_valid(first))
	assert.equals(regions[#regions].id, state.hover[player.index].region_id)
	charts.interactive.destroy(state)
end)

test("draw_crosshair: opts.camera_zoom wins over metadata.camera_zoom", function()
	local surface_data = charts.surface.create("test-crosshair-zoom")
	local chunk = charts.surface.allocate_chunk(surface_data)
	local metadata = two_by_two_metadata()
	metadata.camera_zoom = 1.5
	local player = game.players[1]
	if not player then return skip_without_player() end
	local cell = {column = 1, series_name = "a", graph_x = 2, graph_y = 3}
	local widths = {}
	for _, zoom in ipairs({1, 2}) do
		local objects = charts.interaction.draw_crosshair(surface_data.surface, chunk, metadata, cell, player, {camera_zoom = zoom})
		widths[zoom] = objects[1].width
		for _, obj in ipairs(objects) do obj.destroy() end
	end
	assert.are_not.equal(widths[1], widths[2])
	assert.is_true(math.abs(widths[1] - charts.style.line_width(1, 1)) < 1e-6)
	assert.is_true(math.abs(widths[2] - charts.style.line_width(1, 2)) < 1e-6)
	charts.surface.free_chunk(surface_data, chunk)
end)

test("polygon series mode draws the thick series as one strip per unbroken run", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local state = make_state("test-crosshair-polygon", {hover_series_mode = "polygon"})
	charts.interactive.set_hover(state, player, charts.interactive.get_hover_regions(state)[1])
	-- vertical + horizontal + marker + one ribbon
	assert.equals(4, #state.hover[player.index].objects)
	charts.interactive.destroy(state)
end)

test("column mode crosshair draws a marker per series", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local state = make_state("test-crosshair-column-draw")
	local configs = charts.interactive.get_hover_buttons(state, {position = {x = 14, y = 11}, zoom = 1, widget_width = 900, widget_height = 700}, {mode = "column", gui_zoom = 1})
	assert.equals(20, #configs)
	charts.interactive.set_hover(state, player, configs[1].region)
	-- vertical line + one marker per series
	assert.equals(3, #state.hover[player.index].objects)
	charts.interactive.destroy(state)
end)

test("destroy clears every player's hover state", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local state = make_state("test-crosshair-destroy", {id = "crosshair-destroy"})
	charts.interactive.set_hover(state, player, charts.interactive.get_hover_regions(state)[1])
	local objects = state.hover[player.index].objects
	charts.interactive.destroy(state)
	assert.is_nil(next(state.hover))
	assert.is_true(none_valid(objects))
	assert.is_nil(charts.interactive.get_state("crosshair-destroy"))
end)

test("redraw keeps the crosshair on the same column and series", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local state = make_state("test-crosshair-redraw")
	local region = charts.interactive.get_hover_regions(state)[3]
	charts.interactive.set_hover(state, player, region)
	local old = state.hover[player.index].objects
	charts.interactive.update_line_graph(state, {ttl = 500})
	local entry = state.hover[player.index]
	assert.is_not_nil(entry)
	assert.equals(region.id, entry.region_id)
	assert.is_true(none_valid(old))
	assert.is_true(all_valid(entry.objects))
	charts.interactive.destroy(state)
end)

test("on_cell_hover and on_cell_leave callbacks receive cell and player", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local hovered, left = nil, nil
	local state = make_state("test-crosshair-callbacks", {
		on_cell_hover = function(cell, p, s) hovered = {cell = cell, player = p, state = s} end,
		on_cell_leave = function(p, s) left = {player = p, state = s} end,
	})
	local region = charts.interactive.get_hover_regions(state)[1]
	charts.interactive.set_hover(state, player, region)
	assert.equals(region.data, hovered.cell)
	assert.equals(player, hovered.player)
	assert.equals(state, hovered.state)
	charts.interactive.clear_hover(state, player)
	assert.equals(player, left.player)
	charts.interactive.destroy(state)
end)

-- ============================================================================
-- Tooltips
-- ============================================================================

test("time_ago matches the vanilla wording", function()
	assert.equals("42 seconds ago", charts.format.time_ago(42))
	assert.equals("1 second ago", charts.format.time_ago(1))
	assert.equals("6.6 minutes ago", charts.format.time_ago(396))
	assert.equals("1 minute ago", charts.format.time_ago(60))
	assert.equals("1.3 hours ago", charts.format.time_ago(4680))
	assert.equals("1 minute ago", charts.format.time_ago(59.6))
	assert.equals("59 seconds ago", charts.format.time_ago(59.4))
	assert.equals("1 hour ago", charts.format.time_ago(3599))
end)

test("default tooltip: series, value and age", function()
	local tooltip = crosshair.default_tooltip(
		{column = 3, series_name = "iron-plate", value = 35000, seconds_ago = 396},
		function(v) return string.format("%.0fk", v / 1000) end
	)
	assert.same({"", "iron-plate", "\n", "35k", " - ", "6.6 minutes ago"}, tooltip)
end)

test("default tooltip without a time axis omits the age", function()
	local tooltip = crosshair.default_tooltip({column = 3, series_name = "a", value = 50}, nil)
	assert.same({"", "a", "\n", "50%"}, tooltip)
end)

test("default column tooltip nests beyond 20 parameters", function()
	local values = {}
	for i = 1, 8 do
		values[i] = {series_name = "s" .. i, value = i}
	end
	local tooltip = crosshair.default_tooltip({column = 1, values = values, seconds_ago = 30}, "percent")
	assert.equals("", tooltip[1])
	assert.equals("30 seconds ago", tooltip[2])
	assert.is_true(#tooltip <= 21)
	assert.equals("table", type(tooltip[21]))
end)

-- ============================================================================
-- Overlay buttons and GUI event dispatch
-- ============================================================================

local CAMERA = {position = {x = 14.0625, y = 10.9375}, zoom = 1, widget_width = 900, widget_height = 700}

test("get_hover_buttons tags every config and sets a tooltip", function()
	local state = make_state("test-crosshair-buttons", {id = "crosshair-buttons"})
	local configs = charts.interactive.get_hover_buttons(state, CAMERA, {gui_zoom = 1})
	assert.is_true(#configs > 0)
	for _, config in ipairs(configs) do
		assert.equals("crosshair-buttons", config.tags.factorio_charts.chart)
		assert.equals(config.region_id, config.tags.factorio_charts.region)
		assert.is_true(config.raise_hover_events)
		assert.equals("table", type(config.tooltip))
	end
	local custom = charts.interactive.get_hover_buttons(state, CAMERA, {
		format_tooltip = function(cell) return "col " .. cell.column end,
		gui_zoom = 1,
	})
	assert.equals("col " .. custom[1].region.data.column, custom[1].tooltip)
	charts.interactive.destroy(state)
end)

test("get_hover_buttons without opts.player or opts.gui_zoom errors instead of guessing", function()
	local state = make_state("test-crosshair-needs-zoom", {id = "crosshair-needs-zoom"})
	local ok, err = pcall(charts.interactive.get_hover_buttons, state, CAMERA)
	assert.is_false(ok)
	assert.is_truthy(string.find(err, "needs opts.player or opts.gui_zoom", 1, true))
	-- Either one satisfies it.
	assert.is_true(#charts.interactive.get_hover_buttons(state, CAMERA, {gui_zoom = 1}) > 0)
	assert.is_true(#charts.interactive.get_hover_buttons(state, CAMERA, {
		player = {valid = true, display_scale = 1, display_density_scale = 1},
	}) > 0)
	charts.interactive.destroy(state)
end)

test("get_hover_buttons with opts.player places buttons for a zoom that is not scale / density", function()
	-- Cybersyn's Utilization tab: zoom = display_scale / display_density_scale + 0.05. The default gui_zoom of 1
	-- is only exact without the 0.05; a headless run has no player, and a real one's density cannot be set.
	local player = {valid = true, display_scale = 1.5, display_density_scale = 2}
	local camera = {position = CAMERA.position, zoom = 1.5 / 2 + 0.05, widget_width = 900, widget_height = 700}
	local state = make_state("test-crosshair-gui-zoom", {id = "crosshair-gui-zoom"})
	local opts = {mode = "column", player = player}
	local configs = charts.interactive.get_hover_buttons(state, camera, opts)
	local expected = charts.interaction.generate_overlay_buttons(camera.position, camera.zoom * 2 / 1.5,
		{width = 900, height = 700}, charts.interactive.get_hover_regions(state))
	assert.equals(#expected, #configs)
	for i, config in ipairs(configs) do
		assert.same(expected[i].style_mods, config.style_mods)
	end
	-- Without the player the edge columns land short of the plot by 0.05 * density / scale of their offset.
	local default = {}
	for _, config in ipairs(charts.interactive.get_hover_buttons(state, camera, {mode = "column", gui_zoom = 1})) do
		default[config.region_id] = config.style_mods
	end
	local first, last
	for _, config in ipairs(configs) do
		if default[config.region_id] then
			first = first or config
			last = config
		end
	end
	assert.is_true(default[first.region_id].left_margin - first.style_mods.left_margin > 10)
	assert.is_true(last.style_mods.left_margin - default[last.region_id].left_margin > 10)
	charts.interactive.destroy(state)
end)

test("create_overlay_buttons sets raise_hover_events", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local frame = player.gui.screen.add{type = "frame", direction = "vertical"}
	local created = charts.interaction.create_overlay_buttons(frame, {
		{style_mods = {left_margin = 10, top_margin = 10, width = 20, height = 20}},
		{style_mods = {left_margin = 40, top_margin = 10, width = 20, height = 20}, raise_hover_events = true},
	}, {button_style = "button"})
	assert.equals(2, #created)
	for _, button in ipairs(created) do
		local expected = button.style.left_margin == 40
		assert.equals(expected, button.raise_hover_events)
	end
	local all = charts.interaction.create_overlay_buttons(frame, {
		{style_mods = {left_margin = 10, top_margin = 10, width = 20, height = 20}},
	}, {button_style = "button", raise_hover_events = true})
	assert.is_true(all[1].raise_hover_events)
	frame.destroy()
end)

test("handle_gui_hover resolves a tagged button and handle_gui_leave clears only its own region", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local state = make_state("test-crosshair-events", {id = "crosshair-events"})
	local frame = player.gui.screen.add{type = "frame", direction = "vertical"}
	frame.style.width = 900
	frame.style.height = 700
	local configs = charts.interactive.get_hover_buttons(state, CAMERA, {gui_zoom = 1})
	local buttons = charts.interaction.create_overlay_buttons(frame, configs, {
		button_style = "button",
		widget_width = 900,
		widget_height = 700,
	})
	assert.is_true(#buttons >= 2)
	local first, second = buttons[1], buttons[2]
	assert.is_true(first.raise_hover_events)

	assert.is_true(charts.events.handle_gui_hover({element = first, player_index = player.index}))
	local entry = state.hover[player.index]
	assert.is_not_nil(entry)
	assert.equals(first.tags.factorio_charts.region, entry.region_id)

	-- A late leave of a button the pointer already left must not remove the newer crosshair.
	assert.is_true(charts.events.handle_gui_hover({element = second, player_index = player.index}))
	assert.is_true(charts.events.handle_gui_leave({element = first, player_index = player.index}))
	assert.equals(second.tags.factorio_charts.region, state.hover[player.index].region_id)

	assert.is_true(charts.events.handle_gui_leave({element = second, player_index = player.index}))
	assert.is_nil(state.hover[player.index])

	frame.destroy()
	charts.interactive.destroy(state)
end)

test("handle_gui_hover ignores elements without factorio_charts tags", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local frame = player.gui.screen.add{type = "frame", direction = "vertical", tags = {other = 1}}
	assert.is_false(charts.events.handle_gui_hover({element = frame, player_index = player.index}))
	assert.is_false(charts.events.handle_gui_leave({element = frame, player_index = player.index}))
	assert.is_false(charts.events.handle_gui_hover({element = nil, player_index = player.index}))
	frame.destroy()
end)

test("handle_gui_hover ignores tags of an unregistered chart", function()
	local player = game.players[1]
	if not player then return skip_without_player() end
	local frame = player.gui.screen.add{type = "frame", direction = "vertical",
		tags = {factorio_charts = {chart = "no-such-chart", region = "xh_1_a"}}}
	assert.is_false(charts.events.handle_gui_hover({element = frame, player_index = player.index}))
	frame.destroy()
end)

test("register makes a state reachable again after load", function()
	local state = make_state("test-crosshair-register", {id = "crosshair-register"})
	charts.interactive.unregister(state)
	assert.is_nil(charts.interactive.get_state("crosshair-register"))
	charts.interactive.register(state)
	assert.equals(state, charts.interactive.get_state("crosshair-register"))
	charts.interactive.destroy(state)
end)

test("hover needs an explicit id: a generated id is not registered and hover calls error", function()
	local state = make_state("test-crosshair-no-id", {id = false})
	assert.is_string(state.id)
	assert.is_nil(charts.interactive.get_state(state.id))
	local ok, err = pcall(charts.interactive.get_hover_buttons, state, CAMERA)
	assert.is_false(ok)
	assert.is_truthy(string.find(err, "interactive charts need options.id to use hover", 1, true))
	ok = pcall(charts.interactive.set_hover, state, game.players[1], {column = 1, series_name = "iron"})
	assert.is_false(ok)
	ok = pcall(charts.interactive.register, state)
	assert.is_false(ok)
	charts.interactive.destroy(state)

	local named = make_state("test-crosshair-with-id", {id = "crosshair-with-id"})
	assert.equals(named, charts.interactive.get_state("crosshair-with-id"))
	assert.is_true(#charts.interactive.get_hover_buttons(named, CAMERA, {gui_zoom = 1}) > 0)
	charts.interactive.destroy(named)
end)

test("register does not modify the state", function()
	local state = make_state("test-crosshair-register-pure", {id = "crosshair-register-pure"})
	charts.interactive.unregister(state)
	state.hover = nil
	local before = serpent.block(state, {comment = false, sortkeys = true})
	charts.interactive.register(state)
	assert.equals(before, serpent.block(state, {comment = false, sortkeys = true}))
	assert.is_nil(state.hover)
	charts.interactive.destroy(state)
end)

test("callbacks given to register are used without being in options", function()
	local state = make_state("test-crosshair-register-callbacks", {id = "crosshair-register-callbacks"})
	local hovered, left = nil, nil
	charts.interactive.register(state, {
		on_cell_hover = function(cell) hovered = cell end,
		on_cell_leave = function(p) left = p end,
		format_tooltip = function(cell) return "registered " .. cell.column end,
	})
	assert.is_nil(state.options.on_cell_hover)
	assert.is_nil(state.options.format_tooltip)
	local configs = charts.interactive.get_hover_buttons(state, CAMERA, {gui_zoom = 1})
	assert.equals("registered " .. configs[1].region.data.column, configs[1].tooltip)
	local player = game.players[1]
	if player then
		charts.interactive.set_hover(state, player, configs[1].region)
		assert.equals(configs[1].region.data, hovered)
		charts.interactive.clear_hover(state, player)
		assert.equals(player, left)
	end
	charts.interactive.destroy(state)
	assert.equals("table", type(charts.interactive.get_hover_buttons(
		make_state("test-crosshair-register-callbacks-2", {id = "crosshair-register-callbacks"}), CAMERA,
		{gui_zoom = 1})[1].tooltip))
end)

test("old on_hover path keeps working next to the crosshair", function()
	local calls = {}
	local state = make_state("test-crosshair-old-path", {
		on_hover = function(region, s) calls.hover = {region = region, state = s} end,
		on_hover_leave = function(region_id, s) calls.leave = {region_id = region_id, state = s} end,
	})
	local region = state.hit_regions[1]
	charts.interactive.on_hover(state, region.id, game.players[1])
	assert.equals(region.id, state.hovered_region)
	assert.is_not_nil(state.highlights[region.id])
	charts.interactive.on_hover_leave(state, region.id)
	assert.is_nil(state.hovered_region)
	assert.equals(region, calls.hover.region)
	assert.equals(state, calls.hover.state)
	assert.equals(region.id, calls.leave.region_id)
	assert.equals(state, calls.leave.state)
	charts.interactive.destroy(state)
end)
