-- High-level interactive chart wrapper
local interactive_chart = {}

local line_graph = require("charts/line-graph")
local bar_chart = require("charts/bar-chart")
local interaction = require("interaction/interaction")
local format_module = require("core/format")

---@class InteractiveChartState
---@field id string Unique chart identifier
---@field chart_type string "line_graph" | "bar_chart"
---@field chunk table The allocated chunk
---@field surface LuaSurface The rendering surface
---@field hit_regions HitRegion[] Current hit regions
---@field render_ids LuaRenderObject[] Current render object IDs
---@field highlights table<string, LuaRenderObject> Active highlights by region_id
---@field tooltips table<string, LuaRenderObject[]> Active tooltips by region_id
---@field selected_series table<string, boolean>? Series visibility state
---@field hovered_region string? Currently hovered region ID
---@field options table Last render options
---@field metadata table Last render metadata
---@field ordered_sums table? Last ordered_sums (for line graphs)

local chart_id_counter = 0
local function generate_chart_id()
	chart_id_counter = chart_id_counter + 1
	return "chart_" .. chart_id_counter
end

-- Internal helper to clear existing render objects
local function clear_render_objects(state)
	if state.render_ids then
		for _, obj in ipairs(state.render_ids) do
			if obj and obj.valid then
				obj.destroy()
			end
		end
	end
	state.render_ids = {}
end

-- Internal helper to clear highlights
local function clear_highlights(state)
	for region_id, highlight in pairs(state.highlights) do
		if highlight and highlight.valid then
			highlight.destroy()
		end
	end
	state.highlights = {}
end

-- Internal helper to clear tooltips
local function clear_tooltips(state)
	for region_id, tooltip_objs in pairs(state.tooltips) do
		interaction.destroy_render_objects(tooltip_objs)
	end
	state.tooltips = {}
end

---Create an interactive line graph
---@param surface LuaSurface The rendering surface
---@param chunk table The allocated chunk
---@param options table Rendering options (same as render_line_graph plus interaction options)
---@return InteractiveChartState state The chart state
function interactive_chart.create_line_graph(surface, chunk, options)
	local state = {
		id = generate_chart_id(),
		chart_type = "line_graph",
		chunk = chunk,
		surface = surface,
		hit_regions = {},
		render_ids = {},
		highlights = {},
		tooltips = {},

		selected_series = options.selected_series,
		hovered_region = nil,
		options = options,
		metadata = nil,
		ordered_sums = nil,
	}

	-- Initial render
	interactive_chart.redraw_line_graph(state)

	return state
end

---Redraw a line graph (internal)
---@param state InteractiveChartState
function interactive_chart.redraw_line_graph(state)
	clear_render_objects(state)
	clear_highlights(state)
	clear_tooltips(state)

	local ordered_sums, line_ids, metadata = line_graph.render_with_metadata(
		state.surface,
		state.chunk,
		state.options
	)

	state.render_ids = line_ids or {}
	state.metadata = metadata
	state.ordered_sums = ordered_sums

	-- Generate hit regions if we have metadata
	if metadata then
		state.hit_regions = interaction.create_line_graph_hit_regions(
			state.chunk,
			metadata,
			{point_radius = state.options.hit_radius or 0.3}
		)
	else
		state.hit_regions = {}
	end
end

---Update an interactive line graph with new data
---@param state InteractiveChartState Existing chart state
---@param options table New options (merged with existing)
function interactive_chart.update_line_graph(state, options)
	-- Merge new options with existing
	for key, value in pairs(options) do
		state.options[key] = value
	end

	interactive_chart.redraw_line_graph(state)
end

---Create an interactive bar chart
---@param surface LuaSurface The rendering surface
---@param chunk table The allocated chunk
---@param options table Rendering options (same as render_stacked_bars plus interaction options)
---@return InteractiveChartState state The chart state
function interactive_chart.create_bar_chart(surface, chunk, options)
	local state = {
		id = generate_chart_id(),
		chart_type = "bar_chart",
		chunk = chunk,
		surface = surface,
		hit_regions = {},
		render_ids = {},
		highlights = {},
		tooltips = {},

		selected_series = nil,
		hovered_region = nil,
		options = options,
		metadata = nil,
		ordered_sums = nil,
	}

	-- Initial render
	interactive_chart.redraw_bar_chart(state)

	return state
end

---Redraw a bar chart (internal)
---@param state InteractiveChartState
function interactive_chart.redraw_bar_chart(state)
	clear_render_objects(state)
	clear_highlights(state)
	clear_tooltips(state)

	local line_ids, metadata = bar_chart.render_with_metadata(
		state.surface,
		state.chunk,
		state.options
	)

	state.render_ids = line_ids or {}
	state.metadata = metadata

	-- Generate hit regions if we have metadata
	if metadata then
		state.hit_regions = interaction.create_bar_chart_hit_regions(
			state.chunk,
			metadata
		)
	else
		state.hit_regions = {}
	end
end

---Update an interactive bar chart with new data
---@param state InteractiveChartState Existing chart state
---@param options table New options (merged with existing)
function interactive_chart.update_bar_chart(state, options)
	-- Merge new options with existing
	for key, value in pairs(options) do
		state.options[key] = value
	end

	interactive_chart.redraw_bar_chart(state)
end

---Get hit regions for a chart (for manual hit testing)
---@param state InteractiveChartState
---@return HitRegion[]
function interactive_chart.get_hit_regions(state)
	return state.hit_regions
end

---Handle hover event
---@param state InteractiveChartState The chart state
---@param region_id string The region ID being hovered
---@param player LuaPlayer? The player (for per-player tooltips)
function interactive_chart.on_hover(state, region_id, player)
	-- Find the region
	local region = nil
	for _, r in ipairs(state.hit_regions) do
		if r.id == region_id then
			region = r
			break
		end
	end

	if not region then
		return
	end

	-- Clear previous hover state
	if state.hovered_region and state.hovered_region ~= region_id then
		interactive_chart.on_hover_leave(state, state.hovered_region)
	end

	state.hovered_region = region_id

	-- Create highlight
	if not state.highlights[region_id] then
		state.highlights[region_id] = interaction.create_highlight(
			state.surface,
			region,
			{
				color = {r = 1, g = 1, b = 1, a = 0.4},
				ttl = state.options.ttl or 360,
				width = 2,
			}
		)
	end

	-- Create tooltip
	if not state.tooltips[region_id] then
		local lines = interactive_chart.format_tooltip(state, region)
		local tooltip_pos = {
			x = (region.tile_bounds.left + region.tile_bounds.right) / 2,
			y = region.tile_bounds.top,
		}
		state.tooltips[region_id] = interaction.create_tooltip(
			state.surface,
			tooltip_pos,
			lines,
			{
				ttl = state.options.ttl or 360,
				scale = 0.7,
				offset = {x = 0, y = -0.8},
			}
		)
	end

	-- Call user callback if provided
	if state.options.on_hover then
		state.options.on_hover(region, state)
	end
end

---Handle hover leave event
---@param state InteractiveChartState The chart state
---@param region_id string The region ID being left
function interactive_chart.on_hover_leave(state, region_id)
	-- Destroy highlight
	if state.highlights[region_id] then
		if state.highlights[region_id].valid then
			state.highlights[region_id].destroy()
		end
		state.highlights[region_id] = nil
	end

	-- Destroy tooltip
	if state.tooltips[region_id] then
		interaction.destroy_render_objects(state.tooltips[region_id])
		state.tooltips[region_id] = nil
	end

	if state.hovered_region == region_id then
		state.hovered_region = nil
	end

	-- Call user callback if provided
	if state.options.on_hover_leave then
		state.options.on_hover_leave(region_id, state)
	end
end

---Handle click event
---@param state InteractiveChartState The chart state
---@param region_id string The region ID being clicked
---@param button defines.mouse_button_type The mouse button
---@param player LuaPlayer? The player
function interactive_chart.on_click(state, region_id, button, player)
	-- Find the region
	local region = nil
	for _, r in ipairs(state.hit_regions) do
		if r.id == region_id then
			region = r
			break
		end
	end

	if not region then
		return
	end

	-- Call user callback if provided
	if state.options.on_click then
		state.options.on_click(region, button, state)
	end
end

---Format tooltip lines for a region
---@param state InteractiveChartState
---@param region HitRegion
---@return string[] lines
function interactive_chart.format_tooltip(state, region)
	local lines = {}

	if region.type == "data_point" then
		lines[1] = region.data.series_name
		if type(state.options.label_format) == "function" then
			lines[2] = state.options.label_format(region.data.value)
		elseif state.options.label_format == "time" then
			lines[2] = format_module.time_detailed(region.data.value)
		else
			lines[2] = format_module.percent_label(region.data.value)
		end
	elseif region.type == "bar_segment" then
		lines[1] = region.data.phase_name
		lines[2] = format_module.time_detailed(region.data.duration)
	elseif region.type == "legend_item" then
		lines[1] = region.data.series_name
	end

	-- Allow user to customize tooltip
	if state.options.format_tooltip then
		lines = state.options.format_tooltip(region, lines, state)
	end

	return lines
end

---Toggle series visibility
---@param state InteractiveChartState The chart state
---@param series_name string The series to toggle
function interactive_chart.toggle_series(state, series_name)
	if state.chart_type ~= "line_graph" then
		return
	end

	state.selected_series = state.selected_series or {}
	local is_visible = state.selected_series[series_name] ~= false
	state.selected_series[series_name] = not is_visible

	state.options.selected_series = state.selected_series

	interactive_chart.redraw_line_graph(state)
end

---Cleanup all resources
---@param state InteractiveChartState The chart state
function interactive_chart.destroy(state)
	clear_render_objects(state)
	clear_highlights(state)
	clear_tooltips(state)
end

---Get overlay button configurations for a camera widget
---@param state InteractiveChartState The chart state
---@param camera_position table Camera center in tile coordinates
---@param camera_zoom number Zoom level
---@param widget_size table {width, height} in pixels
---@return table[] button_configs
function interactive_chart.get_overlay_buttons(state, camera_position, camera_zoom, widget_size)
	return interaction.generate_overlay_buttons(
		camera_position,
		camera_zoom,
		widget_size,
		state.hit_regions
	)
end

---Perform hit test at a tile position
---@param state InteractiveChartState The chart state
---@param tile_pos table {x, y} in tile coordinates
---@return HitRegion? region
function interactive_chart.hit_test(state, tile_pos)
	return interaction.hit_test(state.hit_regions, tile_pos)
end

---Perform hit test from screen position
---@param state InteractiveChartState The chart state
---@param camera_position table Camera center in tile coordinates
---@param camera_zoom number Zoom level
---@param widget_size table {width, height} in pixels
---@param screen_pos table {x, y} in widget-local pixels
---@return HitRegion? region
function interactive_chart.hit_test_screen(state, camera_position, camera_zoom, widget_size, screen_pos)
	local tile_pos = interaction.screen_to_tile(camera_position, camera_zoom, widget_size, screen_pos)
	return interaction.hit_test(state.hit_regions, tile_pos)
end

return interactive_chart
