# Flex and Grid

The V layout API separates measurement from placement. `measure_layout_element`
measures text and content under `LayoutConstraints`; `flex_frames` and
`grid_frames` assign child frames. `flex` and `grid` return an `Element` with
those frames applied. Dimensions and spacing stay fractional through these steps.

## Flex

`FlexConfig` arranges `FlexChild` values horizontally or vertically. A child's
`basis` supplies its preferred main-axis size, `grow` shares extra space, and
`shrink` shares a deficit in proportion to its basis. Minima and maxima constrain
the result. Wrapping creates separate lines with `line_gap` between them.

```v
children := [
    ui2.FlexChild{ element: heading, grow: 1, minimum_width: 170 },
    ui2.FlexChild{ element: action, shrink: 0 },
]
toolbar := ui2.flex(ui2.FlexConfig{
    frame: ui2.rect(0, 0, available_width, 40)
    gap: 12
    align: .center
    children: children
})!
```

`LayoutOrientation`, `LayoutAlignment`, and `LayoutPadding` provide shared
orientation, alignment, and padding values. `FlexChild.align_self` overrides the
container's alignment for one child; `.auto` inherits the container's alignment.

Measure a width-dependent child again after calculating its assigned width.
For example, a wrapped label can need more height when its Flex sibling grows.
Use `measure_layout_element` with that width and then place the measured child.
The measurement callback receives the declared `TextStyle`.

## Grid

`GridConfig` supports fixed rows or columns, track minima, spacing and padding.
With `auto_columns_min_width`, it selects the number of columns that fit the
available width. `max_columns` caps that count. A `GridSpan` can reserve adjacent
rows or columns for a child; automatic grids clamp column spans when the viewport
becomes narrower.

```v
cards := ui2.grid(ui2.GridConfig{
    frame: ui2.rect(0, 0, available_width, available_height)
    auto_columns_min_width: 240
    max_columns: 3
    spacing: ui2.GridSpacing{ horizontal: 16, vertical: 16 }
    child_spans: [ui2.GridSpan{ column_span: 2 }]
    children: project_cards
})!
```

`flex_preferred_size` and `grid_preferred_size` report natural sizes from measured
children. They calculate geometry without constructing a view or invoking actions.
Explicit child frames provide preferences; the parent assigns the final frames.

The [responsive example](../examples/responsive_layout/main.v) combines wrapped
toolbar rows, a search control, and a spanning project grid. The
[grid example](../examples/grid_layout/main.v) demonstrates equal cells. The
[measurement benchmark](../benchmarks/flex_measure/main.v) exercises text
measurement, wrapping, nested Flex containers and responsive Grid placement.
