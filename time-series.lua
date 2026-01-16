-- Multi-resolution time series with cascading aggregation
-- Similar to RRDtool - maintains data at multiple resolutions for efficient long-term storage

local time_series = {}

local line_graph = require("line-graph")
local interaction = require("interaction")

---Create a new interval set from definitions
---@param defs table[] Array of {name, ticks, steps, length} definitions
---  - name: Display name for this interval (e.g., "5s", "1m", "1h")
---  - ticks: How many game ticks between samples at this resolution
---  - steps: How many samples to aggregate before cascading to next interval (nil for last)
---  - length: Ring buffer capacity (number of datapoints to keep)
---@return table[] intervals Array of interval objects
function time_series.create_interval_set(defs)
	local intervals = {}
	for i, def in ipairs(defs) do
		intervals[i] = {
			name = def.name,
			data = {},
			index = 0,
			sum = {},
			counts = {},
			ticks = def.ticks,
			steps = def.steps,
			length = def.length,
			-- GUI tracking fields (for viewer management)
			viewer_count = 0,
			guis = {},
			chunk = nil,
			last_rendered_tick = nil,
			line_ids = {},
		}
	end
	return intervals
end

---Add a datapoint to an interval set with cascading aggregation
---Automatically maintains running sums and counts for efficient averaging,
---and cascades aggregated values to coarser intervals.
---@param intervals table[] The interval set created by create_interval_set
---@param value table {[series_name]: number} The values to add
function time_series.add_datapoint(intervals, value)
	for interval_index, interval in ipairs(intervals) do
		local index = interval.index
		local steps = interval.steps

		-- Remove oldest value from sum and counts
		local old_data = interval.data[index + 1]
		if old_data then
			for k, v in pairs(old_data) do
				interval.counts[k] = interval.counts[k] - 1
				if interval.counts[k] == 0 then
					interval.sum[k] = nil
					interval.counts[k] = nil
				else
					interval.sum[k] = interval.sum[k] - v
				end
			end
		end

		-- Insert new value
		interval.data[index + 1] = value

		-- Update sum and counts
		for k, v in pairs(value) do
			interval.sum[k] = (interval.sum[k] or 0) + v
			interval.counts[k] = (interval.counts[k] or 0) + 1
		end

		-- Advance index
		interval.index = (index + 1) % interval.length

		-- Cascade to next interval if needed
		if steps and interval.index % steps == 0 then
			local start_idx = (interval.index - steps) % interval.length
			local consolidated = {}
			for i = 1, steps do
				local datum = interval.data[start_idx + i]
				if datum then
					for k, v in pairs(datum) do
						consolidated[k] = (consolidated[k] or 0) + v
					end
				end
			end
			for k, v in pairs(consolidated) do
				consolidated[k] = v / steps
			end
			value = consolidated
		else
			break
		end
	end
end

---Get the current average for a series across an interval
---@param interval table A single interval from the interval set
---@param series_name string The series to get the average for
---@return number? average The average value, or nil if no data
function time_series.get_average(interval, series_name)
	local sum = interval.sum[series_name]
	local count = interval.counts[series_name]
	if sum and count and count > 0 then
		return sum / count
	end
	return nil
end

---Get all series averages for an interval
---@param interval table A single interval from the interval set
---@return table averages {[series_name]: average}
function time_series.get_all_averages(interval)
	local averages = {}
	for name, sum in pairs(interval.sum) do
		local count = interval.counts[name]
		if count and count > 0 then
			averages[name] = sum / count
		end
	end
	return averages
end

---Clear all data from an interval set
---@param intervals table[] The interval set to clear
function time_series.clear(intervals)
	for _, interval in ipairs(intervals) do
		interval.data = {}
		interval.index = 0
		interval.sum = {}
		interval.counts = {}
	end
end

---Render a time series interval as a line graph
---Handles render lifecycle: cleanup old renders, render new, generate hit regions, cache results
---@param surface LuaSurface The rendering surface
---@param intervals table[] The interval set created by create_interval_set
---@param interval_index number Which interval to render (1-based)
---@param options table Rendering options
---  - selected_series: table? {[name]: bool} Filter which series to show
---  - y_range: table? {min, max} Fixed Y-axis range (nil for auto-scale)
---  - label_format: string? "percent" (default) or "time"
---  - viewport_width: number? Viewport width in pixels (default 900)
---  - viewport_height: number? Viewport height in pixels (default 700)
---  - point_radius: number? Hit region radius around points (default 0.3)
---@return table? ordered_sums Array of {name, sum} sorted by sum descending
---@return table? hit_regions Hit regions for interaction
function time_series.render(surface, intervals, interval_index, options)
	local interval = intervals[interval_index]
	if not interval or not interval.chunk then
		return nil, nil
	end

	options = options or {}

	-- Avoid re-render on same tick
	if interval.last_rendered_tick == game.tick then
		return interval.ordered_sums, interval.hit_regions
	end
	interval.last_rendered_tick = game.tick

	-- Destroy old lines before drawing new ones
	if interval.line_ids then
		for _, render_obj in ipairs(interval.line_ids) do
			if render_obj.valid then
				render_obj.destroy()
			end
		end
	end
	interval.line_ids = {}

	-- Calculate TTL based on interval's tick rate (at least 6 seconds)
	local ttl = math.max(interval.ticks * 2, 360)

	-- Render the line graph with metadata for interaction
	local ordered_sums, line_ids, metadata = line_graph.render_with_metadata(surface, interval.chunk, {
		data = interval.data,
		index = interval.index,
		length = interval.length,
		counts = interval.counts,
		sum = interval.sum,
		y_range = options.y_range,
		label_format = options.label_format or "percent",
		selected_series = options.selected_series,
		ttl = ttl,
		viewport_width = options.viewport_width,
		viewport_height = options.viewport_height,
	})

	if line_ids then
		interval.line_ids = line_ids
	end

	-- Generate hit regions from metadata
	local hit_regions = nil
	if metadata then
		hit_regions = interaction.create_line_graph_hit_regions(
			interval.chunk,
			metadata,
			{point_radius = options.point_radius or 0.3}
		)
	end

	-- Cache for re-render checks
	interval.ordered_sums = ordered_sums
	interval.hit_regions = hit_regions

	return ordered_sums, hit_regions
end

return time_series
