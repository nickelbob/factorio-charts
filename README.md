# Factorio Charts

A reusable charting library for Factorio 2.0+ mods. Provides line graphs and stacked bar charts rendered on hidden surfaces, viewable through GUI camera widgets.

## Features

- **Line Graphs**: Multi-series time series data with auto-scaling Y-axis
- **Stacked Bar Charts**: Phase breakdown visualization with optional hatched phases
- **Interactive Charts**: Hit testing, hover highlights, tooltips, overlay buttons
- **Time Series**: Multi-resolution cascading aggregation (like RRDtool)
- **Surface Management**: Automatic chunk allocation and cleanup
- **Color Palettes**: 12 distinct colors for series differentiation

## Installation

Add to your mod's `info.json` dependencies:

```json
{
    "dependencies": [
        "factorio-charts >= 1.0.0"
    ]
}
```

## Usage

```lua
local charts = require("__factorio-charts__.charts")

-- Initialize (call once in on_init)
local surface_data = charts.surface.create("my-analytics")

-- Allocate a chunk for rendering
local chunk = charts.surface.allocate_chunk(surface_data)

-- Render a line graph
local ordered_sums, line_ids = charts.render.line_graph(surface_data.surface, chunk, {
    data = ring_buffer,           -- Array of {[series_name]: value}
    index = current_index,        -- Current position in ring buffer
    length = buffer_length,       -- Ring buffer capacity
    counts = sample_counts,       -- {[series_name]: count}
    sum = series_sums,            -- {[series_name]: total}
    y_range = {0, 100},           -- Optional fixed range (nil for auto-scale)
    label_format = "percent",     -- "percent", "time", or function(value) -> string
    selected_series = nil,        -- Filter: nil=all, {[name]: false}=hide
    ttl = 360,                    -- Render lifetime in ticks
})

-- Render a stacked bar chart
local line_ids = charts.render.stacked_bars(surface_data.surface, chunk, {
    deliveries = delivery_data,   -- Array of phase timing objects
    phase_colors = {              -- Color per phase
        loading = {r=0, g=1, b=0},
        travel = {r=0, g=0, b=1},
    },
    phase_order = {"loading", "travel"},  -- Stack order (bottom to top)
    ttl = 360,
})

-- Free chunk when done
charts.surface.free_chunk(surface_data, chunk)
```

## Displaying Charts in GUI

```lua
-- Calculate camera parameters for resolution-independent display
local camera = charts.surface.get_camera_params(chunk, {
    widget_width = 900,
    widget_height = 700,
})

-- Create camera widget
local camera_widget = parent.add{
    type = "camera",
    position = camera.position,
    surface_index = surface_data.surface.index,
    zoom = camera.zoom,
}
```

## API Reference

### Surface Management (`charts.surface`)

| Function | Description |
|----------|-------------|
| `charts.surface.create(name)` | Create a hidden surface for rendering |
| `charts.surface.allocate_chunk(surface_data)` | Get a chunk for rendering a graph |
| `charts.surface.free_chunk(surface_data, chunk)` | Return a chunk when done |
| `charts.surface.get_camera_params(chunk, options)` | Calculate camera position and zoom |
| `charts.surface.setup_camera_widget(element, surface, chunk, options)` | Configure a camera widget |
| `charts.surface.create_render_state(surface_data)` | Create chunk + line_ids storage |
| `charts.surface.destroy_render_state(surface_data, state)` | Free render state resources |

### Rendering (`charts.render`)

| Function | Description |
|----------|-------------|
| `charts.render.line_graph(surface, chunk, options)` | Render a multi-series line graph |
| `charts.render.line_graph_with_metadata(surface, chunk, options)` | Render + return point positions for interaction |
| `charts.render.stacked_bars(surface, chunk, options)` | Render a stacked bar chart |
| `charts.render.stacked_bars_with_metadata(surface, chunk, options)` | Render + return segment bounds for interaction |
| `charts.render.stacked_bars_with_overlays(surface, chunk, options)` | Render + generate overlay button configs |
| `charts.render.time_series(surface, intervals, index, options)` | Render a time series interval |

### Interaction (`charts.interaction`)

| Function | Description |
|----------|-------------|
| `charts.interaction.tile_to_screen(camera_pos, zoom, widget_size, tile_pos)` | Convert tile to screen coordinates |
| `charts.interaction.screen_to_tile(camera_pos, zoom, widget_size, screen_pos)` | Convert screen to tile coordinates |
| `charts.interaction.hit_test(regions, tile_pos)` | Find topmost hit region at position |
| `charts.interaction.hit_test_all(regions, tile_pos)` | Find all hit regions at position |
| `charts.interaction.create_line_graph_hit_regions(chunk, metadata)` | Generate hit regions from line graph metadata |
| `charts.interaction.create_bar_chart_hit_regions(chunk, metadata)` | Generate hit regions from bar chart metadata |
| `charts.interaction.create_highlight(surface, region, options)` | Draw highlight rectangle |
| `charts.interaction.create_tooltip(surface, tile_pos, lines, options)` | Draw tooltip text |
| `charts.interaction.generate_overlay_buttons(camera_pos, zoom, widget_size, regions)` | Generate button configs for GUI overlay |
| `charts.interaction.create_overlay_buttons(parent, configs, options)` | Create z-ordered buttons on a camera widget |

### Interactive Charts (`charts.interactive`)

| Function | Description |
|----------|-------------|
| `charts.interactive.create_line_graph(surface, chunk, options)` | Create interactive line graph with state |
| `charts.interactive.update_line_graph(state, options)` | Update with new data |
| `charts.interactive.create_bar_chart(surface, chunk, options)` | Create interactive bar chart with state |
| `charts.interactive.update_bar_chart(state, options)` | Update with new data |
| `charts.interactive.on_hover(state, region_id, player)` | Handle hover event |
| `charts.interactive.on_click(state, region_id, button, player)` | Handle click event |
| `charts.interactive.toggle_series(state, series_name)` | Toggle series visibility |
| `charts.interactive.destroy(state)` | Clean up all resources |

### Time Series (`charts.time_series`)

| Function | Description |
|----------|-------------|
| `charts.time_series.create(interval_defs)` | Create multi-resolution interval set |
| `charts.time_series.add_datapoint(intervals, value)` | Add data with cascading aggregation |
| `charts.time_series.get_average(interval, series_name)` | Get current average for a series |
| `charts.time_series.get_all_averages(interval)` | Get all series averages |
| `charts.time_series.clear(intervals)` | Clear all data |

### Events (`charts.events`)

| Function | Description |
|----------|-------------|
| `charts.events.register(handlers)` | Register tick handler |
| `charts.events.unregister()` | Unregister event handlers |
| `charts.events.is_registered()` | Check if events are registered |
| `charts.events.get_tick_handler()` | Get the tick handler function |

### Colors & Formatting

| Function | Description |
|----------|-------------|
| `charts.colors.get_series_colors()` | Get the 12-color palette array |
| `charts.colors.get_series_color(index)` | Get a specific series color |
| `charts.format.time_label(seconds)` | Format as "30s", "5m", "2.5h" |
| `charts.format.percent_label(value)` | Format as percentage |

### Backward Compatibility

All flat aliases (e.g., `charts.create_surface()`, `charts.render_line_graph()`) continue to work. See CLAUDE.md for architectural details.

## License

MIT License - See LICENSE file

## Credits

Graph rendering technique inspired by [factorio-timeseries](https://mods.factorio.com/mod/timeseries) by Kirk McDonald.

Developed for [Project Cybersyn](https://mods.factorio.com/mod/cybersyn).
