-- Color palettes for chart rendering
local colors_module = {}

-- Maximum brightness colors for line series
local series_colors = {
	{r = 1.0,  g = 1.0,  b = 0.0},   -- Yellow
	{r = 0.0,  g = 1.0,  b = 1.0},   -- Cyan
	{r = 1.0,  g = 1.0,  b = 1.0},   -- White
	{r = 1.0,  g = 0.0,  b = 0.0},   -- Red
	{r = 0.0,  g = 1.0,  b = 0.0},   -- Green
	{r = 1.0,  g = 0.5,  b = 0.0},   -- Orange
	{r = 1.0,  g = 0.0,  b = 1.0},   -- Magenta
	{r = 0.5,  g = 0.5,  b = 1.0},   -- Light blue
	{r = 1.0,  g = 0.5,  b = 0.5},   -- Light red
	{r = 0.5,  g = 1.0,  b = 0.5},   -- Light green
	{r = 1.0,  g = 1.0,  b = 0.5},   -- Light yellow
	{r = 1.0,  g = 0.5,  b = 1.0},   -- Pink
}

-- Grid line color (subtle)
local grid_color = {r = 0.3, g = 0.3, b = 0.3, a = 0.4}

-- Label color
local label_color = {r = 0.8, g = 0.8, b = 0.8}

---Get the series color palette
---@return table[] Array of color tables
function colors_module.get_series_colors()
	return series_colors
end

---Get a specific series color by index (wraps around)
---@param index number 1-based index
---@return table color {r, g, b}
function colors_module.get_series_color(index)
	return series_colors[((index - 1) % #series_colors) + 1]
end

---Get the grid line color
---@return table color {r, g, b, a}
function colors_module.get_grid_color()
	return grid_color
end

---Get the label color
---@return table color {r, g, b}
function colors_module.get_label_color()
	return label_color
end

---Get the maximum number of distinct series colors
---@return number
function colors_module.get_max_series()
	return #series_colors
end

return colors_module
