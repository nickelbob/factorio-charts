# Factorio Charts

A reusable charting library for Factorio 2.0+ mods. Provides line graphs and stacked bar charts rendered on hidden surfaces, viewable through GUI camera widgets.

## Features

- **Line Graphs**: Multi-series time series data with auto-scaling Y-axis
- **Stacked Bar Charts**: Phase breakdown visualization
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
local surface_data = charts.create_surface("my-analytics")

-- Allocate a chunk for rendering
local chunk = charts.allocate_chunk(surface_data)

-- Render a line graph
local ordered_sums, line_ids = charts.render_line_graph(surface_data.surface, chunk, {
    data = ring_buffer,           -- Array of {[series_name]: value}
    index = current_index,        -- Current position in ring buffer
    length = buffer_length,       -- Ring buffer capacity
    counts = sample_counts,       -- {[series_name]: count}
    sum = series_sums,            -- {[series_name]: total}
    y_range = {0, 100},           -- Optional fixed range (nil for auto-scale)
    label_format = "percent",     -- "percent" or "time"
    selected_series = nil,        -- Filter: nil=all, {[name]: false}=hide
    ttl = 360,                    -- Render lifetime in ticks
})

-- Render a stacked bar chart
local line_ids = charts.render_stacked_bars(surface_data.surface, chunk, {
    deliveries = delivery_data,   -- Array of phase timing objects
    phase_colors = {              -- Color per phase
        loading = {r=0, g=1, b=0},
        travel = {r=0, g=0, b=1},
    },
    phase_order = {"loading", "travel"},  -- Stack order (bottom to top)
    ttl = 360,
})

-- Free chunk when done
charts.free_chunk(surface_data, chunk)
```

## Displaying Charts in GUI

Use a camera widget pointing at the chunk coordinates:

```lua
{
    type = "camera",
    position = chunk.coord,
    surface_index = surface_data.surface.index,
    zoom = 1,
}
```

## API Reference

### Surface Management

| Function | Description |
|----------|-------------|
| `charts.create_surface(name)` | Create a hidden surface for rendering |
| `charts.allocate_chunk(surface_data)` | Get a chunk for rendering a graph |
| `charts.free_chunk(surface_data, chunk)` | Return a chunk when done |

### Rendering

| Function | Description |
|----------|-------------|
| `charts.render_line_graph(surface, chunk, options)` | Render a multi-series line graph |
| `charts.render_stacked_bars(surface, chunk, options)` | Render a stacked bar chart |

### Utilities

| Function | Description |
|----------|-------------|
| `charts.get_series_colors()` | Get the 12-color palette array |
| `charts.get_series_color(index)` | Get a specific series color |
| `charts.get_grid_color()` | Get the grid line color |
| `charts.get_label_color()` | Get the axis label color |
| `charts.get_max_series()` | Get max supported series count (12) |
| `charts.format_time_label(seconds)` | Format seconds as "30s", "5m", "2.5h" |
| `charts.format_percent_label(value)` | Format as percentage with 1 decimal |

## License

MIT License - See LICENSE file

## Credits

Graph rendering technique inspired by [factorio-timeseries](https://mods.factorio.com/mod/timeseries) by Kirk McDonald.

Developed for [Project Cybersyn](https://mods.factorio.com/mod/cybersyn).
