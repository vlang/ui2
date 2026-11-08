module ui2

import math

// DataTable: GPUI Kit's DataTable for large row counts. The header stays put
// over a body that scrolls both ways, and only the rows in view are built. Like
// every ui2 component it is controlled: the application owns the sort, the
// selection, the column widths and the scroll offsets, passes them in, and turns
// what the table emits back into new values with data_table_event.

// Both scroll backends leave this much room below a Scroll element's content.
const data_table_scroll_inset = 16.0

// Half the width of the strip that grabs a header divider.
const data_table_handle_reach = 4.0

pub enum TableSelectionMode {
	none
	single   // A row click selects that row.
	multiple // A checkbox column, with a select-all checkbox in the header.
}

// TableResizeDrag remembers where a column drag started. data_table_event hands
// one out with resize_start; keep it in resize_drag until resize_end.
pub struct TableResizeDrag {
pub:
	column      int = -1
	start_x     f64 // Window x of the press.
	start_width f64
}

pub fn (drag TableResizeDrag) active() bool {
	return drag.column >= 0
}

// TableRowFn returns the row shown at a display index. The data table calls it
// only for the rows in view (and from data_table_event for the row an event
// names), so the cost of a build does not grow with row_count. Map the display
// index through the application's sort order to its data.
pub type TableRowFn = fn (index int) TableRow

pub struct DataTableConfig {
pub:
	id      string // Required.
	frame   Rect
	columns []TableColumn
	// row_count rows exist; `row` builds the ones on screen.
	row_count int
	row       TableRowFn = unsafe { nil }
	footer    []TableRow // Rows pinned under the body, such as totals.
	caption   string
	// scroll_x and scroll_y are the body's scroll offsets. Read them with
	// scroll_horizontal_offset and scroll_offset of data_table_body_id(id) when
	// building: the header follows scroll_x and the rows built follow scroll_y.
	scroll_x f64
	scroll_y f64
	overscan int = 6 // Rows built beyond each edge of the body.
	// sort_column is the column the application sorted by, or -1.
	sort_column         int = -1
	sort_direction      TableSortDirection
	selection           TableSelectionMode
	selected_count      int // How many rows are selected, for the select-all checkbox.
	active_row          int = -1 // The keyboard cursor; outlined in multiple selection.
	resize_drag         TableResizeDrag
	hoverable           bool = true
	hovered_row         int  = -1
	loading             bool // Shows skeleton rows instead of data.
	striped             bool
	bordered            bool = true
	column_dividers     bool
	header_height       f64 // 0 uses the row height.
	empty_text          string = 'No data'
	enabled             bool   = true
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// DataTableLayout is where a data table puts its parts, in table-local points.
pub struct DataTableLayout {
pub:
	box             Rect // The bordered surface.
	header          Rect
	body            Rect // The scrolling body.
	footer          Rect // Zero height without footer rows.
	caption         Rect
	corner          f64 // Reach of the rounded corners, kept clear of square fills.
	selection_width f64 // The checkbox column; 0 without one.
	widths          []f64
	xs              []f64 // Left edge of each column in the scrolled content.
	content_width   f64
	row_height      f64
	scroll_x        f64 // The offsets passed in, held to the scroll range.
	scroll_y        f64
	rows            TableRowRange // The rows built.
}

// data_table_body_id is the id of the body's Scroll element, for scroll_offset,
// scroll_horizontal_offset, scroll_to_offset and on_scroll.
pub fn data_table_body_id(id string) string {
	return component_part_id(id, 'body')
}

fn data_table_header_height(config DataTableConfig, metrics TableMetrics) f64 {
	return if component_finite(config.header_height) && config.header_height > 0 {
		config.header_height
	} else {
		metrics.row_height
	}
}

pub fn data_table_layout(config DataTableConfig) DataTableLayout {
	metrics := table_metrics(config.size)
	rh := metrics.row_height
	border := table_border(config.bordered)
	width := config.frame.width
	caption_height := math.min(table_caption_height(config.caption, metrics), config.frame.height)
	box := rect(0, 0, width, math.max(0.0, config.frame.height - caption_height))
	inner_width := math.max(0.0, width - 2 * border)
	inner_height := math.max(0.0, box.height - 2 * border)
	corner := if config.bordered { math.max(0.0, metrics.radius - border) } else { 0.0 }
	header_height := math.min(data_table_header_height(config, metrics), inner_height)
	footer_height := math.min(f64(config.footer.len) * rh, inner_height - header_height)
	header := rect(border, border, inner_width, header_height)
	footer := rect(border, border + inner_height - footer_height, inner_width, footer_height)
	// Without a footer the body stops short of the rounded bottom corners, which
	// a highlighted row would otherwise poke past.
	bottom := if footer_height > 0 { footer.y } else { border + inner_height - corner }
	body := rect(border, border + header_height, inner_width, math.max(0.0, bottom - border -
		header_height))
	selection_width := if config.selection == .multiple { metrics.checkbox_column } else { 0.0 }
	widths := table_column_widths(config.columns, math.max(0.0, inner_width - selection_width))
	mut content_width := selection_width
	for value in widths {
		content_width += value
	}
	total := if config.loading { 0.0 } else { f64(math.max(0, config.row_count)) * rh }
	max_y := math.max(0.0, total + data_table_scroll_inset - body.height)
	max_x := math.max(0.0, content_width - inner_width)
	scroll_y := if component_finite(config.scroll_y) {
		math.min(max_y, math.max(0.0, config.scroll_y))
	} else {
		0.0
	}
	scroll_x := if component_finite(config.scroll_x) {
		math.min(max_x, math.max(0.0, config.scroll_x))
	} else {
		0.0
	}
	caption_y := math.min(box.height + metrics.gap, config.frame.height)
	return DataTableLayout{
		box:             box
		header:          header
		body:            body
		footer:          footer
		caption:         rect(0, caption_y, width, math.max(0.0, math.min(rh, config.frame.height - caption_y)))
		corner:          corner
		selection_width: selection_width
		widths:          widths
		xs:              table_offsets(widths, selection_width)
		content_width:   content_width
		row_height:      rh
		scroll_x:        scroll_x
		scroll_y:        scroll_y
		rows:            if config.loading {
			TableRowRange{}
		} else {
			table_visible_rows(config.row_count, rh, body.height, scroll_y, config.overscan)
		}
	}
}

fn data_table_validate(config DataTableConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	table_validate_columns(config.columns)!
	if config.row_count < 0 {
		return error('data table row_count must not be negative')
	}
	if config.row_count > 0 && voidptr(config.row) == unsafe { nil } {
		return error('data table needs a row function for its rows')
	}
}

fn data_table_resizable(config DataTableConfig, column int) bool {
	return config.enabled && !config.loading && column >= 0 && column < config.columns.len
		&& config.columns[column].resizable
}

pub fn data_table(config DataTableConfig) !Element {
	data_table_validate(config)!
	metrics := table_metrics(config.size)
	colors := table_colors(config.theme)
	layout := data_table_layout(config)
	mut box_children := []Element{}
	// The header and footer fills carry the rounded corners; the clipping strips
	// over them start below and end above those corners.
	if layout.header.height > 0 {
		box_children << table_fill(layout.header, layout.corner, colors.head, .start)
		box_children << data_table_strip(layout, rect(layout.header.x, layout.header.y +
			layout.corner, layout.header.width, math.max(0.0, layout.header.height - layout.corner)),
			layout.corner, layout.header.height, colors.head, data_table_header_cells(config,
				layout, metrics, colors), 'header')
		box_children << table_line(rect(layout.header.x, layout.header.y + layout.header.height - 1,
			layout.header.width, 1), colors.row_border, 'header:line')
	}
	box_children << Element{
		...scroll_with_mode(data_table_body_id(config.id), layout.body, colors.surface,
			.both, data_table_body_rows(config, layout, metrics, colors))
		key:                 'body'
		accessibility_role:  'rowgroup'
		accessibility_label: 'Rows'
	}
	if config.loading {
		box_children << Element{
			...view('', layout.body, BoxStyle{ transparent: true }, data_table_skeleton(config.columns,
				layout, metrics, colors))
			key:                 'loading'
			accessibility_role:  'status'
			accessibility_label: 'Loading'
		}
	} else if config.row_count == 0 && layout.body.height > 0 {
		box_children << Element{
			...view('', layout.body, BoxStyle{ transparent: true }, table_empty_elements(rect(0,
				0, layout.body.width, layout.body.height), config.empty_text, metrics, colors))
			key: 'empty'
		}
	}
	if layout.footer.height > 0 {
		box_children << table_fill(layout.footer, layout.corner, colors.head, .end)
		box_children << data_table_strip(layout, rect(layout.footer.x, layout.footer.y,
			layout.footer.width, math.max(0.0, layout.footer.height - layout.corner)), 0,
			layout.footer.height, colors.head, data_table_footer_cells(config, layout, metrics,
				colors), 'footer')
		box_children << table_line(rect(layout.footer.x, layout.footer.y, layout.footer.width,
			1), colors.row_border, 'footer:line')
	}
	box_style := if config.bordered {
		component_box(colors.surface, colors.border, metrics.radius)
	} else {
		BoxStyle{
			bg: colors.surface
		}
	}
	mut children := [
		Element{
			...view('', layout.box, box_style, box_children)
			key: 'box'
		},
	]
	if config.caption.len > 0 && layout.caption.height > 0 {
		children << Element{
			...label('', config.caption, layout.caption, TextStyle{
				color: colors.muted_text
				size:  metrics.font_size
				align: .center
			})
			key: 'caption'
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'grid'
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			config.caption
		}
		accessibility_value: if config.loading {
			'loading'
		} else {
			'${config.row_count} rows'
		}
	})
}

// data_table_strip shows a header or footer band moved sideways with the body.
// ui2 views do not clip, so the band is an id-less Scroll element, which clips
// and, with nothing reaching past its right edge, has nothing to scroll: its
// one child starts scroll_x to the left and ends exactly at that edge, and
// carries the cells at their content positions. `lift` moves the cells up when
// the strip starts below the band's top.
fn data_table_strip(layout DataTableLayout, frame Rect, lift f64, height f64, bg u32, cells []Element, key string) Element {
	content := view('', rect(-layout.scroll_x, -lift, frame.width + layout.scroll_x, height),
		BoxStyle{ transparent: true }, cells)
	return Element{
		...scroll_with_mode('', frame, bg, .horizontal_only, [content])
		key: key
	}
}

fn data_table_header_cells(config DataTableConfig, layout DataTableLayout, metrics TableMetrics, colors TableColors) []Element {
	height := layout.header.height
	mut cells := []Element{cap: config.columns.len * 2 + 1}
	if config.selection == .multiple {
		check := table_check_state(config.selected_count, config.row_count)
		on := config.enabled && !config.loading && config.row_count > 0
		part := component_part_id(config.id, 'check_all')
		cells << Element{
			...button_view(part, rect(0, 0, layout.selection_width, height), BoxStyle{
				transparent: true
			}, table_checkbox(rect(0, 0, layout.selection_width, height), metrics.checkbox,
				check, on, colors))
			key:                 'check_all'
			enabled:             on
			accessibility_role:  'checkbox'
			accessibility_label: 'Select all rows'
			accessibility_value: table_check_value(check)
		}
	}
	icon_side := math.round(metrics.font_size * 0.95)
	for index, column in config.columns {
		x := layout.xs[index]
		width := layout.widths[index]
		pad := math.min(metrics.padding, width / 2)
		direction := if config.sort_column == index { config.sort_direction } else { .none }
		style := TextStyle{
			color: colors.head_text
			size:  metrics.font_size
			bold:  true
			align: column.align
		}
		key := 'head:' + table_column_key(column, index)
		if !column.sortable {
			cells << Element{
				...label('', column.title, rect(x + pad, 0, math.max(0.0, width - 2 * pad), height),
					style)
				key:                key
				accessibility_role: 'columnheader'
			}
			continue
		}
		// The sort icon takes the right end of the header; the title has the rest.
		icon_box := math.min(icon_side, math.max(0.0, width - 2 * pad))
		text_width := math.max(0.0, width - 2 * pad - icon_box - metrics.padding / 2)
		symbol := match direction {
			.ascending { 'arrow.up' }
			.descending { 'arrow.down' }
			.none { 'arrow.up.arrow.down' }
		}
		icon_color := if direction == .none {
			choice_mix(colors.head_text, colors.head, 0.45)
		} else {
			colors.text
		}
		part := component_part_id(config.id, 'head:${index}')
		cells << Element{
			...button_view(part, rect(x, 0, width, height), BoxStyle{ transparent: true }, [
				label('', column.title, rect(pad, 0, text_width, height), style),
				Element{
					...image('', 'symbol:' + symbol, rect(width - pad - icon_box, (height - icon_box) / 2,
						icon_box, icon_box))
					text_style: TextStyle{
						color: icon_color
					}
				},
			])
			key:                 key
			enabled:             config.enabled && !config.loading
			accessibility_label: column.title
			accessibility_value: match direction {
				.ascending { 'sorted ascending' }
				.descending { 'sorted descending' }
				.none { '' }
			}
		}
	}
	// Dividers go last so their handles are on top of the header buttons.
	for index, column in config.columns {
		edge := layout.xs[index] + layout.widths[index]
		dragging := config.resize_drag.column == index
		if data_table_resizable(config, index) {
			reach := data_table_handle_reach
			line := if dragging {
				rect(reach - 1, 0, 2, height)
			} else {
				rect(reach - 1, height * 0.25, 1, height * 0.5)
			}
			cells << Element{
				...draggable_view_with_cursor(component_part_id(config.id, 'resize:${index}'),
					rect(edge - reach, 0, 2 * reach, height), BoxStyle{ transparent: true },
					cursor_resize_ew, [
						view('', line, BoxStyle{
							bg: if dragging { colors.accent } else { colors.border }
						}, []Element{}),
					])
				key:                 'resize:' + table_column_key(column, index)
				accessibility_role:  'separator'
				accessibility_label: 'Resize ${column.title}'
			}
		} else if config.column_dividers && index < config.columns.len - 1 {
			cells << table_line(rect(edge - 1, 0, 1, height), colors.row_border, 'divider:${index}')
		}
	}
	return cells
}

fn data_table_footer_cells(config DataTableConfig, layout DataTableLayout, metrics TableMetrics, colors TableColors) []Element {
	rh := layout.row_height
	width := math.max(layout.content_width, layout.footer.width)
	mut cells := []Element{cap: config.footer.len}
	for index, row in config.footer {
		y := f64(index) * rh
		if y >= layout.footer.height {
			break
		}
		cells << Element{
			...view('', rect(0, y, width, rh), BoxStyle{
				transparent:  true
				border_color: colors.row_border
				border_top:   if index > 0 { 1 } else { 0 }
			}, table_cell_elements(row.cells, config.columns, layout.xs, layout.widths, rh,
				math.inf(1), TableTextStyle{
					padding: metrics.padding
					size:    metrics.font_size
					color:   colors.text
				}))
			key:                 'footer:' + table_row_key(row, index)
			accessibility_role:  'row'
			accessibility_label: table_row_label(row)
		}
	}
	if config.column_dividers {
		cells << table_dividers(layout.xs, layout.widths, math.inf(1), 0, layout.footer.height,
			colors.row_border)
	}
	return cells
}

fn data_table_body_rows(config DataTableConfig, layout DataTableLayout, metrics TableMetrics, colors TableColors) []Element {
	if config.loading || config.row_count == 0 {
		return []Element{}
	}
	rh := layout.row_height
	width := math.max(layout.content_width, layout.body.width)
	total := f64(config.row_count) * rh
	mut rows := []Element{cap: layout.rows.len() + 2}
	// The spacer gives the scroll its full height while only some rows exist.
	rows << Element{
		...view('', rect(0, total - 1, width, 1), BoxStyle{ transparent: true }, []Element{})
		key: 'spacer'
	}
	for index in layout.rows.start .. layout.rows.end {
		rows << data_table_row(config, layout, metrics, colors, config.row(index), index, width)
	}
	if config.column_dividers && layout.rows.len() > 0 {
		y := f64(layout.rows.start) * rh
		rows << Element{
			...view('', rect(0, y, width, f64(layout.rows.len()) * rh), BoxStyle{
				transparent: true
			}, table_dividers(layout.xs, layout.widths, math.inf(1), 0, f64(layout.rows.len()) * rh,
				colors.row_border))
			key: 'dividers'
		}
	}
	return rows
}

fn data_table_row(config DataTableConfig, layout DataTableLayout, metrics TableMetrics, colors TableColors, row TableRow, index int, width f64) Element {
	rh := layout.row_height
	selectable := config.selection != .none
	selected := selectable && row.selected
	hovered := config.hoverable && config.enabled && row.enabled && index == config.hovered_row
	fill := if selected && hovered {
		colors.selected_hover
	} else if selected {
		colors.selected
	} else if hovered {
		colors.hover
	} else if config.striped && index % 2 == 1 {
		colors.stripe
	} else {
		colors.surface
	}
	active := config.selection == .multiple && index == config.active_row
	enabled := config.enabled && row.enabled
	mut children := []Element{cap: row.cells.len + 1}
	if config.selection == .multiple {
		check := if row.selected { TableCheckState.checked } else { TableCheckState.unchecked }
		part := component_part_id(config.id, 'check:${index}')
		children << Element{
			...button_view(part, rect(0, 0, layout.selection_width, rh), BoxStyle{
				transparent: true
			}, table_checkbox(rect(0, 0, layout.selection_width, rh), metrics.checkbox, check,
				enabled, colors))
			key:                 'check'
			enabled:             enabled
			accessibility_role:  'checkbox'
			accessibility_label: 'Select row'
			accessibility_value: table_check_value(check)
		}
	}
	children << table_cell_elements(row.cells, config.columns, layout.xs, layout.widths, rh,
		math.inf(1), TableTextStyle{
			padding: metrics.padding
			size:    metrics.font_size
			color:   if enabled { colors.text } else { colors.dimmed_text }
		})
	box := if active {
		BoxStyle{
			bg:            fill
			border_color:  colors.accent
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}
	} else {
		BoxStyle{
			bg:            fill
			transparent:   fill == colors.surface
			border_color:  colors.row_border
			border_bottom: 1
		}
	}
	part := table_row_part(config.id, index)
	mut el := view(part, rect(0, f64(index) * rh, width, rh), box, children)
	if selectable {
		el = with_button_behavior(el)
	}
	if config.hoverable {
		el = with_hover(el)
	}
	return Element{
		...el
		key:                 'row:' + table_row_key(row, index)
		enabled:             enabled
		accessibility_role:  'row'
		accessibility_label: table_row_label(row)
		accessibility_value: if selected { 'selected' } else { '' }
	}
}

// data_table_skeleton fills the body with placeholder bars while loading, as
// GPUI Kit's table does: one bar per column, of varied lengths.
fn data_table_skeleton(columns []TableColumn, layout DataTableLayout, metrics TableMetrics, colors TableColors) []Element {
	rh := layout.row_height
	bar := math.round(rh * 0.4)
	mut out := []Element{}
	mut index := 0
	for f64(index) * rh + (rh + bar) / 2 <= layout.body.height {
		y := f64(index) * rh
		for column, x0 in layout.xs {
			x := x0 - layout.scroll_x
			width := layout.widths[column]
			if x >= layout.body.width {
				break
			}
			if x + width <= 0 {
				continue
			}
			pad := math.min(metrics.padding, width / 2)
			// A fixed pattern of lengths, so the placeholder does not jump about
			// from one build to the next.
			share := 0.45 + 0.4 * f64((index * 7 + column * 13) % 10) / 10
			length := (width - 2 * pad) * share
			// The bar sits where the column's text would.
			start := match columns[column].align {
				.left { x + pad }
				.center { x + (width - length) / 2 }
				.right { x + width - pad - length }
			}
			left := math.max(0.0, start)
			right := math.min(layout.body.width, start + length)
			if right - left < 4 {
				continue
			}
			out << view('', rect(left, y + (rh - bar) / 2, right - left, bar), BoxStyle{
				bg:     colors.skeleton
				radius: bar / 2
			}, []Element{})
		}
		out << table_line(rect(0, y + rh - 1, layout.body.width, 1), colors.row_border, 'line:${index}')
		index++
	}
	return out
}

// ── Events ──────────────────────────────────────────────────────────

pub enum DataTableEventKind {
	sort            // Sort by `column` in `direction` (none restores the data order).
	select_row      // Select only `row`, and make it the active row.
	toggle_row      // Set `row`'s selection to `checked`.
	select_all      // Select every row when `checked`, none otherwise.
	clear_selection // Escape: select nothing.
	hover_row       // The pointer is over `row`, or -1 when it left the hovered row.
	resize_start    // Keep `drag` in resize_drag until resize_end.
	resize          // `column` is now `width`; `widths` has every column.
	resize_end      // Like resize, then clear resize_drag.
}

pub struct DataTableEvent {
pub:
	kind      DataTableEventKind
	row       int = -1
	column    int = -1
	direction TableSortDirection
	checked   bool
	width     f64
	widths    []f64
	drag      TableResizeDrag
}

// data_table_event decodes anything an on_event handler receives: header clicks
// (sort), row and checkbox clicks (selection), pointer reports from rows (hover)
// and from header dividers (resizing). It returns none for events that are not
// this table's, malformed or forged ones, disabled rows, a disabled or loading
// table, and changes that change nothing.
pub fn data_table_event(config DataTableConfig, event string) ?DataTableEvent {
	if !config.enabled {
		return none
	}
	if pointer := parse_pointer_event(event) {
		return data_table_pointer_event(config, pointer)
	}
	part := component_action_part(config.id, event)?
	if part.starts_with('head:') {
		column := component_parse_index(part['head:'.len..], config.columns.len - 1)?
		if config.loading || !config.columns[column].sortable {
			return none
		}
		return DataTableEvent{
			kind:      .sort
			column:    column
			direction: if config.sort_column == column {
				config.sort_direction.next()
			} else {
				TableSortDirection.ascending
			}
		}
	}
	if config.loading || config.selection == .none || voidptr(config.row) == unsafe { nil } {
		return none
	}
	if part == 'check_all' {
		if config.selection != .multiple || config.row_count == 0 {
			return none
		}
		return DataTableEvent{
			kind:    .select_all
			checked: config.selected_count < config.row_count
		}
	}
	if part.starts_with('check:') {
		if config.selection != .multiple {
			return none
		}
		index := component_parse_index(part['check:'.len..], config.row_count - 1)?
		row := config.row(index)
		if !row.enabled {
			return none
		}
		return DataTableEvent{
			kind:    .toggle_row
			row:     index
			checked: !row.selected
		}
	}
	if part.starts_with('row:') {
		index := component_parse_index(part['row:'.len..], config.row_count - 1)?
		row := config.row(index)
		if !row.enabled
			|| (row.selected && config.selected_count == 1 && config.active_row == index) {
			return none
		}
		return DataTableEvent{
			kind: .select_row
			row:  index
		}
	}
	return none
}

fn data_table_pointer_event(config DataTableConfig, pointer PointerEvent) ?DataTableEvent {
	part := component_action_part(config.id, pointer.action)?
	match pointer.phase {
		'enter', 'leave' {
			if !config.hoverable || config.loading || !part.starts_with('row:') {
				return none
			}
			index := component_parse_index(part['row:'.len..], config.row_count - 1)?
			entered := pointer.phase == 'enter'
			if entered == (index == config.hovered_row) {
				return none
			}
			return DataTableEvent{
				kind: .hover_row
				row:  if entered { index } else { -1 }
			}
		}
		'down', 'drag', 'up' {
			if !part.starts_with('resize:') || !component_finite(pointer.x) {
				return none
			}
			column := component_parse_index(part['resize:'.len..], config.columns.len - 1)?
			if !data_table_resizable(config, column) {
				return none
			}
			widths := data_table_layout(config).widths
			if pointer.phase == 'down' {
				return DataTableEvent{
					kind:   .resize_start
					column: column
					width:  widths[column]
					widths: widths
					drag:   TableResizeDrag{
						column:      column
						start_x:     pointer.x
						start_width: widths[column]
					}
				}
			}
			drag := config.resize_drag
			if drag.column != column {
				return none
			}
			next := table_resized_widths(config.columns, widths, column, drag.start_width,
				pointer.x - drag.start_x)
			if pointer.phase == 'drag' && next[column] == widths[column] {
				return none
			}
			return DataTableEvent{
				kind:   if pointer.phase == 'up' { .resize_end } else { .resize }
				column: column
				width:  next[column]
				widths: next
				drag:   drag
			}
		}
		else {
			return none
		}
	}
}

// ── Keyboard and scrolling ──────────────────────────────────────────

// data_table_page_rows is how many whole rows the body shows, the step of Page
// Up and Page Down.
pub fn data_table_page_rows(config DataTableConfig) int {
	layout := data_table_layout(config)
	return math.max(1, int(math.floor(layout.body.height / layout.row_height)))
}

// data_table_event_from_key is for on_key_event. Up, Down, Page Up, Page Down,
// Home and End select the row they move the active row to; with multiple
// selection Space toggles the active row and Cmd+A or Ctrl+A selects every row;
// Escape clears the selection. Components cannot take keyboard focus, so call it
// while the table is what the keyboard should drive.
pub fn data_table_event_from_key(config DataTableConfig, event KeyEvent) ?DataTableEvent {
	if !config.enabled || config.loading || config.selection == .none || config.row_count == 0
		|| voidptr(config.row) == unsafe { nil } {
		return none
	}
	command := event.cmd || event.ctrl
	if config.selection == .multiple && command && !event.alt && !event.shift
		&& event.code == .a {
		if config.selected_count >= config.row_count {
			return none
		}
		return DataTableEvent{
			kind:    .select_all
			checked: true
		}
	}
	if command || event.alt || event.shift {
		return none
	}
	if event.code == .escape {
		return if config.selected_count > 0 {
			DataTableEvent{
				kind: .clear_selection
			}
		} else {
			none
		}
	}
	if event.code == .space {
		if config.selection != .multiple || config.active_row < 0
			|| config.active_row >= config.row_count {
			return none
		}
		row := config.row(config.active_row)
		if !row.enabled {
			return none
		}
		return DataTableEvent{
			kind:    .toggle_row
			row:     config.active_row
			checked: !row.selected
		}
	}
	target := table_row_after_key(config.active_row, config.row_count, data_table_page_rows(config),
		event.code)?
	return DataTableEvent{
		kind: .select_row
		row:  data_table_enabled_row_near(config, target)?
	}
}

// data_table_enabled_row_near is `target`, or when that row is disabled the
// nearest enabled one: first further on in the direction the key moved, then back
// toward the active row. None when every row in reach is disabled.
fn data_table_enabled_row_near(config DataTableConfig, target int) ?int {
	if config.row(target).enabled {
		return target
	}
	current := config.active_row
	onward := if target < current { -1 } else { 1 }
	mut index := target + onward
	for index >= 0 && index < config.row_count && index != current {
		if config.row(index).enabled {
			return index
		}
		index += onward
	}
	index = target - onward
	for index >= 0 && index < config.row_count && index != current {
		if config.row(index).enabled {
			return index
		}
		index -= onward
	}
	return none
}

// data_table_scroll_to_row is the vertical offset that brings `row` fully into
// view, or none when it already is. Pass it to scroll_to_offset with
// data_table_body_id(id) after moving the selection from the keyboard.
pub fn data_table_scroll_to_row(config DataTableConfig, row int) ?f64 {
	if row < 0 || row >= config.row_count {
		return none
	}
	layout := data_table_layout(config)
	top := f64(row) * layout.row_height
	bottom := top + layout.row_height
	if top < layout.scroll_y {
		return top
	}
	if bottom > layout.scroll_y + layout.body.height {
		return bottom - layout.body.height
	}
	return none
}
