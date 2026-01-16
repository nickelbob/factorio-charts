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

**Core Rendering:**
- `charts.lua` - Main entry point, re-exports all public API functions
- `rendering.lua` - Surface and chunk management (allocation, freelist, lighting)
- `line-graph.lua` - Multi-series line graph rendering with ring buffer support
- `bar-chart.lua` - Stacked bar chart rendering with optional hatched phases
- `colors.lua` - 12-color palette for series, plus grid/label colors
- `format.lua` - Label formatting utilities (time, percentages)
- `time-series.lua` - Multi-resolution time series with cascading aggregation

**Interactive Features:**
- `interaction.lua` - Hit testing, coordinate transforms, highlight/tooltip creation
- `animation.lua` - Easing functions, interpolation, animation lifecycle
- `interactive-chart.lua` - High-level wrapper with state management
- `events.lua` - Event handler registration for animation processing

### Key Concepts

**Surface Management**: Charts are rendered on hidden Factorio surfaces. `create_surface()` initializes one, then `allocate_chunk()` gives you a 32x32 tile area with lighting. Chunks are reused via a freelist when freed.

**Ring Buffer Data Format**: Line graphs expect data in a ring buffer format:
- `data`: array of `{[series_name]: value}` tables
- `index`: current write position
- `length`: buffer capacity
- Iteration order is `index+1 → length`, then `1 → index` for chronological display

**Rendering Coordinates**: Graphs use pixel-based viewport dimensions (default 900x700) converted to tile coordinates (divide by 32). Graph area has margins for axis labels.

**TTL-Based Cleanup**: All rendered objects use `time_to_live` in ticks. No manual cleanup needed for graph lines/text - they auto-expire.

**Resolution Independence**: Use `get_camera_params()` to calculate correct camera position and zoom for any widget size. The viewport dimensions (default 900x700) define the graph layout in tile space. The function computes the zoom needed to fit the graph into the actual widget dimensions:
```lua
local camera = charts.get_camera_params(chunk, {
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
local surface_data = charts.create_surface("my-surface")  -- once in on_init
local chunk = charts.allocate_chunk(surface_data)
charts.render_line_graph(surface_data.surface, chunk, {...})

-- Calculate camera params for resolution-independent display
local camera = charts.get_camera_params(chunk, {
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

charts.free_chunk(surface_data, chunk)  -- when done
```

### Interactive Charts

The library provides two approaches for adding hover/click interactions:

**High-Level (Recommended):** Use `interactive-chart.lua` wrapper for automatic state management:
```lua
local state = charts.create_interactive_line_graph(surface, chunk, {
    data = ring_buffer, index = idx, length = len,
    counts = counts, sum = sums,
    on_hover = function(region, state) ... end,
    on_click = function(region, button, state) ... end,
})
-- Handle hover: charts.chart_on_hover(state, region_id, player)
-- Update data: charts.update_interactive_line_graph(state, new_options)
-- Cleanup: charts.destroy_interactive_chart(state)
```

**Low-Level:** Use primitives directly for full control:
```lua
-- Render with metadata
local ordered_sums, line_ids, metadata = charts.render_line_graph_with_metadata(...)
-- Create hit regions
local hit_regions = charts.create_line_graph_hit_regions(chunk, metadata)
-- Convert screen position to tile coordinates
local tile_pos = charts.screen_to_tile(camera_pos, zoom, widget_size, screen_pos)
-- Hit test
local region = charts.hit_test(hit_regions, tile_pos)
-- Create visual feedback
local highlight = charts.create_highlight(surface, region)
local tooltip = charts.create_tooltip(surface, tile_pos, {"Line 1", "Line 2"})
```

**Overlay Buttons:** Factorio doesn't expose mouse position over cameras. Use transparent buttons:
```lua
local buttons = charts.generate_overlay_buttons(camera_pos, zoom, widget_size, hit_regions)
-- buttons[i] = {region_id, style_mods, region}
-- Create actual GUI buttons with raise_hover_events=true
```

**Animation:** Smooth transitions via `charts.animation`:
```lua
local anim = charts.animation.create({
    start_tick = game.tick, duration = 30,
    from = {value = 0}, to = {value = 100},
    easing = "ease_in_out",
    on_update = function(t, values, anim) ... end,
})
-- Register tick handler: charts.register_events({})
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
local intervals = charts.create_time_series(interval_defs)

-- Add data each tick - automatically cascades to coarser intervals
charts.add_datapoint(intervals, {series1 = 50, series2 = 75})

-- Render a specific interval
charts.render_line_graph(surface, chunk, {
    data = intervals[2].data,
    index = intervals[2].index,
    length = intervals[2].length,
    counts = intervals[2].counts,
    sum = intervals[2].sum,
})
```
