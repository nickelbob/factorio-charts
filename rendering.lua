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

	-- Hide the surface from all forces' map view
	for _, force in pairs(game.forces) do
		force.set_surface_hidden(surface, true)
	end

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
---@param options table? Optional settings {viewport_width, viewport_height}
---@return table chunk {coord, light_ids, tiles_width, tiles_height}
function rendering_module.allocate_chunk(surface_data, options)
	options = options or {}
	-- Use provided viewport dimensions, or fall back to surface_data defaults
	local viewport_width = options.viewport_width or surface_data.viewport_width or DEFAULT_VIEWPORT_WIDTH
	local viewport_height = options.viewport_height or surface_data.viewport_height or DEFAULT_VIEWPORT_HEIGHT

	-- Calculate required tile coverage (add margin for graph axes/labels)
	local tiles_width = math.ceil(viewport_width / 32) + 2
	local tiles_height = math.ceil(viewport_height / 32) + 2

	local chunk_coord

	local length = #surface_data.chunk_freelist
	if length > 0 then
		chunk_coord = surface_data.chunk_freelist[length]
		surface_data.chunk_freelist[length] = nil
	else
		-- Use larger spacing for chunks based on viewport size
		local chunk_spacing = math.max(tiles_width, tiles_height, 32)
		chunk_coord = {
			x = surface_data.next_chunk_x * chunk_spacing,
			y = surface_data.next_chunk_y * chunk_spacing
		}
		-- Diagonal chunk allocation pattern
		if surface_data.next_chunk_x == 0 then
			surface_data.next_chunk_x = surface_data.next_chunk_y + 1
			surface_data.next_chunk_y = 0
		else
			surface_data.next_chunk_x = surface_data.next_chunk_x - 1
			surface_data.next_chunk_y = surface_data.next_chunk_y + 1
		end

		-- Create dark tiles for graph background (sized to viewport)
		local tiles = {}
		local i = 1
		for x = chunk_coord.x, chunk_coord.x + tiles_width - 1 do
			for y = chunk_coord.y, chunk_coord.y + tiles_height - 1 do
				tiles[i] = {name = "lab-dark-1", position = {x = x, y = y}}
				i = i + 1
			end
		end
		surface_data.surface.set_tiles(tiles)
	end

	-- Add multiple bright lights to illuminate the graph area
	-- Adjust light positions based on tile coverage
	local light_ids = {}
	local light_spacing_x = tiles_width / 3
	local light_spacing_y = tiles_height / 3
	for lx = 0, 2 do
		for ly = 0, 2 do
			local light_id = rendering.draw_light{
				sprite = "utility/light_medium",
				scale = 50,
				intensity = 10,
				minimum_darkness = 0,
				target = {chunk_coord.x + light_spacing_x * (lx + 0.5), chunk_coord.y + light_spacing_y * (ly + 0.5)},
				surface = surface_data.surface,
			}
			table.insert(light_ids, light_id)
		end
	end

	return {coord = chunk_coord, light_ids = light_ids, tiles_width = tiles_width, tiles_height = tiles_height}
end

---Ensure a chunk has sufficient tile coverage for the given viewport
---Use this to upgrade existing chunks that may have been allocated with smaller dimensions
---@param surface_data table The surface data
---@param chunk table The chunk to ensure coverage for
---@param options table {viewport_width, viewport_height}
function rendering_module.ensure_tile_coverage(surface_data, chunk, options)
	if not chunk or not chunk.coord then return end

	local viewport_width = options.viewport_width or surface_data.viewport_width or DEFAULT_VIEWPORT_WIDTH
	local viewport_height = options.viewport_height or surface_data.viewport_height or DEFAULT_VIEWPORT_HEIGHT

	-- Calculate required tile coverage
	local tiles_width = math.ceil(viewport_width / 32) + 2
	local tiles_height = math.ceil(viewport_height / 32) + 2

	-- Check if we need to expand (only if chunk doesn't already have sufficient coverage)
	local current_width = chunk.tiles_width or 32
	local current_height = chunk.tiles_height or 32

	if tiles_width <= current_width and tiles_height <= current_height then
		return  -- Already have sufficient coverage
	end

	-- Expand to the larger of current and required
	local new_width = math.max(tiles_width, current_width)
	local new_height = math.max(tiles_height, current_height)

	-- Create dark tiles for the expanded area
	local tiles = {}
	local i = 1
	for x = chunk.coord.x, chunk.coord.x + new_width - 1 do
		for y = chunk.coord.y, chunk.coord.y + new_height - 1 do
			tiles[i] = {name = "lab-dark-1", position = {x = x, y = y}}
			i = i + 1
		end
	end
	surface_data.surface.set_tiles(tiles)

	-- Update chunk's recorded tile size
	chunk.tiles_width = new_width
	chunk.tiles_height = new_height
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

---Set up a camera widget to display a chart and return camera info for hit-testing
---This is a convenience function that combines get_camera_params with camera element setup.
---
---@param camera_element LuaGuiElement The camera GUI element to configure
---@param surface LuaSurface The chart rendering surface
---@param chunk table The chunk from allocate_chunk()
---@param options table Setup options
---  - widget_width: number Camera widget width in pixels
---  - widget_height: number Camera widget height in pixels
---  - display_scale: number? Player's display_scale (default 1.0, used for fallback zoom calculation)
---  - position_offset: table? {x, y} Manual position adjustment (default {0, 0})
---  - zoom_override: number? Explicit zoom value (recommended: calculate based on display_scale)
---@return table camera_info {position, zoom, widget_width, widget_height} for hit-testing
function rendering_module.setup_camera_widget(camera_element, surface, chunk, options)
	if not camera_element or not chunk or not chunk.coord then
		return nil
	end

	local widget_width = options.widget_width
	local widget_height = options.widget_height
	local display_scale = options.display_scale or 1.0
	local position_offset = options.position_offset or {x = 0, y = 0}

	-- Get camera parameters
	local camera_params = rendering_module.get_camera_params(chunk, {
		widget_width = widget_width,
		widget_height = widget_height,
	})

	-- Use explicit zoom if provided, otherwise fall back to display_scale-based calculation
	-- Note: The fallback formula (display_scale / 2) may not work well across all resolutions.
	-- Callers should calculate and pass zoom_override based on their specific needs.
	local zoom = options.zoom_override or (display_scale / 2)

	-- Apply position offset
	local position = {
		x = camera_params.position.x + position_offset.x,
		y = camera_params.position.y + position_offset.y,
	}

	-- Configure the camera element
	camera_element.position = position
	camera_element.surface_index = surface.index
	camera_element.zoom = zoom

	-- Return camera info for hit-testing
	return {
		position = position,
		zoom = zoom,
		widget_width = widget_width,
		widget_height = widget_height,
	}
end

---Create a simple render state for non-time-series charts
---Use this when you need chunk + line_ids storage without the full time series machinery.
---
---@param surface_data table The surface data from create_surface()
---@param options table? Optional {viewport_width, viewport_height}
---@return table render_state {chunk, line_ids, last_rendered_tick}
function rendering_module.create_render_state(surface_data, options)
	local chunk = rendering_module.allocate_chunk(surface_data, options)
	return {
		chunk = chunk,
		line_ids = {},
		last_rendered_tick = nil,
	}
end

---Destroy a render state and free its resources
---@param surface_data table The surface data
---@param render_state table The render state to destroy
function rendering_module.destroy_render_state(surface_data, render_state)
	if not render_state then return end

	-- Cleanup render objects
	if render_state.line_ids then
		for _, render_obj in ipairs(render_state.line_ids) do
			if render_obj.valid then
				render_obj.destroy()
			end
		end
		render_state.line_ids = {}
	end

	-- Free chunk back to pool
	if render_state.chunk then
		rendering_module.free_chunk(surface_data, render_state.chunk)
		render_state.chunk = nil
	end
end

---Clear render objects from a render state (for re-rendering)
---@param render_state table The render state
function rendering_module.clear_render_state(render_state)
	if not render_state or not render_state.line_ids then return end

	for _, render_obj in ipairs(render_state.line_ids) do
		if render_obj.valid then
			render_obj.destroy()
		end
	end
	render_state.line_ids = {}
end

return rendering_module
