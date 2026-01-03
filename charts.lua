-- Factorio Charts - Main entry point
-- A reusable charting library for Factorio mods

local charts = {}

local rendering_module = require("rendering")
local line_graph = require("line-graph")
local bar_chart = require("bar-chart")
local colors = require("colors")
local format = require("format")

-- Re-export rendering functions
charts.create_surface = rendering_module.create_surface
charts.allocate_chunk = rendering_module.allocate_chunk
charts.free_chunk = rendering_module.free_chunk
charts.get_viewport_size = rendering_module.get_viewport_size

-- Re-export chart rendering functions
charts.render_line_graph = line_graph.render
charts.render_stacked_bars = bar_chart.render

-- Re-export color utilities
charts.get_series_colors = colors.get_series_colors
charts.get_series_color = colors.get_series_color
charts.get_grid_color = colors.get_grid_color
charts.get_label_color = colors.get_label_color
charts.get_max_series = colors.get_max_series

-- Re-export format utilities
charts.format_time_label = format.time_label
charts.format_percent_label = format.percent_label
charts.format_time_detailed = format.time_detailed

return charts
