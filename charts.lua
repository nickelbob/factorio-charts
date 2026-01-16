-- Factorio Charts - Main entry point
-- A reusable charting library for Factorio mods
--
-- Graph rendering technique inspired by factorio-timeseries by Kirk McDonald
-- https://mods.factorio.com/mod/timeseries (MIT License)

local charts = {}

local rendering_module = require("rendering")
local line_graph = require("line-graph")
local bar_chart = require("bar-chart")
local colors = require("colors")
local format = require("format")
local interaction = require("interaction")
local animation = require("animation")
local interactive_chart = require("interactive-chart")
local events = require("events")
local time_series = require("time-series")

-- Re-export rendering functions
charts.create_surface = rendering_module.create_surface
charts.allocate_chunk = rendering_module.allocate_chunk
charts.ensure_tile_coverage = rendering_module.ensure_tile_coverage
charts.free_chunk = rendering_module.free_chunk
charts.get_viewport_size = rendering_module.get_viewport_size
charts.get_camera_params = rendering_module.get_camera_params

-- Re-export chart rendering functions (basic, no interaction)
charts.render_line_graph = line_graph.render
charts.render_stacked_bars = bar_chart.render

-- Re-export metadata-returning render functions (for interaction support)
charts.render_line_graph_with_metadata = line_graph.render_with_metadata
charts.render_stacked_bars_with_metadata = bar_chart.render_with_metadata

-- High-level render with overlay buttons (combines render + hit regions + button generation)
charts.render_stacked_bars_with_overlays = bar_chart.render_with_overlays

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

-- Low-level interaction primitives
charts.tile_to_screen = interaction.tile_to_screen
charts.screen_to_tile = interaction.screen_to_tile
charts.create_line_graph_hit_regions = interaction.create_line_graph_hit_regions
charts.create_bar_chart_hit_regions = interaction.create_bar_chart_hit_regions
charts.create_legend_hit_regions = interaction.create_legend_hit_regions
charts.hit_test = interaction.hit_test
charts.hit_test_all = interaction.hit_test_all
charts.create_highlight = interaction.create_highlight
charts.create_highlight_filled = interaction.create_highlight_filled
charts.create_tooltip = interaction.create_tooltip
charts.destroy_render_objects = interaction.destroy_render_objects
charts.calculate_button_style = interaction.calculate_button_style
charts.generate_overlay_buttons = interaction.generate_overlay_buttons

-- Animation utilities (exposed as sub-table for namespacing)
charts.animation = animation

-- High-level interactive chart wrappers
charts.create_interactive_line_graph = interactive_chart.create_line_graph
charts.update_interactive_line_graph = interactive_chart.update_line_graph
charts.create_interactive_bar_chart = interactive_chart.create_bar_chart
charts.update_interactive_bar_chart = interactive_chart.update_bar_chart
charts.get_chart_hit_regions = interactive_chart.get_hit_regions
charts.chart_on_hover = interactive_chart.on_hover
charts.chart_on_hover_leave = interactive_chart.on_hover_leave
charts.chart_on_click = interactive_chart.on_click
charts.toggle_chart_series = interactive_chart.toggle_series
charts.chart_tick = interactive_chart.tick
charts.destroy_interactive_chart = interactive_chart.destroy
charts.get_chart_overlay_buttons = interactive_chart.get_overlay_buttons
charts.chart_hit_test = interactive_chart.hit_test
charts.chart_hit_test_screen = interactive_chart.hit_test_screen

-- Event registration (for animation processing)
charts.register_events = events.register
charts.unregister_events = events.unregister
charts.is_events_registered = events.is_registered
charts.get_tick_handler = events.get_tick_handler
charts.add_animation = events.add_animation
charts.remove_animation = events.remove_animation
charts.is_animation_running = events.is_animation_running
charts.get_animations = events.get_animations
charts.clear_animations = events.clear_animations

-- Time series data management
charts.create_time_series = time_series.create_interval_set
charts.add_datapoint = time_series.add_datapoint
charts.get_series_average = time_series.get_average
charts.get_all_averages = time_series.get_all_averages
charts.clear_time_series = time_series.clear
charts.render_time_series = time_series.render

return charts
