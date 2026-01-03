-- Formatting utilities for chart labels
local format_module = {}

---Format seconds into human readable time for Y-axis labels
---@param seconds number
---@return string
function format_module.time_label(seconds)
	if seconds < 60 then
		return string.format("%.0fs", seconds)
	elseif seconds < 3600 then
		return string.format("%.0fm", seconds / 60)
	else
		return string.format("%.1fh", seconds / 3600)
	end
end

---Format a percentage for Y-axis labels
---@param value number The percentage value (0-100)
---@return string
function format_module.percent_label(value)
	return string.format("%.0f%%", value)
end

---Format seconds into detailed human readable time
---@param seconds number
---@return string
function format_module.time_detailed(seconds)
	if seconds < 60 then
		return string.format("%.1fs", seconds)
	elseif seconds < 3600 then
		local mins = math.floor(seconds / 60)
		local secs = seconds % 60
		return string.format("%dm %.0fs", mins, secs)
	else
		local hours = math.floor(seconds / 3600)
		local mins = math.floor((seconds % 3600) / 60)
		return string.format("%dh %dm", hours, mins)
	end
end

return format_module
