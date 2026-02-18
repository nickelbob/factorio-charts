-- Stacked bar chart rendering
local bar_chart = {}

local colors_module = require("core/colors")
local format_module = require("core/format")

-- Constants
local STRIPE_SPACING = 0.4  -- Increased from 0.15 for better performance
local STRIPE_COLOR = {r = 0, g = 0, b = 0, a = 0.4}
local MAX_BAR_WIDTH = 1.5
local MAX_TOTAL_PADDING = 1.1
local NUM_GRID_LINES = 5
local DEFAULT_BAR_SPACING = 0.1

---Draw diagonal stripes on a bar segment for hatched phases
---@param surface LuaSurface
---@param seg_left number
---@param seg_top number
---@param seg_right number
---@param seg_bottom number
---@param ttl number
---@param line_ids table Array to append render IDs to
local function draw_hatched_stripes(surface, seg_left, seg_top, seg_right, seg_bottom, ttl, line_ids)
	local seg_width = seg_right - seg_left
	local seg_height = seg_bottom - seg_top

	local num_stripes = math.ceil((seg_width + seg_height) / STRIPE_SPACING)
	for i = 0, num_stripes do
		local offset = i * STRIPE_SPACING
		-- Line starts from left edge or bottom edge
		local start_x = seg_left + offset
		local start_y = seg_bottom
		if start_x > seg_right then
			start_y = seg_bottom - (start_x - seg_right)
			start_x = seg_right
		end
		-- Line ends at top edge or right edge
		local end_x = seg_left + offset - seg_height
		local end_y = seg_top
		if end_x < seg_left then
			end_y = seg_top + (seg_left - end_x)
			end_x = seg_left
		end

		-- Only draw if line is within bounds
		if start_y >= seg_top and end_y <= seg_bottom and start_x >= seg_left and end_x <= seg_right then
			local stripe_id = rendering.draw_line{
				surface = surface,
				color = STRIPE_COLOR,
				width = 1,
				from = {start_x, start_y},
				to = {end_x, end_y},
				time_to_live = ttl,
			}
			line_ids[#line_ids + 1] = stripe_id
		end
	end
end

---Internal render function with optional metadata and overlay generation
---@param surface LuaSurface The rendering surface
---@param chunk table The chunk with coord
---@param options table Rendering options
---@param collect_metadata boolean Whether to collect segment bounds
---@param overlay_info table? Camera info for overlay button generation {camera_position, camera_zoom, widget_size, get_tooltip}
---@return LuaRenderObject[]? line_ids
---@return table? metadata_or_buttons Returns metadata if collect_metadata, button_configs if overlay_info
---@return table? metadata Only returned when overlay_info is provided
local function render_internal(surface, chunk, options, collect_metadata, overlay_info)
	if not chunk or not chunk.coord then
		return nil
	end

	local deliveries = options.deliveries
	local phase_colors = options.phase_colors
	local phase_order = options.phase_order
	local hatched_phases = options.hatched_phases or {}
	local ttl = options.ttl or 360
	local viewport_width = options.viewport_width or 900
	local viewport_height = options.viewport_height or 700

	if #deliveries == 0 then
		return nil
	end

	local grid_color = colors_module.get_grid_color()
	local label_color = colors_module.get_label_color()

	-- Graph coordinates
	local graph_left = 1.5
	local graph_right = viewport_width / 32 - 0.5
	local graph_top = 1
	local graph_bottom = viewport_height / 32 - 1.5

	local graph_width = graph_right - graph_left
	local graph_height = graph_bottom - graph_top

	local entity_pos = chunk.coord
	local line_ids = {}

	-- Calculate max total time for Y-axis scaling
	local max_total = 0
	for _, delivery in ipairs(deliveries) do
		local total = 0
		for _, phase in ipairs(phase_order) do
			total = total + (delivery[phase] or 0)
		end
		if total > max_total then
			max_total = total
		end
	end

	if max_total == 0 then
		max_total = 1
	end

	max_total = max_total * MAX_TOTAL_PADDING

	-- Bar dimensions
	local num_bars = #deliveries
	local bar_spacing = DEFAULT_BAR_SPACING
	local total_spacing = bar_spacing * (num_bars + 1)
	local bar_width = (graph_width - total_spacing) / num_bars
	if bar_width > MAX_BAR_WIDTH then
		bar_width = MAX_BAR_WIDTH
	end

	-- Recalculate spacing with capped bar width
	local total_bar_width = bar_width * num_bars
	local remaining_space = graph_width - total_bar_width
	bar_spacing = remaining_space / (num_bars + 1)

	-- Initialize metadata collection if requested
	local bar_positions = nil
	local segment_bounds = nil
	if collect_metadata then
		bar_positions = {}
		segment_bounds = {}
	end

	-- Initialize overlay generation if requested
	local button_configs = nil
	local pixels_per_tile, screen_center_x, screen_center_y
	local camera_position, widget_size, get_tooltip
	if overlay_info then
		button_configs = {}
		camera_position = overlay_info.camera_position
		widget_size = overlay_info.widget_size
		get_tooltip = overlay_info.get_tooltip
		pixels_per_tile = 32 * overlay_info.camera_zoom
		screen_center_x = widget_size.width / 2
		screen_center_y = widget_size.height / 2
	end

	-- Draw Y-axis grid lines and labels
	for i = 0, NUM_GRID_LINES - 1 do
		local grid_value = (max_total * i / (NUM_GRID_LINES - 1))
		local grid_y = graph_bottom - (grid_value / max_total) * graph_height

		local id = rendering.draw_line{
			surface = surface,
			color = grid_color,
			width = 1,
			from = {entity_pos.x + graph_left, entity_pos.y + grid_y},
			to = {entity_pos.x + graph_right, entity_pos.y + grid_y},
			time_to_live = ttl,
		}
		line_ids[#line_ids + 1] = id

		local text_id = rendering.draw_text{
			text = format_module.time_label(grid_value),
			surface = surface,
			target = {entity_pos.x + graph_left - 0.2, entity_pos.y + grid_y},
			color = label_color,
			scale = 0.8,
			alignment = "right",
			vertical_alignment = "middle",
			time_to_live = ttl,
		}
		line_ids[#line_ids + 1] = text_id
	end

	-- Draw stacked bars
	for bar_idx, delivery in ipairs(deliveries) do
		local bar_x = graph_left + bar_spacing + (bar_idx - 1) * (bar_width + bar_spacing)
		local bar_bottom = graph_bottom
		local cumulative_height = 0

		-- Record bar position if collecting metadata
		if bar_positions then
			bar_positions[bar_idx] = {
				x = bar_x,
				width = bar_width,
			}
			segment_bounds[bar_idx] = {}
		end

		-- Draw each phase segment from bottom to top
		for _, phase in ipairs(phase_order) do
			local phase_duration = delivery[phase] or 0
			if phase_duration > 0 then
				local segment_height = (phase_duration / max_total) * graph_height

				local seg_left = entity_pos.x + bar_x
				local seg_right = entity_pos.x + bar_x + bar_width
				local seg_top = entity_pos.y + bar_bottom - cumulative_height - segment_height
				local seg_bottom = entity_pos.y + bar_bottom - cumulative_height

				-- Draw the bar segment
				local id = rendering.draw_rectangle{
					surface = surface,
					color = phase_colors[phase],
					filled = true,
					left_top = {seg_left, seg_top},
					right_bottom = {seg_right, seg_bottom},
					time_to_live = ttl,
				}
				line_ids[#line_ids + 1] = id

				-- Record segment bounds if collecting metadata
				if segment_bounds then
					segment_bounds[bar_idx][phase] = {
						left = bar_x,
						top = bar_bottom - cumulative_height - segment_height,
						right = bar_x + bar_width,
						bottom = bar_bottom - cumulative_height,
						duration = phase_duration,
						color = phase_colors[phase],
						delivery = delivery,
					}
				end

				-- Generate button config if generating overlays
				if button_configs then
					local left_screen = screen_center_x + (seg_left - camera_position.x) * pixels_per_tile
					local top_screen = screen_center_y + (seg_top - camera_position.y) * pixels_per_tile
					local right_screen = screen_center_x + (seg_right - camera_position.x) * pixels_per_tile
					local bottom_screen = screen_center_y + (seg_bottom - camera_position.y) * pixels_per_tile

					local btn_width = math.max(1, math.floor(right_screen - left_screen))
					local btn_height = math.max(1, math.floor(bottom_screen - top_screen))
					local left_margin = math.floor(left_screen)
					local top_margin = math.floor(top_screen)

					-- Only include buttons that are at least partially visible
					if left_margin + btn_width > 0 and left_margin < widget_size.width and
					   top_margin + btn_height > 0 and top_margin < widget_size.height then

						local tooltip = nil
						if get_tooltip then
							tooltip = get_tooltip(bar_idx, phase, phase_duration, delivery)
						end

						button_configs[#button_configs + 1] = {
							region_id = "bar_" .. bar_idx .. "_" .. phase,
							style_mods = {
								left_margin = left_margin,
								top_margin = top_margin,
								width = btn_width,
								height = btn_height,
							},
							region = {
								tile_bounds = {
									left = seg_left,
									top = seg_top,
									right = seg_right,
									bottom = seg_bottom,
								},
								data = {
									bar_index = bar_idx,
									phase_name = phase,
									duration = phase_duration,
								},
							},
							tooltip = tooltip,
						}
					end
				end

				-- Draw diagonal stripes for hatched phases
				if hatched_phases[phase] then
					draw_hatched_stripes(surface, seg_left, seg_top, seg_right, seg_bottom, ttl, line_ids)
				end

				cumulative_height = cumulative_height + segment_height
			end
		end
	end

	-- Build metadata
	local metadata = {
		graph_left = graph_left,
		graph_right = graph_right,
		graph_top = graph_top,
		graph_bottom = graph_bottom,
		graph_width = graph_width,
		graph_height = graph_height,
		max_total = max_total,
		bar_width = bar_width,
		bar_spacing = bar_spacing,
		bar_positions = bar_positions,
		segment_bounds = segment_bounds,
	}

	-- Return based on what was requested
	if overlay_info then
		return line_ids, button_configs, metadata
	elseif collect_metadata then
		return line_ids, metadata
	else
		return line_ids
	end
end

---Render a stacked bar chart to a chunk
---@param surface LuaSurface The rendering surface
---@param chunk table The chunk with coord
---@param options table Rendering options
---  - deliveries: table[] Array of data objects with phase durations
---  - phase_colors: table {[phase_name]: color}
---  - phase_order: string[] Order of phases from bottom to top
---  - hatched_phases: table? {[phase_name]: true} Phases to draw with diagonal stripes
---  - ttl: number? Time to live in ticks (default 360)
---  - viewport_width: number? Viewport width in pixels (default 900)
---  - viewport_height: number? Viewport height in pixels (default 700)
---@return table? line_ids Array of render object IDs
function bar_chart.render(surface, chunk, options)
	return render_internal(surface, chunk, options, false, nil)
end

---Render stacked bars and return metadata for interaction
---Same as render() but also returns segment bounds for hit region generation
---@param surface LuaSurface The rendering surface
---@param chunk table The chunk with coord
---@param options table Same rendering options as render()
---@return LuaRenderObject[]? line_ids Array of render object IDs
---@return table? metadata Bar metadata for interaction
function bar_chart.render_with_metadata(surface, chunk, options)
	return render_internal(surface, chunk, options, true, nil)
end

---Render stacked bars with overlay button configurations for GUI integration
---This is a higher-level function that combines rendering, hit region creation,
---and overlay button generation into a single call.
---
---@param surface LuaSurface The rendering surface
---@param chunk table The chunk with coord
---@param options table Rendering and overlay options
---  - deliveries: table[] Array of data objects with phase durations
---  - phase_colors: table {[phase_name]: color}
---  - phase_order: string[] Order of phases from bottom to top
---  - hatched_phases: table? {[phase_name]: true} Phases to draw with diagonal stripes
---  - ttl: number? Time to live in ticks (default 360)
---  - viewport_width: number? Viewport width in pixels (default 900)
---  - viewport_height: number? Viewport height in pixels (default 700)
---  - camera_position: table {x, y} Camera center position (with any visual offset applied)
---  - camera_zoom: number Camera zoom level
---  - widget_size: table {width, height} Camera widget size in pixels
---  - get_tooltip: function?(bar_index, phase_name, duration, delivery) -> string Optional tooltip generator
---@return LuaRenderObject[]? line_ids Array of render object IDs
---@return table[]? button_configs Array of {region_id, style_mods, region, tooltip}
---@return table? metadata Bar metadata for advanced use
function bar_chart.render_with_overlays(surface, chunk, options)
	local camera_position = options.camera_position
	local camera_zoom = options.camera_zoom
	local widget_size = options.widget_size

	if not camera_position or not camera_zoom or not widget_size then
		return nil
	end

	local overlay_info = {
		camera_position = camera_position,
		camera_zoom = camera_zoom,
		widget_size = widget_size,
		get_tooltip = options.get_tooltip,
	}

	return render_internal(surface, chunk, options, true, overlay_info)
end

return bar_chart
