# Factorio Charts

A reusable charting library for Factorio 2.0+ mods. Provides line graphs and stacked bar charts rendered on hidden surfaces, viewable through GUI camera widgets.

## Features

- **Line Graphs**: Multi-series time series data with auto-scaling Y-axis
- **Stacked Bar Charts**: Phase breakdown visualization with optional hatched phases
- **Interactive Charts**: Hit testing, hover highlights, tooltips, overlay buttons, production-graph crosshair hover
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
    y_range = {0, 100},           -- Optional fixed range, "zero" (min pinned at 0), or nil for auto-scale
    label_format = "percent",     -- "percent", "time", "si", or function(value) -> string
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

## Axes and number formatting

Line graphs can look like Factorio's Production statistics graph. The axis options below are opt-in; the
line, grid and background style is the default since 1.3.0 (see "The look" below).

```lua
charts.render.line_graph(surface, chunk, {
    data = ring_buffer, index = idx, length = len, counts = counts, sum = sums,
    label_format = "si",          -- Y labels "0", "16k", "1.2M"
    grid_lines = 8,               -- horizontal grid lines incl. top and bottom (default 8 since 1.3.0, was 5;
                                  -- 5 with a fixed {min, max} y_range, so {0, 100} reads 0/25/50/75/100)
    y_range = "zero",             -- auto max, min pinned at 0 ({min, max} stays a fixed range)
    nice_ticks = true,            -- round the auto range to 1/2/2.5/5 x 10^k steps (default false)
    x_axis = {                    -- default false: no X labels
        ticks_per_point = 60,     -- game ticks per ring-buffer slot (time_series fills it from interval.ticks)
        format = "auto",          -- "auto" | "seconds" | "minutes" | "hours" | function(seconds_ago) -> string
        labels = "auto",          -- "auto" (>= 40 px apart at zoom 1) or a maximum label count
        grid = false,             -- vertical grid lines at the labels
    },
})
```

The X axis counts time backwards: the newest slot is "0" at the right edge and a 600 x 1 s buffer reads "10"
(minutes) at the left edge, with labels every 0.5. Each column is one time slot ending at its point, so points are
`plot width / columns` apart, the newest on the right edge and the oldest one slot in from the left edge, and the
left edge is exactly `columns x ticks_per_point / 60` seconds old (1.2.0 spread the points `width / (columns - 1)`
apart, oldest on the left edge). "auto" picks seconds below 2 minutes, minutes below 2 hours,
hours above. The plot shrinks by 0.7 tile to make room for the label row. "si", "time" and "percent" Y labels add
decimals when two neighbouring ticks would otherwise read the same.

`render_line_graph_with_metadata` returns, besides the 1.2.0 fields (`graph_*`, `min_y`, `max_y`, `dx`, `dy`,
`point_positions`):

| Field | Meaning |
|-------|---------|
| `columns` | Number of ring-buffer slots drawn (= `length`) |
| `x_positions[i]` | Plot x of column i in chunk-relative tiles, 1 = oldest, `columns` = newest: `plot.left + i * dx` with `dx = plot width / columns` |
| `seconds_ago[i]` | Age of column i in seconds (`(columns - i) * ticks_per_point / 60`); nil without `x_axis` |
| `plot` | `{left, top, right, bottom}`: the plot rectangle, chunk-relative, without the label gutters |
| `series_order` | `{name, color_index}` per drawn series, bottom-most first (the last entry is drawn on top) |
| `y_ticks` | `{value, y, text}` per horizontal grid line, bottom first |
| `x_labels` | `{seconds_ago, value, text, x}` per X label, newest ("0") first; nil without `x_axis` |
| `x_unit`, `x_step`, `ticks_per_point` | Display unit, label step in that unit, ticks per slot; nil without `x_axis` |
| `label_format` | The Y label format in use |

`charts.render.time_series` passes `x_axis`, `grid_lines`, `nice_ticks`, `y_range`, `camera_zoom`, `line_px`,
`line_width` and `smooth` through and caches the metadata on `intervals[i].metadata`.

## The look (1.3.0)

Charts draw like the vanilla Production statistics graph by default: a pure black plot area, 1 px series lines,
8 faint grid lines and small grey labels. The numbers were measured on Factorio 2.1, where `draw_line` is not
anti-aliased and a width `w` shows as about `ceil(w * camera_zoom)` whole screen pixels (never less than 1).

```lua
charts.render.line_graph(surface, chunk, {
    -- ...data options...
    camera_zoom = player.display_scale / player.display_density_scale,  -- the zoom your camera widget uses (default 1.5)
    line_px = 1,                  -- series thickness in screen pixels (default 1; 2 for an emphasised series)
    line_width = nil,             -- raw draw_line width; wins over line_px
    smooth = 3,                   -- centred moving average over the drawn values (odd window; default nil = off)
})
charts.render.stacked_bars(surface, chunk, {..., camera_zoom = zoom})  -- 1 px grid and hatching
```

- Pass `camera_zoom` when your camera zoom is not 1.5; without it the library assumes 1.5 (Cybersyn's
  `display_scale / display_density_scale` on 4K at UI scale 1.5). The default width (1/3) is still 1 px at zoom 1
  and 0.75; it only gets thicker above zoom 3.
- `smooth` averages each value with its neighbours in time (the window shrinks at the ends; missing values stay
  gaps). Raw per-sample data with one point per ~3 GUI pixels zig-zags; `smooth = 3` looks closest to vanilla,
  which averages many ticks per column. The Y range follows the smoothed values; metadata `point_positions` carry
  the drawn `value` and the original `raw_value`, plus `metadata.smooth`, `metadata.camera_zoom` and
  `metadata.line_width`.
- About 300 columns across a 900 px viewport is the right density; more points than screen pixels only add noise
  and render objects (300 x 6 series = 1794 segments, about 4 ms to draw).

`charts.style` holds the recipe for your own drawing (hover markers, legends):

| Name | Value |
|------|-------|
| `style.line_width(px, zoom)` | `(px - 0.5) / zoom`: the `draw_line` width that gives `px` screen pixels |
| `style.grid_width(zoom)` | 1 px grid width |
| `style.DEFAULT_ZOOM`, `style.DEFAULT_LINE_PX`, `style.GRID_LINES` | 1.5, 1, 8 |
| `style.grid_color()`, `style.label_color()` | {0.25, 0.25, 0.25}, {0.7, 0.7, 0.7} |
| `style.LABEL_FONT`, `style.LABEL_SCALE` | "default", 0.93 (about 14 px digits at zoom 1.5), `scale_with_zoom = false` |
| `style.draw_label(params)` | `rendering.draw_text` with the label font, scale and colour filled in |
| `style.series_colors()`, `style.series_color(i)` | The 12-colour palette (indices unchanged) |
| `style.smooth(values, n, count)` | The moving average used by `smooth` |

**Background and existing saves.** Chunks are now `out-of-map` tiles on a surface with `always_day = true`
(pure black, no render objects), instead of `lab-dark-1` tiles lit by nine lights (which rendered a flat dark
grey). `create_surface` sets `always_day` on an existing surface too (so do `allocate_chunk` and
`ensure_tile_coverage`, for surfaces kept from an old save), and new or reused chunks get the new tiles.
Chunks your mod already holds from an older version keep their lights and lab tiles until you convert them:
call `charts.surface.restyle_chunk(surface_data, chunk)` once per stored chunk (for example from
`on_configuration_changed`), or free and re-allocate them. `restyle_chunk` is idempotent.

## Crosshair hover (line graphs)

Like the vanilla production graph: hovering a line graph draws a white vertical line at the hovered column, a
white horizontal line and a small circle at the hovered point, redraws that series twice as thick, and shows a
native tooltip ("iron-plate / 35k - 6.6 minutes ago"). Factorio reports no mouse position over a camera, so the
plot is covered with transparent overlay buttons that raise `on_gui_hover` / `on_gui_leave`.

1. A transparent button style in your `data.lua`:
   ```lua
   data.raw["gui-style"].default.my_chart_overlay_button = {
       type = "button_style", parent = "button",
       default_graphical_set = {}, hovered_graphical_set = {}, clicked_graphical_set = {},
       padding = 0, minimal_width = 1, minimal_height = 1,
   }
   ```
2. An interactive line graph with a stable id, and the buttons on its camera:
   ```lua
   local state = charts.interactive.create_line_graph(surface, chunk, {
       id = "my-mod-production-" .. player.index,  -- stable across save/load (generated ids are not)
       data = ring, index = idx, length = len, counts = counts, sum = sums,
       label_format = "si", x_axis = {ticks_per_point = 120},  -- the tooltip shows "... - 6.6 minutes ago"
   })
   local camera_info = charts.surface.setup_camera_widget(camera, surface, chunk, {
       widget_width = 900, widget_height = 700, zoom_override = player.display_scale / player.display_density_scale,
   })
   local configs = charts.interactive.get_hover_buttons(state, camera_info, {player = player})
   charts.interaction.create_overlay_buttons(camera, configs, {
       button_style = "my_chart_overlay_button", widget_width = 900, widget_height = 700,
   })
   ```
3. Forward the two GUI events from your own handlers (a mod has one handler per event, so the library never
   registers them itself). Both return `true` when the element was a chart button:
   ```lua
   script.on_event(defines.events.on_gui_hover, function(e) charts.events.handle_gui_hover(e) end)
   script.on_event(defines.events.on_gui_leave, function(e) charts.events.handle_gui_leave(e) end)
   ```

Each button carries `tags = {factorio_charts = {chart = state.id, region = region_id}}`; the handlers look the
state up in a registry filled by `create_line_graph` (module state, not saved: call
`charts.interactive.register(state, callbacks)` in `on_load` for states you keep in `storage`). Hover needs `options.id`:
only states created with one are registered, and `get_hover_buttons`, `set_hover` and `register` raise
`factorio-charts: interactive charts need options.id to use hover` for a state without it. Generated ids come
from a counter that is not saved, so a joining client or a reloaded save would hand out different ids than the
server did. Charts that never use hover can still omit the id.

States kept in `storage`: pass callbacks to `charts.interactive.register(state, callbacks)` in `on_load`, where
`callbacks = {on_cell_hover = fn, on_cell_leave = fn, format_tooltip = fn}`; function options are not saveable.
Callbacks given to `register` win over the same names in the chart options, which still work for states that are
never saved. `format_tooltip` there has the `opts.format_tooltip(cell, state)` signature of `get_hover_buttons`. The crosshair objects use
`players = {player}`, so each player only sees their own; hovering never re-renders the graph. Forgetting
`register` in `on_load` makes hover silently do nothing: the handlers do not find the chart and return `false`.

Details:
- `get_hover_buttons(state, camera_info, opts)`: `opts.mode = "cell"` (default: each column is split between the
  series at the midpoints of their y values, so the cell under the pointer is the series nearest in y) or
  `"column"` (one full-height button per column, markers on every series, tooltip lists all values).
  `opts.max_buttons` (default 400): when columns x series exceeds it, k = ceil(columns x series / max_buttons)
  adjacent columns share a button and report the centre column, or the nearest column of the group that has
  points when the centre has none (300 columns x 6 series -> k = 5, 360 buttons).
  `opts.format_tooltip(cell, state) -> LocalisedString` replaces the default tooltip. Button positions are in GUI
  units: pass `opts.player`, which derives the factor, or `opts.gui_zoom` to state it outright. Passing neither
  errors. `gui_zoom = 1` is right only for a camera zoom of exactly `display_scale / display_density_scale`
  (Cybersyn's Breakdown tab); any other zoom, such as Utilization's `display_scale / display_density_scale +
  0.05`, drifts further off the plot the further a column is from the widget centre.
- Rebuild the buttons after `update_line_graph` (the tooltips hold values). An active crosshair follows a redraw
  to the same column and series. Rebuilding is not free (about 9 ms for 360 buttons), so do it when the data
  changes, throttled to the chart's refresh cadence, not every tick.
- The default tooltip shows the internal series name (the key in your data, e.g. `iron-plate`); use
  `opts.format_tooltip` for localised names or rich-text icons.
- `charts.interactive.set_hover(state, player, cell)` / `clear_hover(state, player)` drive it directly;
  `options.on_cell_hover(cell, player, state)` and `options.on_cell_leave(player, state)` fire alongside (the old
  `on_hover(region, state)` / `on_hover_leave(region_id, state)` belong to the `charts.interactive.on_hover` path).
  Cell data: `{column, first_column, last_column, series_name, value, seconds_ago, graph_x, graph_y, color}`.
- Options on the chart: `hover_series_mode` (`"lines"` default, one object per segment, uniform thickness like
  vanilla; `"polygon"`, one mitred triangle strip per unbroken run, 4 objects but uneven thickness), `hover_color` (guide lines, default 60% white),
  `hover_ttl`, and `camera_zoom` (default 1.5): widths are chosen so the guides are 1 screen px and the hovered
  series twice as thick as the base line on screen.
- Without `charts.interactive`: `charts.interaction.create_line_graph_hover_regions(chunk, metadata, opts)` and
  `charts.interaction.draw_crosshair(surface, chunk, metadata, cell, player, opts)` (`opts.camera_zoom` wins over
  `metadata.camera_zoom`, then 1.5).

Measured on Factorio 2.1 (900x700 widget, UI scale 1.5): regions + configs 2.0 ms / overlay buttons 3.7 ms at
100 columns x 6 series (300 buttons), 3.1 ms / 5.6 ms at 300 x 6 (360 buttons, 720 GUI elements); one hover
about 0.7 ms and 302 render objects at 300 columns (polygon mode: 0.1-0.3 ms, 4 objects).

## API Reference

### Surface Management (`charts.surface`)

| Function | Description |
|----------|-------------|
| `charts.surface.create(name)` | Create a hidden surface for rendering |
| `charts.surface.allocate_chunk(surface_data)` | Get a chunk for rendering a graph |
| `charts.surface.free_chunk(surface_data, chunk)` | Return a chunk when done |
| `charts.surface.restyle_chunk(surface_data, chunk)` | Give a chunk from an older version the black background (idempotent) |
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
| `charts.interaction.create_overlay_buttons(parent, configs, options)` | Create z-ordered buttons on a camera widget (`raise_hover_events`, per-config `tags`) |
| `charts.interaction.create_line_graph_hover_regions(chunk, metadata, opts)` | Crosshair regions (`"crosshair_cell"` / `"crosshair_column"`) |
| `charts.interaction.draw_crosshair(surface, chunk, metadata, cell, player, opts)` | Draw a crosshair for one player |

### Interactive Charts (`charts.interactive`)

| Function | Description |
|----------|-------------|
| `charts.interactive.create_line_graph(surface, chunk, options)` | Create interactive line graph with state |
| `charts.interactive.update_line_graph(state, options)` | Update with new data |
| `charts.interactive.create_bar_chart(surface, chunk, options)` | Create interactive bar chart with state |
| `charts.interactive.update_bar_chart(state, options)` | Update with new data |
| `charts.interactive.on_hover(state, region_id, player)` | Handle hover event (highlight + rendered tooltip) |
| `charts.interactive.get_hover_buttons(state, camera_info, opts)` | Tagged overlay button configs for crosshair hover |
| `charts.interactive.set_hover(state, player, cell)` / `clear_hover(state, player)` | Show / remove a player's crosshair |
| `charts.interactive.get_hover_regions(state)` | Crosshair regions for the current data |
| `charts.interactive.register(state, callbacks?)` / `unregister` / `get_state(id)` | Registry the GUI hover handlers use (states with `options.id` only) |
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
| `charts.events.handle_gui_hover(event)` | Forward `on_gui_hover`: draws the crosshair of a tagged chart button |
| `charts.events.handle_gui_leave(event)` | Forward `on_gui_leave`: clears it (only for the region being left) |

### Colors & Formatting

| Function | Description |
|----------|-------------|
| `charts.colors.get_series_colors()` | Get the 12-color palette array |
| `charts.colors.get_series_color(index)` | Get a specific series color |
| `charts.format.time_label(seconds)` | Format as "30s", "2.5m", "15m", "2.5h" (one decimal below 10 of a unit) |
| `charts.format.percent_label(value, decimals?)` | Format as percentage |
| `charts.format.si_label(value)` | Format as "950", "1.2k", "16k", "1.2M" (production-graph style) |
| `charts.format.time_ago(seconds)` | Format as "42 seconds ago", "6.6 minutes ago", "1.3 hours ago" |

### Backward Compatibility

All flat aliases (e.g., `charts.create_surface()`, `charts.render_line_graph()`) continue to work. See CLAUDE.md for architectural details.

## License

MIT License - See LICENSE file

## Credits

Graph rendering technique inspired by [factorio-timeseries](https://mods.factorio.com/mod/timeseries) by Kirk McDonald.

Developed for [Project Cybersyn](https://mods.factorio.com/mod/cybersyn).
