-- Line graph rendering
local line_graph = {}

local colors_module = require("colors")
local format_module = require("format")

---Internal render function that optionally collects metadata
---@param surface LuaSurface The rendering surface
---@param chunk table The chunk with coord
---@param options table Rendering options
---@param collect_metadata boolean Whether to collect point positions for interaction
---@return table? ordered_sums Array of {name, sum} sorted by sum descending
---@return LuaRenderObject[]? line_ids Array of render object IDs
---@return table? metadata Graph metadata (only if collect_metadata is true)
local function render_internal(surface, chunk, options, collect_metadata)
	if not chunk or not chunk.coord then
		return nil
	end

	local data = options.data
	local index = options.index
	local length = options.length
	local counts = options.counts
	local sum = options.sum
	local fixed_range = options.y_range
	local label_format = options.label_format or "percent"
	local selected_series = options.selected_series
	local ttl = options.ttl or 360
	local viewport_width = options.viewport_width or 900
	local viewport_height = options.viewport_height or 700

	local series_colors = colors_module.get_series_colors()
	local grid_color = colors_module.get_grid_color()
	local label_color = colors_module.get_label_color()
	local max_lines = colors_module.get_max_series()

	-- Collect and sort ALL series by sum first (for consistent color assignment)
	local all_series = {}
	local all_count = 0
	for name, count in pairs(counts) do
		all_count = all_count + 1
		all_series[all_count] = {name = name, sum = sum[name] or 0}
	end

	if all_count == 0 then
		return nil
	end

	table.sort(all_series, function(a, b)
		if a.sum ~= b.sum then
			return a.sum > b.sum
		end
		return a.name < b.name
	end)

	-- Build color index mapping (series name -> color index based on full sorted list)
	local color_indices = {}
	for i, entry in ipairs(all_series) do
		color_indices[entry.name] = ((i - 1) % max_lines) + 1
	end

	-- Filter to selected series only, preserving sort order
	local show_all = not selected_series or not next(selected_series)
	local ordered_sums = {}
	local datasets = 0
	for _, entry in ipairs(all_series) do
		if show_all or selected_series[entry.name] ~= false then
			datasets = datasets + 1
			ordered_sums[datasets] = {name = entry.name, sum = entry.sum, color_index = color_indices[entry.name]}
		end
	end

	if datasets == 0 then
		return nil
	end

	local to_draw = math.min(datasets, max_lines)

	-- Compute Y-axis range from actual data
	local min_y = math.huge
	local max_y = -math.huge
	local has_data = false
	for i = 1, length do
		local datum = data[i]
		if datum then
			for j = 1, to_draw do
				local name = ordered_sums[j].name
				local val = datum[name]
				if val then
					has_data = true
					if val < min_y then min_y = val end
					if val > max_y then max_y = val end
				end
			end
		end
	end

	if not has_data then
		return nil
	end

	-- Use fixed range if provided
	if fixed_range then
		min_y = fixed_range[1]
		max_y = fixed_range[2]
	else
		if min_y == max_y then
			min_y = min_y - 1
			max_y = max_y + 1
		end
	end

	-- Calculate graph coordinates
	-- graph_left must leave room for y-axis labels
	local graph_left = 2.0
	local graph_right = viewport_width / 32 - 0.5  -- Reduced right margin for better fill
	local graph_top = 1
	local graph_bottom = viewport_height / 32 - 0.5  -- Reduced bottom margin

	local graph_width = graph_right - graph_left
	local graph_height = graph_bottom - graph_top

	local y_range = max_y - min_y
	if y_range == 0 then y_range = 1 end

	local dx = graph_width / (length - 1)
	local dy = graph_height / y_range

	local entity_pos = chunk.coord
	local line_ids = {}

	-- Initialize metadata for point positions (only if collecting)
	local point_positions = nil
	if collect_metadata then
		point_positions = {}
		for j = 1, to_draw do
			point_positions[ordered_sums[j].name] = {}
		end
	end

	-- Draw horizontal grid lines with Y-axis labels
	local num_grid_lines = 5
	for i = 0, num_grid_lines - 1 do
		local grid_value = min_y + (y_range * i / (num_grid_lines - 1))
		local grid_y = graph_bottom - ((grid_value - min_y) * dy)

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
		local label_text
		if label_format == "time" then
			label_text = format_module.time_label(grid_value)
		else
			label_text = format_module.percent_label(grid_value)
		end
		local text_id = rendering.draw_text{
			text = label_text,
			surface = surface,
			target = {entity_pos.x + graph_left - 0.2, entity_pos.y + grid_y},
			color = label_color,
			scale = 1.0,
			alignment = "right",
			vertical_alignment = "middle",
			time_to_live = ttl,
		}
		line_ids[#line_ids + 1] = text_id
	end

	-- Draw lines for each series and optionally track point positions
	local prev = {}
	local x = graph_left

	-- Get first datapoint (oldest)
	local first = data[index + 1]
	if first then
		for j = 1, to_draw do
			local name = ordered_sums[j].name
			local n = first[name]
			if n then
				local y = graph_bottom - ((n - min_y) * dy)
				prev[name] = {x, y}
				-- Record point position if collecting metadata
				if point_positions then
					local points = point_positions[name]
					points[#points + 1] = {
						x = x,
						y = y,
						value = n,
						data_index = index + 1,
					}
				end
			end
		end
	end

	-- Iterate through data in chronological order
	local ranges = {
		{start = index + 2, stop = length},
		{start = 1, stop = index},
	}

	for _, range in ipairs(ranges) do
		for i = range.start, range.stop do
			x = x + dx
			local datum = data[i]
			local next_points = {}

			for j = to_draw, 1, -1 do
				local entry = ordered_sums[j]
				local name = entry.name
				local point = prev[name]
				local n = datum and datum[name]

				if n then
					local y = graph_bottom - ((n - min_y) * dy)
					local to = {x, y}
					next_points[name] = to

					-- Record point position if collecting metadata
					if point_positions then
						local points = point_positions[name]
						points[#points + 1] = {
							x = x,
							y = y,
							value = n,
							data_index = i,
						}
					end

					if point then
						local from_pos = {entity_pos.x + point[1], entity_pos.y + point[2]}
						local to_pos = {entity_pos.x + to[1], entity_pos.y + to[2]}

						local id = rendering.draw_line{
							surface = surface,
							color = series_colors[entry.color_index],
							width = 1,
							from = from_pos,
							to = to_pos,
							time_to_live = ttl,
						}
						line_ids[#line_ids + 1] = id
					end
				else
					next_points[name] = nil
				end
			end
			prev = next_points
		end
	end

	-- Build metadata if collecting
	local metadata = nil
	if collect_metadata then
		metadata = {
			graph_left = graph_left,
			graph_right = graph_right,
			graph_top = graph_top,
			graph_bottom = graph_bottom,
			graph_width = graph_width,
			graph_height = graph_height,
			min_y = min_y,
			max_y = max_y,
			y_range = y_range,
			dx = dx,
			dy = dy,
			point_positions = point_positions,
		}
	end

	return ordered_sums, line_ids, metadata
end

---Render a line graph to a chunk
---@param surface LuaSurface The rendering surface
---@param chunk table The chunk with coord
---@param options table Rendering options
---  - data: table[] Ring buffer of {[series_name]: value}
---  - index: number Current position in ring buffer
---  - length: number Buffer capacity
---  - counts: table {[series_name]: sample_count}
---  - sum: table {[series_name]: total} for calculating averages
---  - y_range: table? {min, max} Fixed Y-axis range (nil for auto-scale)
---  - label_format: string? "percent" (default) or "time"
---  - selected_series: table? {[name]: bool} Filter (nil = show all, false = hide)
---  - ttl: number? Time to live in ticks (default 360)
---  - viewport_width: number? Viewport width in pixels (default 900)
---  - viewport_height: number? Viewport height in pixels (default 700)
---@return table? ordered_sums Array of {name, sum} sorted by sum descending
---@return LuaRenderObject[]? line_ids Array of render object IDs
function line_graph.render(surface, chunk, options)
	local ordered_sums, line_ids = render_internal(surface, chunk, options, false)
	return ordered_sums, line_ids
end

---Render a line graph and return metadata for interaction
---Same as render() but also returns point positions for hit region generation
---@param surface LuaSurface The rendering surface
---@param chunk table The chunk with coord
---@param options table Same rendering options as render()
---@return table? ordered_sums Array of {name, sum} sorted by sum descending
---@return LuaRenderObject[]? line_ids Array of render object IDs
---@return table? metadata Graph metadata for interaction
function line_graph.render_with_metadata(surface, chunk, options)
	return render_internal(surface, chunk, options, true)
end

return line_graph
