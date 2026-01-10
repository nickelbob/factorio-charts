-- Surface and chunk management for chart rendering
local rendering_module = {}

-- Default viewport dimensions (pixels at zoom=1)
local DEFAULT_VIEWPORT_WIDTH = 900
local DEFAULT_VIEWPORT_HEIGHT = 700

---Configure surface brightness settings for chart visibility
---@param surface LuaSurface
local function configure_surface_brightness(surface)
	surface.daytime = 0.5
	surface.freeze_daytime = true
end

---Create a chart rendering surface and associated data structure
---@param surface_name string Unique name for the surface
---@param options table? Optional settings {viewport_width, viewport_height}
---@return table surface_data {surface, viewport_width, viewport_height, chunk_freelist, next_chunk_x, next_chunk_y}
function rendering_module.create_surface(surface_name, options)
	options = options or {}
	local viewport_width = options.viewport_width or DEFAULT_VIEWPORT_WIDTH
	local viewport_height = options.viewport_height or DEFAULT_VIEWPORT_HEIGHT

	-- Create or get the surface
	local surface = game.get_surface(surface_name)
	if not surface then
		surface = game.create_surface(surface_name, {
			width = 1,
			height = 1,
		})
	end
	configure_surface_brightness(surface)

	return {
		surface = surface,
		viewport_width = viewport_width,
		viewport_height = viewport_height,
		chunk_freelist = {},
		next_chunk_x = 0,
		next_chunk_y = 0,
	}
end

---Allocate a chunk for graph rendering
---@param surface_data table The surface data from create_surface
---@return table chunk {coord, light_ids}
function rendering_module.allocate_chunk(surface_data)
	local chunk_coord

	local length = #surface_data.chunk_freelist
	if length > 0 then
		chunk_coord = surface_data.chunk_freelist[length]
		surface_data.chunk_freelist[length] = nil
	else
		chunk_coord = {
			x = surface_data.next_chunk_x * 32,
			y = surface_data.next_chunk_y * 32
		}
		-- Diagonal chunk allocation pattern
		if surface_data.next_chunk_x == 0 then
			surface_data.next_chunk_x = surface_data.next_chunk_y + 1
			surface_data.next_chunk_y = 0
		else
			surface_data.next_chunk_x = surface_data.next_chunk_x - 1
			surface_data.next_chunk_y = surface_data.next_chunk_y + 1
		end

		-- Create dark tiles for graph background
		local tiles = {}
		local i = 1
		for x = chunk_coord.x, chunk_coord.x + 31 do
			for y = chunk_coord.y, chunk_coord.y + 31 do
				tiles[i] = {name = "lab-dark-1", position = {x = x, y = y}}
				i = i + 1
			end
		end
		surface_data.surface.set_tiles(tiles)
	end

	-- Add multiple bright lights to illuminate the graph area
	local light_ids = {}
	for lx = 0, 2 do
		for ly = 0, 2 do
			local light_id = rendering.draw_light{
				sprite = "utility/light_medium",
				scale = 50,
				intensity = 10,
				minimum_darkness = 0,
				target = {chunk_coord.x + 5 + lx * 10, chunk_coord.y + 3 + ly * 7},
				surface = surface_data.surface,
			}
			table.insert(light_ids, light_id)
		end
	end

	return {coord = chunk_coord, light_ids = light_ids}
end

---Free a chunk back to the pool
---@param surface_data table The surface data
---@param chunk table The chunk to free
function rendering_module.free_chunk(surface_data, chunk)
	if chunk.light_ids then
		for _, light_id in ipairs(chunk.light_ids) do
			if light_id.valid then
				light_id.destroy()
			end
		end
	end
	table.insert(surface_data.chunk_freelist, chunk.coord)
end

---Get the viewport dimensions
---@param surface_data table The surface data
---@return number width, number height
function rendering_module.get_viewport_size(surface_data)
	return surface_data.viewport_width, surface_data.viewport_height
end

---Calculate camera position and zoom for proper chart display
---This function computes the correct camera parameters to display a chart
---at any widget size, making the library resolution-independent.
---
---The viewport dimensions define the "design size" used for graph layout.
---The widget size is the actual GUI camera element dimensions.
---This function calculates the zoom needed to fit the graph into the widget
---and centers the camera on the graph area.
---
---@param chunk table The chunk with coord from allocate_chunk()
---@param options table Camera calculation options
---  - viewport_width: number? Design viewport width in pixels (default 900)
---  - viewport_height: number? Design viewport height in pixels (default 700)
---  - widget_width: number Actual camera widget width in pixels
---  - widget_height: number Actual camera widget height in pixels
---  - left_margin: number? Extra tiles on left for y-axis labels (default 0)
---  - fit_mode: string? "fit" (default), "fill", or "stretch"
---    - "fit": Zoom to show entire graph, may have letterboxing
---    - "fill": Zoom to fill widget, graph may be cropped
---    - "stretch": Independent x/y zoom (not recommended, distorts)
---@return table camera_params {position, zoom, zoom_x?, zoom_y?, offset?}
function rendering_module.get_camera_params(chunk, options)
	local viewport_width = options.viewport_width or DEFAULT_VIEWPORT_WIDTH
	local viewport_height = options.viewport_height or DEFAULT_VIEWPORT_HEIGHT
	local widget_width = options.widget_width
	local widget_height = options.widget_height
	local left_margin = options.left_margin or 0  -- tiles for y-axis label overflow (graph layouts have built-in margins)
	local fit_mode = options.fit_mode or "fit"

	-- Calculate graph extent in tiles (including left margin for labels)
	local graph_tiles_x = viewport_width / 32 + left_margin
	local graph_tiles_y = viewport_height / 32

	-- Effective viewport includes label margin
	local effective_viewport_width = viewport_width + (left_margin * 32)

	-- Calculate zoom needed for each axis
	local zoom_x = widget_width / effective_viewport_width
	local zoom_y = widget_height / viewport_height

	-- Determine final zoom based on fit mode
	local zoom
	if fit_mode == "fill" then
		zoom = math.max(zoom_x, zoom_y)
	elseif fit_mode == "stretch" then
		-- For stretch mode, we return both zoom factors
		-- The caller would need to handle this specially
		zoom = zoom_x  -- Primary zoom
	else
		-- Default "fit" mode - show entire graph
		zoom = math.min(zoom_x, zoom_y)
	end

	-- Calculate camera center position
	-- Shift left by half the label margin to include label area
	-- The visible area will be from (-left_margin/2) to (graph_tiles_x - left_margin/2)
	local base_center_x = (viewport_width / 32) / 2  -- center of original viewport
	local center_x = chunk.coord.x + base_center_x - (left_margin / 2)
	local center_y = chunk.coord.y + (viewport_height / 32) / 2

	-- For non-uniform zoom (when aspect ratios differ), calculate offset
	-- This tells the caller how much the graph is offset from widget center
	local offset_x = 0
	local offset_y = 0
	if fit_mode == "fit" then
		-- In fit mode with letterboxing, graph is centered
		-- Calculate the unused space in pixels
		local rendered_width = graph_tiles_x * 32 * zoom
		local rendered_height = graph_tiles_y * 32 * zoom
		offset_x = (widget_width - rendered_width) / 2
		offset_y = (widget_height - rendered_height) / 2
	end

	return {
		position = {x = center_x, y = center_y},
		zoom = zoom,
		-- Additional info for advanced use cases
		zoom_x = zoom_x,
		zoom_y = zoom_y,
		offset = {x = offset_x, y = offset_y},
		-- Graph bounds for reference (including label margin)
		graph_tiles = {x = graph_tiles_x, y = graph_tiles_y},
		-- Effective viewport (including label margin)
		effective_viewport = {width = effective_viewport_width, height = viewport_height},
	}
end

return rendering_module
