-- Interaction primitives for chart hover/click detection
local interaction = {}

local colors_module = require("colors")

---@class HitRegion
---@field id string Unique identifier for this hit region
---@field tile_bounds table {left, top, right, bottom} in tile coordinates (absolute, includes chunk offset)
---@field type string "data_point" | "bar_segment" | "legend_item" | "series_line"
---@field data table Arbitrary data associated with this region

-- Coordinate transformation functions

---Calculate screen position for a tile coordinate relative to a camera widget
---@param camera_position table {x, y} Camera center in tile coordinates
---@param camera_zoom number Zoom level (1 = 32 pixels per tile)
---@param widget_size table {width, height} Camera widget size in pixels
---@param tile_pos table {x, y} Target tile position
---@return table screen_pos {x, y} Position in widget-local pixels
function interaction.tile_to_screen(camera_position, camera_zoom, widget_size, tile_pos)
	local pixels_per_tile = 32 * camera_zoom
	-- Camera center is at widget center
	local center_x = widget_size.width / 2
	local center_y = widget_size.height / 2
	-- Offset from camera center in tiles, then convert to pixels
	local dx = (tile_pos.x - camera_position.x) * pixels_per_tile
	local dy = (tile_pos.y - camera_position.y) * pixels_per_tile
	return {
		x = center_x + dx,
		y = center_y + dy,
	}
end

---Calculate tile position from screen position
---@param camera_position table {x, y} Camera center in tile coordinates
---@param camera_zoom number Zoom level
---@param widget_size table {width, height} Camera widget size in pixels
---@param screen_pos table {x, y} Position in widget-local pixels
---@return table tile_pos {x, y} Position in tile coordinates
function interaction.screen_to_tile(camera_position, camera_zoom, widget_size, screen_pos)
	local pixels_per_tile = 32 * camera_zoom
	local center_x = widget_size.width / 2
	local center_y = widget_size.height / 2
	-- Convert screen offset from center to tiles
	local dx = (screen_pos.x - center_x) / pixels_per_tile
	local dy = (screen_pos.y - center_y) / pixels_per_tile
	return {
		x = camera_position.x + dx,
		y = camera_position.y + dy,
	}
end

-- Hit region creation

---Create hit regions for line graph data points
---@param chunk table Chunk with coord
---@param metadata table Graph metadata from render_with_metadata
---@param options table? {point_radius?: number}
---@return HitRegion[] regions Array of hit regions
function interaction.create_line_graph_hit_regions(chunk, metadata, options)
	options = options or {}
	local point_radius = options.point_radius or 0.2 -- tiles

	local regions = {}
	local series_colors = colors_module.get_series_colors()

	if not metadata or not metadata.point_positions then
		return regions
	end

	local series_idx = 0
	for series_name, points in pairs(metadata.point_positions) do
		series_idx = series_idx + 1
		local color = series_colors[((series_idx - 1) % #series_colors) + 1]

		for _, point in ipairs(points) do
			regions[#regions + 1] = {
				id = "line_" .. series_name .. "_" .. point.data_index,
				tile_bounds = {
					left = chunk.coord.x + point.x - point_radius,
					top = chunk.coord.y + point.y - point_radius,
					right = chunk.coord.x + point.x + point_radius,
					bottom = chunk.coord.y + point.y + point_radius,
				},
				type = "data_point",
				data = {
					series_name = series_name,
					data_index = point.data_index,
					value = point.value,
					color = color,
					graph_x = point.x,
					graph_y = point.y,
				},
			}
		end
	end

	return regions
end

---Create hit regions for bar chart segments
---@param chunk table Chunk with coord
---@param metadata table Bar metadata from render_with_metadata
---@return HitRegion[] regions Array of hit regions
function interaction.create_bar_chart_hit_regions(chunk, metadata)
	local regions = {}

	if not metadata or not metadata.segment_bounds then
		return regions
	end

	for bar_idx, phases in pairs(metadata.segment_bounds) do
		for phase_name, bounds in pairs(phases) do
			regions[#regions + 1] = {
				id = "bar_" .. bar_idx .. "_" .. phase_name,
				tile_bounds = {
					left = chunk.coord.x + bounds.left,
					top = chunk.coord.y + bounds.top,
					right = chunk.coord.x + bounds.right,
					bottom = chunk.coord.y + bounds.bottom,
				},
				type = "bar_segment",
				data = {
					bar_index = bar_idx,
					phase_name = phase_name,
					duration = bounds.duration,
					color = bounds.color,
					delivery = bounds.delivery,
				},
			}
		end
	end

	return regions
end

---Create hit regions for series legend items
---@param chunk table Chunk with coord
---@param legend_positions table Array of {name, x, y, width, height}
---@return HitRegion[] regions
function interaction.create_legend_hit_regions(chunk, legend_positions)
	local regions = {}
	local series_colors = colors_module.get_series_colors()

	for idx, legend in ipairs(legend_positions) do
		local color = series_colors[((idx - 1) % #series_colors) + 1]
		regions[#regions + 1] = {
			id = "legend_" .. legend.name,
			tile_bounds = {
				left = chunk.coord.x + legend.x,
				top = chunk.coord.y + legend.y,
				right = chunk.coord.x + legend.x + legend.width,
				bottom = chunk.coord.y + legend.y + legend.height,
			},
			type = "legend_item",
			data = {
				series_name = legend.name,
				color = color,
			},
		}
	end

	return regions
end

-- Hit testing

---Perform hit test given a tile position
---@param hit_regions HitRegion[] Array of hit regions
---@param tile_pos table {x, y} Position in tile coordinates
---@return HitRegion? region The topmost hit region, or nil if none
function interaction.hit_test(hit_regions, tile_pos)
	-- Iterate in reverse to find topmost (last added = on top)
	for i = #hit_regions, 1, -1 do
		local region = hit_regions[i]
		local bounds = region.tile_bounds
		if tile_pos.x >= bounds.left and tile_pos.x <= bounds.right and
		   tile_pos.y >= bounds.top and tile_pos.y <= bounds.bottom then
			return region
		end
	end
	return nil
end

---Find all hit regions at a tile position
---@param hit_regions HitRegion[] Array of hit regions
---@param tile_pos table {x, y} Position in tile coordinates
---@return HitRegion[] regions All hit regions at position
function interaction.hit_test_all(hit_regions, tile_pos)
	local results = {}
	for _, region in ipairs(hit_regions) do
		local bounds = region.tile_bounds
		if tile_pos.x >= bounds.left and tile_pos.x <= bounds.right and
		   tile_pos.y >= bounds.top and tile_pos.y <= bounds.bottom then
			results[#results + 1] = region
		end
	end
	return results
end

-- Visual feedback

---Create a highlight rectangle around a region
---@param surface LuaSurface The rendering surface
---@param region HitRegion The region to highlight
---@param options table? {color?, ttl?, width?}
---@return LuaRenderObject highlight_id The render object
function interaction.create_highlight(surface, region, options)
	options = options or {}
	local color = options.color or {r = 1, g = 1, b = 1, a = 0.5}
	local ttl = options.ttl or 60
	local width = options.width or 2

	local bounds = region.tile_bounds
	return rendering.draw_rectangle{
		surface = surface,
		color = color,
		filled = false,
		width = width,
		left_top = {bounds.left, bounds.top},
		right_bottom = {bounds.right, bounds.bottom},
		time_to_live = ttl,
	}
end

---Create a filled highlight rectangle
---@param surface LuaSurface The rendering surface
---@param region HitRegion The region to highlight
---@param options table? {color?, ttl?}
---@return LuaRenderObject highlight_id The render object
function interaction.create_highlight_filled(surface, region, options)
	options = options or {}
	local color = options.color or {r = 1, g = 1, b = 1, a = 0.2}
	local ttl = options.ttl or 60

	local bounds = region.tile_bounds
	return rendering.draw_rectangle{
		surface = surface,
		color = color,
		filled = true,
		left_top = {bounds.left, bounds.top},
		right_bottom = {bounds.right, bounds.bottom},
		time_to_live = ttl,
	}
end

---Create tooltip render objects near a position
---@param surface LuaSurface The rendering surface
---@param tile_pos table {x, y} Position to anchor tooltip
---@param lines string[] Array of text lines
---@param options table? {background_color?, text_color?, ttl?, scale?, offset?}
---@return LuaRenderObject[] render_ids Array of render objects
function interaction.create_tooltip(surface, tile_pos, lines, options)
	options = options or {}
	local text_color = options.text_color or {r = 1, g = 1, b = 1}
	local ttl = options.ttl or 60
	local scale = options.scale or 0.8
	local offset = options.offset or {x = 0.5, y = -0.5}

	local render_ids = {}
	local y_offset = 0
	local line_height = 0.4 * scale

	for _, line in ipairs(lines) do
		local text_id = rendering.draw_text{
			text = line,
			surface = surface,
			target = {tile_pos.x + offset.x, tile_pos.y + offset.y + y_offset},
			color = text_color,
			scale = scale,
			alignment = "left",
			vertical_alignment = "top",
			time_to_live = ttl,
		}
		render_ids[#render_ids + 1] = text_id
		y_offset = y_offset + line_height
	end

	return render_ids
end

---Destroy multiple render objects
---@param render_ids LuaRenderObject[] Array of render objects
function interaction.destroy_render_objects(render_ids)
	for _, obj in ipairs(render_ids) do
		if obj and obj.valid then
			obj.destroy()
		end
	end
end

-- Overlay button generation

---Generate button style margins for positioning over a camera widget
---@param camera_position table {x, y} Camera center in tile coordinates
---@param camera_zoom number Zoom level
---@param widget_size table {width, height} Camera widget size in pixels
---@param region HitRegion Hit region to create button for
---@return table style_mods {left_margin, top_margin, width, height}
function interaction.calculate_button_style(camera_position, camera_zoom, widget_size, region)
	local top_left = interaction.tile_to_screen(
		camera_position,
		camera_zoom,
		widget_size,
		{x = region.tile_bounds.left, y = region.tile_bounds.top}
	)
	local bottom_right = interaction.tile_to_screen(
		camera_position,
		camera_zoom,
		widget_size,
		{x = region.tile_bounds.right, y = region.tile_bounds.bottom}
	)

	local width = math.max(1, math.floor(bottom_right.x - top_left.x))
	local height = math.max(1, math.floor(bottom_right.y - top_left.y))

	return {
		left_margin = math.floor(top_left.x),
		top_margin = math.floor(top_left.y),
		width = width,
		height = height,
	}
end

---Generate overlay button configurations for hit regions
---This returns data suitable for building GUI buttons
---
---IMPORTANT: Factorio GUI uses flow-based layout, not absolute positioning.
---To position multiple buttons at arbitrary locations over a camera:
---
---1. Add a container flow inside the camera with direction="vertical",
---   sized to match the camera, with padding=0 and vertical_spacing=0:
---   ```lua
---   local container = camera.add{type = "flow", direction = "vertical"}
---   container.style.width = CAMERA_WIDTH
---   container.style.height = CAMERA_HEIGHT
---   container.style.padding = 0
---   container.style.vertical_spacing = 0
---   ```
---
---2. Add buttons to the container using the negative bottom_margin trick:
---   ```lua
---   for _, config in ipairs(button_configs) do
---       local left = config.style_mods.left_margin + OFFSET_X
---       local top = config.style_mods.top_margin + OFFSET_Y
---       local width = config.style_mods.width
---       local height = config.style_mods.height
---       local btn = container.add{type = "button", ...}
---       btn.style.left_margin = left
---       btn.style.top_margin = top
---       btn.style.bottom_margin = -top - height  -- Makes button take zero vertical space!
---       btn.style.width = width
---       btn.style.height = height
---   end
---   ```
---   The negative bottom_margin cancels out the top_margin + height, so each
---   button takes zero net vertical space. This allows all buttons to position
---   from the top of the container independently.
---
---You may need to apply a calibration offset (OFFSET_X, OFFSET_Y) to align
---buttons with the rendered chart elements.
---
---@param camera_position table Camera center in tile coordinates
---@param camera_zoom number Zoom level
---@param widget_size table {width, height} Camera widget size in pixels
---@param hit_regions HitRegion[] Hit regions to create buttons for
---@return table[] button_configs Array of {region_id, style_mods, region}
function interaction.generate_overlay_buttons(camera_position, camera_zoom, widget_size, hit_regions)
	local buttons = {}

	for _, region in ipairs(hit_regions) do
		local style_mods = interaction.calculate_button_style(
			camera_position,
			camera_zoom,
			widget_size,
			region
		)

		-- Only include buttons that are at least partially visible
		if style_mods.left_margin + style_mods.width > 0 and
		   style_mods.left_margin < widget_size.width and
		   style_mods.top_margin + style_mods.height > 0 and
		   style_mods.top_margin < widget_size.height then
			buttons[#buttons + 1] = {
				region_id = region.id,
				style_mods = style_mods,
				region = region,
			}
		end
	end

	return buttons
end

return interaction
