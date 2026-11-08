# Tables: table and data table

Ports of GPUI Kit's [Table](https://github.com/longbridge/gpui-kit/blob/main/website/component/table.md)
and [DataTable](https://github.com/longbridge/gpui-kit/blob/main/website/component/data-table.md).

| GPUI Kit | ui2 | Source |
| --- | --- | --- |
| `Table`, `TableHeader`, `TableBody`, `TableFooter`, `TableRow`, `TableHead`, `TableCell`, `TableCaption` | `table(TableConfig)` | `ui/component_tables.v` |
| `DataTable`, `TableState`, `TableDelegate`, `Column`, `TableEvent` | `data_table(DataTableConfig)`, `data_table_event`, `DataTableEvent` | `ui/component_tables_data.v` |
| `ColumnSort`, keyboard actions, visible range | `TableSortDirection`, sort orders, `table_visible_rows`, `table_row_after_key` | `ui/component_tables_sort.v` |

Tests are in `ui/component_tables_test.v`. `examples/gpui_tables/main.v` shows
two simple tables and a data table of 5,000 people that sorts, resizes,
selects, scrolls both ways and follows the keyboard:

```sh
v run examples/gpui_tables/main.v
v -d ui2_custom_rendering run examples/gpui_tables/main.v
```

## Conventions

- **Controlled state.** Like every ui2 component the tables own nothing. The
  application keeps the sort, the selection, the hovered row, the column widths
  and the scroll offsets, passes them in, and rebuilds. Clicks, hover reports and
  drags come back through `on_event`; `table_event` and `data_table_event` turn
  them into typed events and return none for events that belong to something
  else, are malformed or forged, name a disabled or absent row, or would change
  nothing.
- **Columns** are `TableColumn{key, title, width, flex = 1, min_width = 40,
  max_width = 1200, align, sortable, resizable = true}`. A column with a `width`
  keeps it; the others share what is left by `flex`. `table_column_widths(columns,
  available)` is the rule both tables use: shares are held between `min_width`
  and `max_width`, and what a held column gives up or takes is shared again among
  the rest. The total can exceed the space: a data table then scrolls sideways
  and a simple table cuts the columns off at its edge.
- **Rows and cells.** `TableRow{key, cells, selected, enabled = true}` holds one
  `TableCell{text, color, bold, content}` per column; `table_text_row(texts)` makes
  a row of plain text. `key` keeps a row's native views across rebuilds (it
  defaults to the index) and must be unique among the rows shown.
- **Sizes** follow GPUI Kit: `table_metrics(size)` gives rows 30, 32 and 40
  points tall with 6, 8 and 12 points of cell padding for `.small`, `.medium` and
  `.large`, the text size of `component_metrics`, and the checkbox geometry.
- **Colors** come from `ComponentTheme`: the header and footer use `muted`, header
  text `muted_foreground`, stripes and hover are steps between `background` and
  `border`, selected rows are tinted with `primary`.

### Cell renderers

A cell is text unless its `content` holds elements, which then replace the text.
Their frames are relative to the cell's content box: the cell less
`table_metrics(size).padding` on each side, as tall as the row. Content is not
clipped, so keep it inside that box; `table_metrics(size).row_height` and the
column widths the application holds (or `data_table_layout(config).widths`)
give its size.

The two tables take rows differently, because of what V makes cheap:

- `table` takes `rows []TableRow`, a prebuilt matrix. A simple table shows a
  handful of rows, so building them all is nothing.
- `data_table` takes `row_count` and `row TableRowFn`, a function from a display
  index to a `TableRow`. It is called only for the rows on screen (plus
  `overscan`), so a build costs the same for 50 rows or a million, and custom
  content is built only for those rows. A closure works, or a plain function
  reading application state:

  ```v
  row: fn [app] (index int) ui2.TableRow {
  	person := app.people[app.order[index]] // display index -> data
  	return ui2.TableRow{
  		key:      person.id.str()
  		selected: person.id in app.selected
  		cells:    [ui2.TableCell{ text: person.name }, ui2.TableCell{
  			text:    person.status // still read out to assistive technology
  			content: [status_pill(person.status)]
  		}]
  	}
  }
  ```

  A per-cell callback was the alternative. One function per row keeps the
  lookup of the row's data in one place and lets the row carry its selection and
  enabled state, which the table needs anyway.

## Table

```v
invoices := ui2.TableConfig{
	id:          'invoices'
	frame:       ui2.rect(24, 92, 560, 0)
	columns:     [
		ui2.TableColumn{ title: 'Invoice', width: 100 },
		ui2.TableColumn{ title: 'Status' },
		ui2.TableColumn{ title: 'Amount', width: 110, align: .right },
	]
	rows:        [
		ui2.table_text_row(['INV001', 'Paid', '$250.00']),
		ui2.table_text_row(['INV002', 'Pending', '$150.00']),
	]
	footer:      [ui2.table_text_row(['Total', '', '$400.00'])]
	caption:     'A list of your recent invoices.'
	hoverable:   true
	hovered_row: app.hovered
	theme:       theme
}
config := ui2.TableConfig{
	...invoices
	frame: ui2.rect(24, 92, 560, ui2.table_height(invoices))
}
el := ui2.table(config)!

// on_event:
if e := ui2.table_event(config, event) {
	match e.kind {
		.hover_row { app.hovered = e.row } // -1 when the pointer left
		.click_row { open_invoice(e.row) }
	}
}
```

| Field | Meaning |
| --- | --- |
| `columns`, `rows`, `footer` | Header titles, body rows, footer rows such as totals |
| `caption` | Muted text centered below the table; also the accessible name unless `accessibility_label` is set |
| `striped` | Every other row gets the stripe color |
| `bordered` | A rounded one-point border (default); off gives a plain surface |
| `column_dividers` | Vertical lines between columns |
| `hoverable`, `hovered_row` | Rows report the pointer entering and leaving (`with_hover`); the row at `hovered_row` is highlighted |
| `clickable_rows` | Each row is a button (`with_button_behavior`) whose click `table_event` reports |
| `empty_text` | Shown with a tray icon when there are no rows |
| `size`, `theme` | As for every component |

`id` is required when rows hover or click. `table_height(config)` is the height
the header, every row, the footer and the caption take. A shorter frame leaves
out the rows that do not fit (the footer keeps its place) rather than drawing
past the frame.

### Implemented and omitted

Implemented: header, body, footer and caption sections; fixed and flexible column
widths with minimum widths (upstream's `w()` and flex-1 cells with a 100 px
minimum); left, center and right alignment; striped rows; border on or off; row
hover; column dividers; custom cell content; sizes; an empty state; row clicks.

Omitted: `col_span` (cells line up with columns; give a wide cell a `content`
that runs over its neighbors' empty cells instead), arbitrary `Styled`
refinements on every part (use the config fields and `ComponentTheme`), and
several header or footer rows of different shapes (header titles come from the
columns).

## Data table

```v
fn people_config(app &App) ui2.DataTableConfig {
	body := ui2.data_table_body_id('people')
	return ui2.DataTableConfig{
		id:             'people'
		frame:          ui2.rect(24, 396, 1152, 440)
		columns:        app.columns // TableColumn with the widths the user dragged to
		row_count:      app.people.len
		row:            person_row // see "Cell renderers"
		scroll_x:       ui2.scroll_horizontal_offset(body)
		scroll_y:       ui2.scroll_offset(body)
		sort_column:    app.sort_column
		sort_direction: app.sort_direction
		selection:      .multiple
		selected_count: app.selected.len
		active_row:     app.active_row
		resize_drag:    app.drag
		hovered_row:    app.hovered
		loading:        app.loading
		striped:        true
		theme:          theme
	}
}

fn on_event(event string) {
	e := ui2.data_table_event(people_config(app), event) or { return }
	match e.kind {
		.sort {
			app.sort_column = if e.direction == .none { -1 } else { e.column }
			app.sort_direction = e.direction
			app.order = ui2.table_sort_order_text(app.people.map(it.name), e.direction)
		}
		.select_row {
			app.selected = {
				app.id_at(e.row): true
			}
			app.active_row = e.row
		}
		.toggle_row {
			app.set_selected(e.row, e.checked)
			app.active_row = e.row
		}
		.select_all {
			app.select_all(e.checked)
		}
		.clear_selection {
			app.selected.clear()
		}
		.hover_row {
			app.hovered = e.row
		}
		.resize_start {
			app.drag = e.drag
		}
		.resize {
			app.set_widths(e.widths)
		}
		.resize_end {
			app.set_widths(e.widths)
			app.drag = ui2.TableResizeDrag{}
		}
	}
	ui2.refresh()
}

fn on_key_event(key ui2.KeyEvent) {
	config := people_config(app)
	e := ui2.data_table_event_from_key(config, key) or { return }
	ui2.consume_key()
	// ... apply e as above, then keep the row in view:
	if y := ui2.data_table_scroll_to_row(config, e.row) {
		ui2.scroll_to_offset(ui2.data_table_body_id('people'), y)
	}
	ui2.refresh()
}

fn on_scroll(id string) {
	if id == ui2.data_table_body_id('people') {
		ui2.request_refresh() // build the rows that scrolled in
	}
}
```

Build the config in one function and use it for building and for decoding, so
the decoder sees exactly what was shown.

### Layout, scrolling and virtual rows

The header stays put above a body that is a `Scroll` element with
`scroll_mode: .both` and the id `data_table_body_id(id)`. Pass its offsets in as
`scroll_x` and `scroll_y` on every build: the rows built follow `scroll_y` and
the header (and footer) follow `scroll_x`, so they stay aligned with the columns
when a wide table scrolls sideways. The offsets are held to the scroll range.

Only rows in `table_visible_rows(row_count, row_height, body height, scroll_y,
overscan)` get elements; a one-point spacer at the bottom of the content keeps
the full scroll height. `overscan` (6) rows are built beyond each edge so rows
exist before a scroll brings them in. Native backends report scrolling through
`on_scroll`; rebuild then with `request_refresh()`, not `refresh()`, since a
scroll can be reported while a build is being put on screen. The custom renderer
builds every frame and needs nothing. The iOS backend does not expose scroll
offsets (see the README's "Scrolling"); there, leave `scroll_y` at 0 and raise
`overscan` to build every row of a modest table.

`data_table_layout(config)` returns where everything goes (the box, header,
body, footer and caption rectangles, resolved `widths`, column offsets `xs`,
`content_width`, the clamped offsets and the `rows` range built), for overlays
and for laying out custom content.

ui2 views do not clip their children on every renderer, so the header and
footer bands are id-less `Scroll` elements used as clipping strips: their single
child starts `scroll_x` to the left and ends exactly at the strip's right edge,
so there is nothing for the strip itself to scroll.

### Sorting

A sortable column's header is a button with a sort icon (`arrow.up.arrow.down`
dimmed when unsorted, `arrow.up` or `arrow.down` when sorted). A click reports
`.sort` with the next direction: a new column starts `.ascending`, then
`.descending`, then `.none` (`TableSortDirection.next()`). The table does not
sort; the application keeps a display order and maps display indices through
it in its row function. Stable sort helpers return that order:

- `table_sort_order_text(values []string, direction) []int` compares with
  `table_compare_text`: case-insensitive, and digit runs by value (`Item 9`
  before `Item 10`).
- `table_sort_order_numbers(values []f64, direction) []int`; NaN goes last
  either way.

Both are stable in both directions (values that compare equal keep their
order), and `.none` returns the data order.

### Resizing

Every resizable column (`TableColumn.resizable`, on by default) has an
eight-point drag handle across its header divider (`draggable`, with the
`resize_ew` cursor). `data_table_event` turns its pointer reports into:

1. `.resize_start` on the press, carrying `drag` (`TableResizeDrag{column,
   start_x, start_width}`). Store it and pass it as `resize_drag`.
2. `.resize` on every move, with the new `width` and all `widths`: the start
   width plus how far the pointer moved, held between the column's `min_width`
   and `max_width` (`table_resize_width`, `table_resized_widths`). Store the
   widths as the columns' `width`, which also fixes a flexible column's width.
3. `.resize_end` on release, the same, after which clear `resize_drag`.

The divider being dragged is drawn in the accent color. Working from the press
position rather than from the window position of the divider keeps resizing
right wherever the table is nested and however far it is scrolled.

### Selection

`selection` is `.none`, `.single` or `.multiple`. With `.single` a row click
reports `.select_row`. With `.multiple` a checkbox column comes first: a row's
checkbox reports `.toggle_row` with the new `checked`, the header checkbox
reports `.select_all` (checked when some or no rows are selected, unchecked when
all are; it shows the mixed dash when `0 < selected_count < row_count`, see
`table_check_state`), and a click elsewhere in a row still reports
`.select_row`, which applications usually treat as "select only this row".
Selected rows are tinted, `active_row` (the keyboard cursor) is outlined in the
accent color, and rows with `enabled: false` are dimmed and ignore clicks.

Selection is reported by display index. Keep the selection by your own row
identity (the gallery uses person ids) so it survives sorting.

### Keyboard

Components cannot take focus, so call `data_table_event_from_key(config,
event)` from `on_key_event` while the table should follow the keyboard:

| Key | Event |
| --- | --- |
| Up, Down, Page Up, Page Down, Home, End | `.select_row` with the row the active row moves to (`table_row_after_key`; Page keys move by `data_table_page_rows(config)`), skipping disabled rows |
| Space (multiple) | `.toggle_row` for the active row |
| Cmd+A / Ctrl+A (multiple) | `.select_all` |
| Escape | `.clear_selection` when something is selected |

`data_table_scroll_to_row(config, row)` is the vertical offset that brings a
row into view, or none when it already is.

### Hover, loading, empty, footer

- `hoverable` (on by default) makes rows report the pointer; `.hover_row` gives
  the row under it, or -1 when it left. Store it as `hovered_row`.
- `loading` replaces the rows with skeleton bars, one per column at varied
  lengths and placed by the column's alignment, as GPUI Kit's table does. The
  header stays; sorting, resizing and selection are off. The bars are static; overlay
  `shimmer` on `data_table_layout(config).body` for a moving sheen.
- With no rows the body shows `empty_text` under a tray icon.
- `footer` rows are pinned below the body and scroll sideways with it.
- `caption`, `striped`, `bordered`, `column_dividers`, `header_height` (0 uses
  the row height), `enabled`, `size` and `theme` work as for the simple table.

### Implemented and omitted

Implemented: virtual rows over any row count; sticky header and footer; two-axis
scrolling with the header following the body; sortable columns with the three
states and stable sort helpers; column resizing between minimum and maximum
widths; row selection (single, multiple with checkboxes and an indeterminate
select-all); row hover; disabled rows; keyboard row navigation (Up, Down, Page
Up, Page Down, Home, End, Escape, plus Space and select-all); scrolling a row
into view; loading skeleton; empty state; stripes, border, column dividers;
sizes and a custom header height; custom cell content.

Omitted, with the reason:

- **Column moving and fixed (pinned) columns.** ui2 has no drag-and-drop between
  elements; a pinned column would need a second vertical scroll kept in step
  with the body from `on_scroll`, which lags a frame on native backends.
- **Column and cell selection, double- and right-click events, context menus.**
  ui2 reports neither double clicks nor right clicks on composed views, and
  modifier keys do not come with clicks, so Shift and Cmd clicks cannot extend a
  selection. Space and the checkboxes cover multiple selection.
- **Fit-to-content on double-clicking a divider.** There is no backend-neutral
  text measurement; `component_text_width_estimate` is too rough for it.
- **Infinite loading (`has_more`, `load_more`).** Compare
  `data_table_layout(config).rows.end` with `row_count` when building and fetch
  more yourself; the table needs no hook for it.
- **Column groups and several header rows, scroll bounce, scrollbar visibility.**
  Not portable or not needed for the documented use; the backends' own
  scrollers are used.
- **Upstream's sort cycle** goes Default → Descending → Ascending. This port
  starts ascending, as spreadsheets do.

## Accessibility

The simple table's root has role `table` and the data table's `grid`, labelled
by `accessibility_label` or the caption; the data table's value is
`"<n> rows"` (or `loading`). Rows have role `row`, a label made of their cell
texts and the value `selected`; plain header cells `columnheader`; sortable
headers are buttons whose value is `sorted ascending` or `sorted descending`;
checkboxes are `checkbox` with `checked`, `unchecked` or `mixed`; the body is a
`rowgroup`; resize handles are `separator`s labelled `Resize <title>`; the
loading skeleton is a `status`.

## Platform notes

- AppKit reads tables, grids and row groups as groups; rows, cells and column
  headers keep their native button role so they stay pressable.
- The empty state's `tray` icon is an outline on Apple platforms and Material's
  filled inbox elsewhere: Material Icons has no outlined tray.

## Attribution

No upstream code is adapted. The row heights and cell paddings per size are
GPUI Kit's (`Size::table_row_height` and `table_cell_padding` in
`crates/component/src/sizing.rs`), as are the 1200-point default maximum
column width and the skeleton layout of the loading state; everything else is
a new implementation of the documented behavior.

## Verification

```sh
v test ui/component_tables_test.v
v -d ui2_custom_rendering test ui/component_tables_test.v
v run examples/gpui_tables/main.v
v -d ui2_custom_rendering run examples/gpui_tables/main.v
```
