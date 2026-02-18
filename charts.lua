-- Factorio Charts - Main entry point
-- A reusable charting library for Factorio mods
--
-- Graph rendering technique inspired by factorio-timeseries by Kirk McDonald
-- https://mods.factorio.com/mod/timeseries (MIT License)

local charts = {}

local rendering_module = require("core/rendering")
local line_graph = require("charts/line-graph")
local bar_chart = require("charts/bar-chart")
local colors = require("core/colors")
local format = require("core/format")
local interaction = require("interaction/interaction")
local animation = require("interaction/animation")
local interactive_chart = require("interaction/interactive-chart")
local events = require("interaction/events")
local time_series = require("charts/time-series")

-- ============================================================================
-- Sub-table API
-- ============================================================================

-- Surface management
charts.surface = {
	create = rendering_module.create_surface,
	allocate_chunk = rendering_module.allocate_chunk,
	free_chunk = rendering_module.free_chunk,
	ensure_tile_coverage = rendering_module.ensure_tile_coverage,
	get_viewport_size = rendering_module.get_viewport_size,
	get_camera_params = rendering_module.get_camera_params,
	setup_camera_widget = rendering_module.setup_camera_widget,
	create_render_state = rendering_module.create_render_state,
	destroy_render_state = rendering_module.destroy_render_state,
	clear_render_state = rendering_module.clear_render_state,
}

-- Chart rendering
charts.render = {
	line_graph = line_graph.render,
	line_graph_with_metadata = line_graph.render_with_metadata,
	stacked_bars = bar_chart.render,
	stacked_bars_with_metadata = bar_chart.render_with_metadata,
	stacked_bars_with_overlays = bar_chart.render_with_overlays,
	time_series = time_series.render,
}

-- Color utilities
charts.colors = {
	get_series_colors = colors.get_series_colors,
	get_series_color = colors.get_series_color,
	get_grid_color = colors.get_grid_color,
	get_label_color = colors.get_label_color,
	get_max_series = colors.get_max_series,
}

-- Format utilities
charts.format = {
	time_label = format.time_label,
	percent_label = format.percent_label,
	time_detailed = format.time_detailed,
}

-- Interaction primitives
charts.interaction = {
	tile_to_screen = interaction.tile_to_screen,
	screen_to_tile = interaction.screen_to_tile,
	hit_test = interaction.hit_test,
	hit_test_all = interaction.hit_test_all,
	create_line_graph_hit_regions = interaction.create_line_graph_hit_regions,
	create_bar_chart_hit_regions = interaction.create_bar_chart_hit_regions,
	create_legend_hit_regions = interaction.create_legend_hit_regions,
	create_highlight = interaction.create_highlight,
	create_highlight_filled = interaction.create_highlight_filled,
	create_tooltip = interaction.create_tooltip,
	destroy_render_objects = interaction.destroy_render_objects,
	calculate_button_style = interaction.calculate_button_style,
	generate_overlay_buttons = interaction.generate_overlay_buttons,
	create_overlay_buttons = interaction.create_overlay_buttons,
}

-- Animation utilities (already a sub-table)
charts.animation = animation

-- Interactive chart wrappers
charts.interactive = {
	create_line_graph = interactive_chart.create_line_graph,
	update_line_graph = interactive_chart.update_line_graph,
	create_bar_chart = interactive_chart.create_bar_chart,
	update_bar_chart = interactive_chart.update_bar_chart,
	get_hit_regions = interactive_chart.get_hit_regions,
	on_hover = interactive_chart.on_hover,
	on_hover_leave = interactive_chart.on_hover_leave,
	on_click = interactive_chart.on_click,
	toggle_series = interactive_chart.toggle_series,
	tick = interactive_chart.tick,
	destroy = interactive_chart.destroy,
	get_overlay_buttons = interactive_chart.get_overlay_buttons,
	hit_test = interactive_chart.hit_test,
	hit_test_screen = interactive_chart.hit_test_screen,
}

-- Event registration
charts.events = {
	register = events.register,
	unregister = events.unregister,
	is_registered = events.is_registered,
	get_tick_handler = events.get_tick_handler,
	add_animation = events.add_animation,
	remove_animation = events.remove_animation,
	is_animation_running = events.is_animation_running,
	get_animations = events.get_animations,
	clear_animations = events.clear_animations,
}

-- Time series data management
charts.time_series = {
	create = time_series.create_interval_set,
	add_datapoint = time_series.add_datapoint,
	get_average = time_series.get_average,
	get_all_averages = time_series.get_all_averages,
	clear = time_series.clear,
}

-- ============================================================================
-- Backward-compatible flat aliases (deprecated — use sub-tables above)
-- All 86+ flat exports preserved for existing consumers (e.g., Cybersyn).
-- ============================================================================

-- Surface management
charts.create_surface = rendering_module.create_surface
charts.allocate_chunk = rendering_module.allocate_chunk
charts.ensure_tile_coverage = rendering_module.ensure_tile_coverage
charts.free_chunk = rendering_module.free_chunk
charts.get_viewport_size = rendering_module.get_viewport_size
charts.get_camera_params = rendering_module.get_camera_params
charts.setup_camera_widget = rendering_module.setup_camera_widget
charts.create_render_state = rendering_module.create_render_state
charts.destroy_render_state = rendering_module.destroy_render_state
charts.clear_render_state = rendering_module.clear_render_state

-- Chart rendering (basic, no interaction)
charts.render_line_graph = line_graph.render
charts.render_stacked_bars = bar_chart.render

-- Metadata-returning render functions (for interaction support)
charts.render_line_graph_with_metadata = line_graph.render_with_metadata
charts.render_stacked_bars_with_metadata = bar_chart.render_with_metadata

-- High-level render with overlay buttons
charts.render_stacked_bars_with_overlays = bar_chart.render_with_overlays

-- Color utilities
charts.get_series_colors = colors.get_series_colors
charts.get_series_color = colors.get_series_color
charts.get_grid_color = colors.get_grid_color
charts.get_label_color = colors.get_label_color
charts.get_max_series = colors.get_max_series

-- Format utilities
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
charts.create_overlay_buttons = interaction.create_overlay_buttons

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
