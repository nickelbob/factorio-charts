-- Stacked bar chart rendering
local bar_chart = {}

local colors_module = require("colors")
local format_module = require("format")
local interaction_module = require("interaction")

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
	local graph_right = viewport_width / 32 - 0.5  -- Reduced right margin for better fill
	local graph_top = 1
	local graph_bottom = viewport_height / 32 - 1.5  -- Reduced bottom margin

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

	-- Add 10% padding to max
	max_total = max_total * 1.1

	-- Bar dimensions
	local num_bars = #deliveries
	local bar_spacing = 0.1
	local total_spacing = bar_spacing * (num_bars + 1)
	local bar_width = (graph_width - total_spacing) / num_bars
	if bar_width > 1.5 then
		bar_width = 1.5
	end

	-- Recalculate spacing with capped bar width
	local total_bar_width = bar_width * num_bars
	local remaining_space = graph_width - total_bar_width
	bar_spacing = remaining_space / (num_bars + 1)

	-- Draw Y-axis grid lines and labels
	local num_grid_lines = 5
	for i = 0, num_grid_lines - 1 do
		local grid_value = (max_total * i / (num_grid_lines - 1))
		local grid_y = graph_bottom - (grid_value / max_total) * graph_height

		-- Grid line
		local id = rendering.draw_line{
			surface = surface,
			color = grid_color,
			width = 1,
			from = {entity_pos.x + graph_left, entity_pos.y + grid_y},
			to = {entity_pos.x + graph_right, entity_pos.y + grid_y},
			time_to_live = ttl,
		}
		line_ids[#line_ids + 1] = id

		-- Y-axis label
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

		-- Draw each phase segment from bottom to top
		for _, phase in ipairs(phase_order) do
			local phase_duration = delivery[phase] or 0
			if phase_duration > 0 then
				local segment_height = (phase_duration / max_total) * graph_height

				local seg_left = entity_pos.x + bar_x
				local seg_right = entity_pos.x + bar_x + bar_width
				local seg_top = entity_pos.y + bar_bottom - cumulative_height - segment_height
				local seg_bottom = entity_pos.y + bar_bottom - cumulative_height

				local left_top = {seg_left, seg_top}
				local right_bottom = {seg_right, seg_bottom}

				local id = rendering.draw_rectangle{
					surface = surface,
					color = phase_colors[phase],
					filled = true,
					left_top = left_top,
					right_bottom = right_bottom,
					time_to_live = ttl,
				}
				line_ids[#line_ids + 1] = id

				-- Draw diagonal stripes for hatched phases
				if hatched_phases[phase] then
					local stripe_spacing = 0.15
					local stripe_color = {r = 0, g = 0, b = 0, a = 0.4}  -- Semi-transparent black
					local seg_width = seg_right - seg_left
					local seg_height_actual = seg_bottom - seg_top

					-- Draw diagonal lines from bottom-left to top-right
					local num_stripes = math.ceil((seg_width + seg_height_actual) / stripe_spacing)
					for i = 0, num_stripes do
						local offset = i * stripe_spacing
						-- Line starts from left edge or bottom edge
						local start_x = seg_left + offset
						local start_y = seg_bottom
						if start_x > seg_right then
							start_y = seg_bottom - (start_x - seg_right)
							start_x = seg_right
						end
						-- Line ends at top edge or right edge
						local end_x = seg_left + offset - seg_height_actual
						local end_y = seg_top
						if end_x < seg_left then
							end_y = seg_top + (seg_left - end_x)
							end_x = seg_left
						end

						-- Only draw if line is within bounds
						if start_y >= seg_top and end_y <= seg_bottom and start_x >= seg_left and end_x <= seg_right then
							local stripe_id = rendering.draw_line{
								surface = surface,
								color = stripe_color,
								width = 1,
								from = {start_x, start_y},
								to = {end_x, end_y},
								time_to_live = ttl,
							}
							line_ids[#line_ids + 1] = stripe_id
						end
					end
				end

				cumulative_height = cumulative_height + segment_height
			end
		end
	end

	return line_ids
end

---Render stacked bars and return metadata for interaction
---Same as render() but also returns segment bounds for hit region generation
---@param surface LuaSurface The rendering surface
---@param chunk table The chunk with coord
---@param options table Same rendering options as render()
---@return LuaRenderObject[]? line_ids Array of render object IDs
---@return table? metadata Bar metadata for interaction
function bar_chart.render_with_metadata(surface, chunk, options)
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
	local graph_right = viewport_width / 32 - 0.5  -- Reduced right margin for better fill
	local graph_top = 1
	local graph_bottom = viewport_height / 32 - 1.5  -- Reduced bottom margin

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

	-- Add 10% padding to max
	max_total = max_total * 1.1

	-- Bar dimensions
	local num_bars = #deliveries
	local bar_spacing = 0.1
	local total_spacing = bar_spacing * (num_bars + 1)
	local bar_width = (graph_width - total_spacing) / num_bars
	if bar_width > 1.5 then
		bar_width = 1.5
	end

	-- Recalculate spacing with capped bar width
	local total_bar_width = bar_width * num_bars
	local remaining_space = graph_width - total_bar_width
	bar_spacing = remaining_space / (num_bars + 1)

	-- Initialize metadata
	local bar_positions = {}
	local segment_bounds = {}

	-- Draw Y-axis grid lines and labels
	local num_grid_lines = 5
	for i = 0, num_grid_lines - 1 do
		local grid_value = (max_total * i / (num_grid_lines - 1))
		local grid_y = graph_bottom - (grid_value / max_total) * graph_height

		-- Grid line
		local id = rendering.draw_line{
			surface = surface,
			color = grid_color,
			width = 1,
			from = {entity_pos.x + graph_left, entity_pos.y + grid_y},
			to = {entity_pos.x + graph_right, entity_pos.y + grid_y},
			time_to_live = ttl,
		}
		line_ids[#line_ids + 1] = id

		-- Y-axis label
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

	-- Draw stacked bars and track segment bounds
	for bar_idx, delivery in ipairs(deliveries) do
		local bar_x = graph_left + bar_spacing + (bar_idx - 1) * (bar_width + bar_spacing)
		local bar_bottom = graph_bottom
		local cumulative_height = 0

		-- Record bar position
		bar_positions[bar_idx] = {
			x = bar_x,
			width = bar_width,
		}
		segment_bounds[bar_idx] = {}

		-- Draw each phase segment from bottom to top
		for _, phase in ipairs(phase_order) do
			local phase_duration = delivery[phase] or 0
			if phase_duration > 0 then
				local segment_height = (phase_duration / max_total) * graph_height

				local seg_left = entity_pos.x + bar_x
				local seg_right = entity_pos.x + bar_x + bar_width
				local seg_top = entity_pos.y + bar_bottom - cumulative_height - segment_height
				local seg_bottom = entity_pos.y + bar_bottom - cumulative_height

				local left_top = {seg_left, seg_top}
				local right_bottom = {seg_right, seg_bottom}

				local id = rendering.draw_rectangle{
					surface = surface,
					color = phase_colors[phase],
					filled = true,
					left_top = left_top,
					right_bottom = right_bottom,
					time_to_live = ttl,
				}
				line_ids[#line_ids + 1] = id

				-- Record segment bounds (in graph-local coordinates, without entity_pos offset)
				segment_bounds[bar_idx][phase] = {
					left = bar_x,
					top = bar_bottom - cumulative_height - segment_height,
					right = bar_x + bar_width,
					bottom = bar_bottom - cumulative_height,
					duration = phase_duration,
					color = phase_colors[phase],
					delivery = delivery,
				}

				-- Draw diagonal stripes for hatched phases
				if hatched_phases[phase] then
					local stripe_spacing = 0.15
					local stripe_color = {r = 0, g = 0, b = 0, a = 0.4}  -- Semi-transparent black
					local seg_width = seg_right - seg_left
					local seg_height_actual = seg_bottom - seg_top

					-- Draw diagonal lines from bottom-left to top-right
					local num_stripes = math.ceil((seg_width + seg_height_actual) / stripe_spacing)
					for i = 0, num_stripes do
						local offset = i * stripe_spacing
						-- Line starts from left edge or bottom edge
						local start_x = seg_left + offset
						local start_y = seg_bottom
						if start_x > seg_right then
							start_y = seg_bottom - (start_x - seg_right)
							start_x = seg_right
						end
						-- Line ends at top edge or right edge
						local end_x = seg_left + offset - seg_height_actual
						local end_y = seg_top
						if end_x < seg_left then
							end_y = seg_top + (seg_left - end_x)
							end_x = seg_left
						end

						-- Only draw if line is within bounds
						if start_y >= seg_top and end_y <= seg_bottom and start_x >= seg_left and end_x <= seg_right then
							local stripe_id = rendering.draw_line{
								surface = surface,
								color = stripe_color,
								width = 1,
								from = {start_x, start_y},
								to = {end_x, end_y},
								time_to_live = ttl,
							}
							line_ids[#line_ids + 1] = stripe_id
						end
					end
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

	return line_ids, metadata
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
	if not chunk or not chunk.coord then
		return nil
	end

	local camera_position = options.camera_position
	local camera_zoom = options.camera_zoom
	local widget_size = options.widget_size
	local get_tooltip = options.get_tooltip

	if not camera_position or not camera_zoom or not widget_size then
		return nil
	end

	-- Render the chart and get metadata
	local line_ids, metadata = bar_chart.render_with_metadata(surface, chunk, options)
	if not line_ids or not metadata then
		return nil
	end

	-- Create hit regions from metadata
	local hit_regions = interaction_module.create_bar_chart_hit_regions(chunk, metadata)

	-- Generate overlay button configs
	local button_configs = {}
	local pixels_per_tile = 32 * camera_zoom
	local center_x = widget_size.width / 2
	local center_y = widget_size.height / 2

	for _, region in ipairs(hit_regions) do
		local bounds = region.tile_bounds

		-- Calculate screen position for region bounds
		local left_screen = center_x + (bounds.left - camera_position.x) * pixels_per_tile
		local top_screen = center_y + (bounds.top - camera_position.y) * pixels_per_tile
		local right_screen = center_x + (bounds.right - camera_position.x) * pixels_per_tile
		local bottom_screen = center_y + (bounds.bottom - camera_position.y) * pixels_per_tile

		local width = math.max(1, math.floor(right_screen - left_screen))
		local height = math.max(1, math.floor(bottom_screen - top_screen))
		local left_margin = math.floor(left_screen)
		local top_margin = math.floor(top_screen)

		-- Only include buttons that are at least partially visible
		if left_margin + width > 0 and left_margin < widget_size.width and
		   top_margin + height > 0 and top_margin < widget_size.height then

			-- Generate tooltip if function provided
			local tooltip = nil
			if get_tooltip then
				local bar_index = region.data.bar_index
				local phase_name = region.data.phase_name
				local duration = region.data.duration
				local delivery = options.deliveries[bar_index]
				tooltip = get_tooltip(bar_index, phase_name, duration, delivery)
			end

			button_configs[#button_configs + 1] = {
				region_id = region.id,
				style_mods = {
					left_margin = left_margin,
					top_margin = top_margin,
					width = width,
					height = height,
				},
				region = region,
				tooltip = tooltip,
			}
		end
	end

	return line_ids, button_configs, metadata
end

return bar_chart
