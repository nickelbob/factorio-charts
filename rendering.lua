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
		surface = game.create_surface(surface_name, {width = 2, height = 2})
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

return rendering_module
