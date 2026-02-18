# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Factorio Charts is a reusable charting library for Factorio 2.0+ mods. It renders line graphs and stacked bar charts on hidden game surfaces, viewable through GUI camera widgets. Developed for Project Cybersyn.

## Testing

Tests require the `factorio-test` mod (optional dependency). Two test frameworks are supported:

1. **factorio-test (interactive)**: Load mod in Factorio, click "Run Tests" in GUI
2. **factorio-test-harness (automated)**: Command-line testing via the harness

Test files are in `tests/` and registered in `tests/init.lua` (for factorio-test) and `tests/harness_init.lua` (for harness).

## Architecture

### Module Structure

```
factorio-charts/
├── charts.lua                      Main entry point (sub-table API + flat aliases)
├── control.lua                     Factorio requirement (minimal)
├── core/
│   ├── rendering.lua               Surface and chunk management
│   ├── colors.lua                  12-color series palette
│   └── format.lua                  Label formatting utilities
├── charts/
│   ├── line-graph.lua              Multi-series line graph rendering
│   ├── bar-chart.lua               Stacked bar chart rendering
│   └── time-series.lua             Multi-resolution time series with cascading aggregation
├── interaction/
│   ├── interaction.lua             Hit testing, coordinate transforms, highlights/tooltips
│   ├── animation.lua               Easing functions, interpolation, animation lifecycle
│   ├── interactive-chart.lua       High-level wrapper with state management
│   └── events.lua                  Event handler registration for animation processing
└── tests/
```

**Grouping rationale:**
- **`core/`** — Shared foundations with no chart-type deps (surface mgmt, colors, formatting)
- **`charts/`** — Chart type implementations (depend on core/, produce rendered output)
- **`interaction/`** — User interaction: hit testing, animation, high-level interactive wrapper, events

### Sub-table API

`charts.lua` exposes functions via named sub-tables. Flat aliases (e.g., `charts.create_surface()`) are preserved for backward compatibility.

| Sub-table | Purpose |
|-----------|---------|
| `charts.surface` | Surface/chunk management: `create`, `allocate_chunk`, `free_chunk`, `get_camera_params`, etc. |
| `charts.render` | Chart rendering: `line_graph`, `stacked_bars`, `time_series`, `*_with_metadata`, `*_with_overlays` |
| `charts.colors` | Color palette: `get_series_colors`, `get_series_color`, `get_grid_color`, `get_label_color`, `get_max_series` |
| `charts.format` | Formatting: `time_label`, `percent_label`, `time_detailed` |
| `charts.interaction` | Hit testing, coordinate transforms, highlights, tooltips, overlay buttons |
| `charts.animation` | Easing, interpolation, animation lifecycle (module re-exported directly) |
| `charts.interactive` | High-level interactive chart wrappers: `create_line_graph`, `on_hover`, `destroy`, etc. |
| `charts.events` | Event registration for animation: `register`, `unregister`, `add_animation`, etc. |
| `charts.time_series` | Time series data: `create`, `add_datapoint`, `get_average`, `clear` |

### Key Concepts

**Surface Management**: Charts are rendered on hidden Factorio surfaces. `charts.surface.create()` initializes one, then `charts.surface.allocate_chunk()` gives you a 32x32 tile area with lighting. Chunks are reused via a freelist when freed.

**Ring Buffer Data Format**: Line graphs expect data in a ring buffer format:
- `data`: array of `{[series_name]: value}` tables
- `index`: current write position
- `length`: buffer capacity
- Iteration order is `index+1 → length`, then `1 → index` for chronological display

**Rendering Coordinates**: Graphs use pixel-based viewport dimensions (default 900x700) converted to tile coordinates (divide by 32). Graph area has margins for axis labels.

**TTL-Based Cleanup**: All rendered objects use `time_to_live` in ticks. No manual cleanup needed for graph lines/text - they auto-expire.

**Resolution Independence**: Use `charts.surface.get_camera_params()` to calculate correct camera position and zoom for any widget size. The viewport dimensions (default 900x700) define the graph layout in tile space. The function computes the zoom needed to fit the graph into the actual widget dimensions:
```lua
local camera = charts.surface.get_camera_params(chunk, {
    viewport_width = 900,   -- Design size (graph layout)
    viewport_height = 700,
    widget_width = actual_widget.width,   -- Actual GUI element size
    widget_height = actual_widget.height,
    fit_mode = "fit",  -- "fit", "fill", or "stretch"
})
-- Returns: {position = {x, y}, zoom = number, offset = {x, y}, ...}
```

**Camera Widget Sizing Trade-off**: Factorio does not expose the actual rendered size of GUI elements at runtime. This creates a trade-off when sizing camera widgets:

1. **Fixed size camera** (recommended for consistency): Set explicit `width` and `height` on the camera widget. The chart will look identical regardless of window size or fullscreen/windowed mode. May leave empty space in larger windows.
   ```lua
   style_mods = { width = 900, height = 700 }
   ```

2. **Stretchable camera**: Use `horizontally_stretchable = true` with `minimal_width`. The camera fills available space, but since you can't query the actual size, you must calculate zoom from fixed dimensions. This causes the chart to appear proportionally smaller in larger windows (more surface area visible at the same zoom level).

For consistent appearance across all screen modes, use fixed-size camera widgets.

### Usage Pattern (Basic)

```lua
local charts = require("__factorio-charts__.charts")
local surface_data = charts.surface.create("my-surface")  -- once in on_init
local chunk = charts.surface.allocate_chunk(surface_data)
charts.render.line_graph(surface_data.surface, chunk, {...})

-- Calculate camera params for resolution-independent display
local camera = charts.surface.get_camera_params(chunk, {
    widget_width = 900,  -- Your actual camera widget dimensions
    widget_height = 700,
})

-- Create GUI camera widget with calculated params
local camera_widget = parent.add{
    type = "camera",
    position = camera.position,
    surface_index = surface_data.surface.index,
    zoom = camera.zoom,
}

charts.surface.free_chunk(surface_data, chunk)  -- when done
```

Note: Flat aliases still work (e.g., `charts.create_surface()`, `charts.render_line_graph()`).

### Interactive Charts

The library provides two approaches for adding hover/click interactions:

**High-Level (Recommended):** Use `charts.interactive` for automatic state management:
```lua
local state = charts.interactive.create_line_graph(surface, chunk, {
    data = ring_buffer, index = idx, length = len,
    counts = counts, sum = sums,
    on_hover = function(region, state) ... end,
    on_click = function(region, button, state) ... end,
})
-- Handle hover: charts.interactive.on_hover(state, region_id, player)
-- Update data: charts.interactive.update_line_graph(state, new_options)
-- Cleanup: charts.interactive.destroy(state)
```

**Low-Level:** Use `charts.interaction` primitives directly for full control:
```lua
-- Render with metadata
local ordered_sums, line_ids, metadata = charts.render.line_graph_with_metadata(...)
-- Create hit regions
local hit_regions = charts.interaction.create_line_graph_hit_regions(chunk, metadata)
-- Convert screen position to tile coordinates
local tile_pos = charts.interaction.screen_to_tile(camera_pos, zoom, widget_size, screen_pos)
-- Hit test
local region = charts.interaction.hit_test(hit_regions, tile_pos)
-- Create visual feedback
local highlight = charts.interaction.create_highlight(surface, region)
local tooltip = charts.interaction.create_tooltip(surface, tile_pos, {"Line 1", "Line 2"})
```

**Overlay Buttons:** Factorio doesn't expose mouse position over cameras. Use transparent buttons:
```lua
-- Generate button configs from hit regions
local buttons = charts.interaction.generate_overlay_buttons(camera_pos, zoom, widget_size, hit_regions)
-- buttons[i] = {region_id, style_mods, region}

-- Or create buttons directly on a GUI element
local created = charts.interaction.create_overlay_buttons(parent, button_configs, {
    button_style = "my_transparent_button_style",
    widget_width = 900,
    widget_height = 700,
})
```

**Animation:** Smooth transitions via `charts.animation`:
```lua
local anim = charts.animation.create({
    start_tick = game.tick, duration = 30,
    from = {value = 0}, to = {value = 100},
    easing = "ease_in_out",
    on_update = function(t, values, anim) ... end,
})
-- Register tick handler: charts.events.register({})
-- Or manually: charts.animation.update_all(animations_table, current_tick)
```

**Time Series:** Multi-resolution data storage with cascading aggregation (like RRDtool):
```lua
-- Define intervals: each level aggregates 'steps' samples from the previous
local interval_defs = {
    {name = "5s",  ticks = 1,   steps = 6,   length = 300},  -- 1 sample/tick, 5 min buffer
    {name = "1m",  ticks = 6,   steps = 10,  length = 600},  -- avg of 6 samples, 10 min buffer
    {name = "10m", ticks = 60,  steps = nil, length = 600},  -- avg of 10 samples, 100 min buffer
}
local intervals = charts.time_series.create(interval_defs)

-- Allocate chunk for rendering (store in interval)
intervals[1].chunk = charts.surface.allocate_chunk(surface_data)

-- Add data each tick - automatically cascades to coarser intervals
charts.time_series.add_datapoint(intervals, {series1 = 50, series2 = 75})

-- Render a specific interval (handles lifecycle: cleanup, render, hit regions, caching)
local ordered_sums, hit_regions = charts.render.time_series(surface, intervals, 1, {
    selected_series = nil,  -- or {series1 = true, series2 = false}
    y_range = {0, 100},     -- fixed range, or nil for auto-scale
    label_format = "percent", -- or "time"
    viewport_width = 900,
    viewport_height = 700,
})
```
