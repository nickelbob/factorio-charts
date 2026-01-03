-- Stacked bar chart rendering
local bar_chart = {}

local colors_module = require("colors")
local format_module = require("format")

---Render a stacked bar chart to a chunk
---@param surface LuaSurface The rendering surface
---@param chunk table The chunk with coord
---@param options table Rendering options
---  - deliveries: table[] Array of data objects with phase durations
---  - phase_colors: table {[phase_name]: color}
---  - phase_order: string[] Order of phases from bottom to top
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
	local graph_right = viewport_width / 32 - 1
	local graph_top = 1
	local graph_bottom = viewport_height / 32 - 2.25

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

				local left_top = {
					entity_pos.x + bar_x,
					entity_pos.y + bar_bottom - cumulative_height - segment_height
				}
				local right_bottom = {
					entity_pos.x + bar_x + bar_width,
					entity_pos.y + bar_bottom - cumulative_height
				}

				local id = rendering.draw_rectangle{
					surface = surface,
					color = phase_colors[phase],
					filled = true,
					left_top = left_top,
					right_bottom = right_bottom,
					time_to_live = ttl,
				}
				line_ids[#line_ids + 1] = id

				cumulative_height = cumulative_height + segment_height
			end
		end
	end

	return line_ids
end

return bar_chart
