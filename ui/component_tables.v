module ui2

import math

// Tables: GPUI Kit's Table, a styled table for a handful of rows given up front,
// and DataTable, which builds only the rows on screen and adds sorting, column
// resizing and row selection. This file holds what both share (columns, rows,
// cells, metrics, colors and column widths) and the simple table; the data table
// lives in component_tables_data.v and the pure sort, range and key helpers in
// component_tables_sort.v.

// ── Columns, rows and cells ─────────────────────────────────────────

pub struct TableColumn {
pub:
	key       string // The application's name for the column; element keys use it. Defaults to the index.
	title     string
	width     f64 // Fixed width in points; 0 makes the column flexible.
	flex      f64 = 1 // A flexible column's share of what the fixed columns leave.
	min_width f64 = 40
	max_width f64 = 1200
	align     Align
	sortable  bool // DataTable: a header click asks to sort by the column.
	resizable bool = true // DataTable: the divider after the header can be dragged.
}

// TableCell is one cell: text, or application elements in `content`.
pub struct TableCell {
pub:
	text  string
	color ?u32 // Text color; defaults to the theme's.
	bold  bool
	// content replaces the text. Frames are relative to the cell's content box:
	// the cell less table_metrics(size).padding on the left and right, as tall as
	// the row. Content is not clipped, so keep it inside that box.
	content []Element
}

pub struct TableRow {
pub:
	key      string      // Identity across rebuilds, unique among the rows shown; defaults to the index.
	cells    []TableCell // One per column; missing cells are blank.
	selected bool        // DataTable: drawn selected, with its checkbox checked.
	enabled  bool = true // DataTable: false dims the row and ignores clicks on it.
}

// table_text_row is a row of plain text cells, one per string.
pub fn table_text_row(texts []string) TableRow {
	return TableRow{
		cells: texts.map(TableCell{ text: it })
	}
}

// ── Metrics and colors ──────────────────────────────────────────────

pub struct TableMetrics {
pub:
	row_height      f64 // Header, body and footer rows.
	font_size       f64
	padding         f64 // Inside a cell, on the left and the right.
	checkbox        f64 // Side of a selection checkbox.
	checkbox_column f64 // Width of the selection column.
	radius          f64 // Corner radius of a bordered table.
	gap             f64 // Between the table and its caption.
}

// table_metrics follows GPUI Kit's table sizes: rows 30, 32 and 40 points tall
// with 6, 8 and 12 points of cell padding.
pub fn table_metrics(size ComponentSize) TableMetrics {
	base := component_metrics(size)
	return match size {
		.small {
			TableMetrics{
				row_height:      30
				font_size:       base.font_size
				padding:         6
				checkbox:        14
				checkbox_column: 32
				radius:          base.radius
				gap:             base.gap
			}
		}
		.medium {
			TableMetrics{
				row_height:      32
				font_size:       base.font_size
				padding:         8
				checkbox:        16
				checkbox_column: 40
				radius:          base.radius
				gap:             base.gap
			}
		}
		.large {
			TableMetrics{
				row_height:      40
				font_size:       base.font_size
				padding:         12
				checkbox:        18
				checkbox_column: 48
				radius:          base.radius
				gap:             base.gap
			}
		}
	}
}

// TableColors are GPUI Kit's table tokens derived from a ComponentTheme.
struct TableColors {
	surface        u32
	head           u32
	head_text      u32
	text           u32
	muted_text     u32
	dimmed_text    u32
	stripe         u32
	hover          u32
	selected       u32
	selected_hover u32
	accent         u32
	accent_text    u32
	border         u32
	row_border     u32
	skeleton       u32
}

fn table_colors(theme ComponentTheme) TableColors {
	return TableColors{
		surface:        theme.background
		head:           theme.muted
		head_text:      theme.muted_foreground
		text:           theme.foreground
		muted_text:     theme.muted_foreground
		dimmed_text:    choice_disabled_text(theme)
		stripe:         choice_mix(theme.background, theme.muted, 0.55)
		hover:          choice_mix(theme.muted, theme.border, 0.3)
		selected:       choice_mix(theme.background, theme.primary, 0.12)
		selected_hover: choice_mix(theme.background, theme.primary, 0.2)
		accent:         theme.primary
		accent_text:    theme.primary_foreground
		border:         theme.border
		row_border:     choice_mix(theme.border, theme.background, 0.4)
		skeleton:       shimmer_base_color(theme)
	}
}

// ── Column widths ───────────────────────────────────────────────────

fn table_column_bounds(column TableColumn) (f64, f64) {
	low := if component_finite(column.min_width) { math.max(0.0, column.min_width) } else { 0.0 }
	high := if component_finite(column.max_width) {
		math.max(low, column.max_width)
	} else {
		math.max(low, 1200.0)
	}
	return low, high
}

fn table_validate_columns(columns []TableColumn) ! {
	for column in columns {
		for value in [column.width, column.flex, column.min_width, column.max_width] {
			if !component_finite(value) || value < 0 {
				return error('table column widths must be finite and non-negative')
			}
		}
	}
}

// table_column_widths resolves column widths for `available` points. A column with
// a width keeps it; the others share what is left by flex. Every column stays
// between its min_width and max_width, so the total can be more than available —
// a data table then scrolls sideways, and a simple table cuts the last columns off.
pub fn table_column_widths(columns []TableColumn, available f64) []f64 {
	mut widths := []f64{len: columns.len}
	mut open := []int{}
	mut remaining := if component_finite(available) { math.max(0.0, available) } else { 0.0 }
	for index, column in columns {
		low, high := table_column_bounds(column)
		if component_finite(column.width) && column.width > 0 {
			widths[index] = math.min(high, math.max(low, column.width))
			remaining -= widths[index]
		} else {
			open << index
		}
	}
	remaining = math.max(0.0, remaining)
	// Hand out shares; a column its bounds hold back takes its bound and leaves the
	// rest to be shared again among the others, until no share breaks a bound.
	for open.len > 0 {
		mut weight := 0.0
		for index in open {
			weight += table_flex(columns[index])
		}
		mut still_open := []int{}
		mut settled := 0.0
		for index in open {
			share := remaining * table_flex(columns[index]) / weight
			low, high := table_column_bounds(columns[index])
			if share < low || share > high {
				widths[index] = if share < low { low } else { high }
				settled += widths[index]
			} else {
				still_open << index
			}
		}
		if still_open.len == open.len {
			for index in open {
				widths[index] = remaining * table_flex(columns[index]) / weight
			}
			break
		}
		remaining = math.max(0.0, remaining - settled)
		open = still_open.clone()
	}
	return widths
}

// table_flex is a column's share weight. Flexible columns with no flex at all
// share equally rather than disappearing.
fn table_flex(column TableColumn) f64 {
	return if component_finite(column.flex) && column.flex > 0 { column.flex } else { 1.0 }
}

fn table_offsets(widths []f64, start f64) []f64 {
	mut xs := []f64{cap: widths.len}
	mut x := start
	for width in widths {
		xs << x
		x += width
	}
	return xs
}

// ── Shared drawing ──────────────────────────────────────────────────

struct TableTextStyle {
	padding f64
	size    f64
	color   u32
	bold    bool
}

// table_cell_elements lays out one row's cells at the column offsets. Cells that
// start at or past `limit` are left out, and one crossing it is cut short there,
// so a table that does not scroll never draws past its frame.
fn table_cell_elements(cells []TableCell, columns []TableColumn, xs []f64, widths []f64, height f64, limit f64, style TableTextStyle) []Element {
	mut out := []Element{cap: columns.len}
	for index, column in columns {
		if index >= cells.len {
			break
		}
		x := xs[index]
		if x >= limit {
			break
		}
		width := math.min(widths[index], limit - x)
		pad := math.min(style.padding, width / 2)
		if width - 2 * pad < 1 {
			continue
		}
		cell := cells[index]
		box := rect(x + pad, 0, math.max(0.0, width - 2 * pad), height)
		if cell.content.len > 0 {
			out << Element{
				...view('', box, BoxStyle{ transparent: true }, cell.content)
				key: 'cell:${index}'
			}
			continue
		}
		if cell.text.len == 0 {
			continue
		}
		out << Element{
			...label('', cell.text, box, TextStyle{
				color: cell.color or { style.color }
				size:  style.size
				bold:  cell.bold || style.bold
				align: column.align
			})
			key: 'cell:${index}'
		}
	}
	return out
}

// table_fill paints a section of a bordered table. Only `corners` are rounded,
// so a header fill follows the table's top corners and a footer its bottom ones.
fn table_fill(frame Rect, radius f64, color u32, corners ChoiceCorners) []Element {
	return choice_shape(frame, radius, color, corners, true)
}

fn table_line(frame Rect, color u32, key string) Element {
	return Element{
		...view('', frame, BoxStyle{ bg: color }, []Element{})
		key: key
	}
}

// table_empty_elements is the icon and message shown in place of rows.
fn table_empty_elements(frame Rect, message string, metrics TableMetrics, colors TableColors) []Element {
	icon_side := math.min(math.round(metrics.font_size * 2.2), frame.height / 2)
	gap := math.min(metrics.gap, frame.height / 8)
	text_height := math.max(0.0, math.min(font_line_height(metrics.font_size) + 4, frame.height -
		icon_side - gap))
	top := frame.y + (frame.height - icon_side - gap - text_height) / 2
	color := choice_mix(colors.muted_text, colors.surface, 0.25)
	return [
		Element{
			...image('', 'symbol:tray', rect(frame.x + (frame.width - icon_side) / 2, top,
				icon_side, icon_side))
			key:        'empty:icon'
			text_style: TextStyle{
				color: color
			}
		},
		Element{
			...label('', message, rect(frame.x, top + icon_side + gap, frame.width, text_height),
				TextStyle{
					color: colors.muted_text
					size:  metrics.font_size
					align: .center
				})
			key:                'empty:text'
			accessibility_role: 'status'
		},
	]
}

// table_checkbox draws a selection checkbox centered in `frame`: a rounded box,
// filled with the accent and marked with a check, or with a dash when mixed.
fn table_checkbox(frame Rect, side f64, check TableCheckState, enabled bool, colors TableColors) []Element {
	box_side := math.min(side, math.min(frame.width, frame.height))
	box := rect(frame.x + (frame.width - box_side) / 2, frame.y + (frame.height - box_side) / 2,
		box_side, box_side)
	radius := math.round(box_side / 4)
	on := check != .unchecked
	mut fill := if on { colors.accent } else { colors.surface }
	mut ring := if on { colors.accent } else { colors.border }
	if !enabled {
		fill = choice_mix(fill, colors.surface, 0.5)
		ring = choice_mix(ring, colors.surface, 0.5)
	}
	mut marks := []Element{}
	if on {
		inset := math.round(box_side * 0.12)
		marks << Element{
			...image('', if check == .mixed { 'symbol:minus' } else { 'symbol:checkmark' },
				rect(inset, inset, box_side - 2 * inset, box_side - 2 * inset))
			text_style: TextStyle{
				color: colors.accent_text
			}
		}
	}
	return [view('', box, component_box(fill, ring, radius), marks)]
}

fn table_check_value(check TableCheckState) string {
	return match check {
		.unchecked { 'unchecked' }
		.checked { 'checked' }
		.mixed { 'mixed' }
	}
}

// table_part_index decodes `<prefix><index>` from an action a table emitted.
fn table_part_index(id string, action string, prefix string, count int) ?int {
	part := component_action_part(id, action)?
	if !part.starts_with(prefix) {
		return none
	}
	return component_parse_index(part[prefix.len..], count - 1)
}

fn table_row_part(id string, index int) string {
	return component_part_id(id, 'row:${index}')
}

// ── Table ───────────────────────────────────────────────────────────

// TableConfig describes GPUI Kit's Table: a header, the rows, an optional footer
// and a caption below. Size the frame with table_height. Rows that do not fit are
// left out, and columns past the right edge are cut off.
pub struct TableConfig {
pub:
	id              string // Required when hoverable or clickable_rows.
	frame           Rect
	columns         []TableColumn
	rows            []TableRow
	footer          []TableRow // Rows under the body, such as totals.
	caption         string     // Muted text centered below the table.
	striped         bool
	bordered        bool = true // A rounded border around the table.
	column_dividers bool
	// hoverable rows report the pointer entering and leaving them, and the row
	// at hovered_row is highlighted. Decode the events with table_event.
	hoverable   bool
	hovered_row int = -1
	// clickable_rows makes each row a button; table_event decodes its clicks.
	clickable_rows      bool
	empty_text          string = 'No data'
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

struct TableGeometry {
	border     f64
	corner     f64 // The rounded corner's reach, kept clear of square fills.
	inner      Rect
	box_height f64
	header     f64
	body_y     f64
	rows       int // Rows that fit.
	empty      f64 // Height of the empty message, when there are no rows.
	footer_y   f64
	footers    int
	caption    Rect
	widths     []f64
	xs         []f64
}

fn table_border(bordered bool) f64 {
	return if bordered { 1.0 } else { 0.0 }
}

fn table_caption_height(caption string, metrics TableMetrics) f64 {
	return if caption.len > 0 { metrics.gap + metrics.row_height } else { 0.0 }
}

fn table_empty_height(metrics TableMetrics) f64 {
	return metrics.row_height * 3
}

// table_height is the frame height a table needs for its header, every row, the
// footer and the caption.
pub fn table_height(config TableConfig) f64 {
	metrics := table_metrics(config.size)
	body := if config.rows.len > 0 {
		f64(config.rows.len) * metrics.row_height
	} else {
		table_empty_height(metrics)
	}
	return 2 * table_border(config.bordered) + metrics.row_height + body +
		f64(config.footer.len) * metrics.row_height + table_caption_height(config.caption, metrics)
}

fn table_geometry(config TableConfig) TableGeometry {
	metrics := table_metrics(config.size)
	rh := metrics.row_height
	border := table_border(config.bordered)
	width := config.frame.width
	caption_height := math.min(table_caption_height(config.caption, metrics), config.frame.height)
	room := math.max(0.0, config.frame.height - caption_height - 2 * border)
	header := math.min(rh, room)
	mut left := room - header
	footers := math.min(config.footer.len, int(math.floor(left / rh)))
	left -= f64(footers) * rh
	rows := math.min(config.rows.len, int(math.floor(left / rh)))
	empty := if config.rows.len == 0 { math.min(table_empty_height(metrics), left) } else { 0.0 }
	body := if config.rows.len > 0 { f64(rows) * rh } else { empty }
	box_height := 2 * border + header + body + f64(footers) * rh
	inner := rect(border, border, math.max(0.0, width - 2 * border), box_height - 2 * border)
	widths := table_column_widths(config.columns, inner.width)
	caption_y := math.min(box_height + metrics.gap, config.frame.height)
	return TableGeometry{
		border:     border
		corner:     if config.bordered { math.max(0.0, metrics.radius - border) } else { 0.0 }
		inner:      inner
		box_height: box_height
		header:     header
		body_y:     border + header
		rows:       rows
		empty:      empty
		footer_y:   border + header + body
		footers:    footers
		caption:    rect(0, caption_y, width, math.max(0.0, math.min(rh, config.frame.height -
			caption_y)))
		widths:     widths
		xs:         table_offsets(widths, 0)
	}
}

// table builds the simple table. It owns no state: hover and clicks come back as
// events (table_event) and the application rebuilds with hovered_row.
pub fn table(config TableConfig) !Element {
	component_validate_frame(config.frame)!
	if config.hoverable || config.clickable_rows {
		component_validate_id(config.id)!
	}
	table_validate_columns(config.columns)!
	metrics := table_metrics(config.size)
	colors := table_colors(config.theme)
	geo := table_geometry(config)
	rh := metrics.row_height
	inner := geo.inner
	limit := inner.width
	mut box_children := []Element{}
	// Header.
	if geo.header > 0 {
		mut head := table_fill(rect(0, 0, inner.width, geo.header), geo.corner, colors.head,
			.start)
		head << table_line(rect(0, geo.header - 1, inner.width, 1), colors.row_border, 'line')
		for index, column in config.columns {
			x := geo.xs[index]
			if x >= limit {
				break
			}
			width := math.min(geo.widths[index], limit - x)
			pad := math.min(metrics.padding, width / 2)
			head << Element{
				...label('', column.title, rect(x + pad, 0, math.max(0.0, width - 2 * pad),
					geo.header), TextStyle{
					color: colors.head_text
					size:  metrics.font_size
					bold:  true
					align: column.align
				})
				key:                'head:' + table_column_key(column, index)
				accessibility_role: 'columnheader'
			}
		}
		if config.column_dividers {
			head << table_dividers(geo.xs, geo.widths, limit, 0, geo.header, colors.row_border)
		}
		box_children << Element{
			...view('', rect(inner.x, inner.y, inner.width, geo.header), BoxStyle{
				transparent: true
			}, head)
			key: 'header'
		}
	}
	// Body.
	for index in 0 .. geo.rows {
		row := config.rows[index]
		y := geo.body_y + f64(index) * rh
		last := index == geo.rows - 1 && geo.footers == 0
		box_children << table_simple_row(config, geo, colors, metrics, row, index, y, last)
	}
	if config.rows.len == 0 && geo.empty > 0 {
		box_children << Element{
			...view('', rect(inner.x, geo.body_y, inner.width, geo.empty), BoxStyle{
				transparent: true
			}, table_empty_elements(rect(0, 0, inner.width, geo.empty), config.empty_text,
				metrics, colors))
			key: 'empty'
		}
	}
	if config.column_dividers && geo.rows > 0 {
		box_children << Element{
			...view('', rect(inner.x, geo.body_y, inner.width, f64(geo.rows) * rh), BoxStyle{
				transparent: true
			}, table_dividers(geo.xs, geo.widths, limit, 0, f64(geo.rows) * rh, colors.row_border))
			key: 'dividers'
		}
	}
	// Footer.
	if geo.footers > 0 {
		height := f64(geo.footers) * rh
		mut foot := table_fill(rect(0, 0, inner.width, height), geo.corner, colors.head, .end)
		for index in 0 .. geo.footers {
			foot << Element{
				...view('', rect(0, f64(index) * rh, inner.width, rh), BoxStyle{
					transparent:  true
					border_color: colors.row_border
					border_top:   1
				}, table_cell_elements(config.footer[index].cells, config.columns, geo.xs,
					geo.widths, rh, limit, TableTextStyle{
						padding: metrics.padding
						size:    metrics.font_size
						color:   colors.text
					}))
				key:                'footer:' + table_row_key(config.footer[index], index)
				accessibility_role: 'row'
			}
		}
		if config.column_dividers {
			foot << table_dividers(geo.xs, geo.widths, limit, 0, height, colors.row_border)
		}
		box_children << Element{
			...view('', rect(inner.x, geo.footer_y, inner.width, height), BoxStyle{
				transparent: true
			}, foot)
			key: 'footer'
		}
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
			...view('', rect(0, 0, config.frame.width, geo.box_height), box_style, box_children)
			key: 'box'
		},
	]
	if config.caption.len > 0 && geo.caption.height > 0 {
		children << Element{
			...label('', config.caption, geo.caption, TextStyle{
				color: colors.muted_text
				size:  metrics.font_size
				align: .center
			})
			key: 'caption'
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'table'
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			config.caption
		}
	})
}

fn table_column_key(column TableColumn, index int) string {
	return if column.key.len > 0 { column.key } else { index.str() }
}

fn table_row_key(row TableRow, index int) string {
	return if row.key.len > 0 { row.key } else { index.str() }
}

// table_dividers are the vertical lines between columns, `height` tall from `y`.
fn table_dividers(xs []f64, widths []f64, limit f64, y f64, height f64, color u32) []Element {
	mut lines := []Element{}
	for index in 0 .. xs.len - 1 {
		x := xs[index] + widths[index] - 1
		if x >= limit - 1 {
			break
		}
		lines << table_line(rect(math.max(0.0, x), y, 1, height), color, 'divider:${index}')
	}
	return lines
}

fn table_simple_row(config TableConfig, geo TableGeometry, colors TableColors, metrics TableMetrics, row TableRow, index int, y f64, last bool) Element {
	rh := metrics.row_height
	hovered := config.hoverable && index == config.hovered_row
	fill := if hovered {
		colors.hover
	} else if config.striped && index % 2 == 1 {
		colors.stripe
	} else {
		colors.surface
	}
	painted := fill != colors.surface
	mut children := []Element{}
	// The last row of a bordered table meets its rounded corners, which a square
	// fill would poke past on renderers that do not clip to them.
	if painted && last && geo.corner > 0 {
		children << table_fill(rect(0, 0, geo.inner.width, rh), geo.corner, fill, .end)
	}
	children << table_cell_elements(row.cells, config.columns, geo.xs, geo.widths, rh,
		geo.inner.width, TableTextStyle{
			padding: metrics.padding
			size:    metrics.font_size
			color:   colors.text
		})
	part := if config.hoverable || config.clickable_rows {
		table_row_part(config.id, index)
	} else {
		''
	}
	box := BoxStyle{
		bg:           fill
		transparent:  !painted || (last && geo.corner > 0)
		border_color: colors.row_border
		border_top:   if index > 0 { 1 } else { 0 }
	}
	mut el := view(part, rect(geo.inner.x, y, geo.inner.width, rh), box, children)
	if config.clickable_rows {
		el = with_button_behavior(el)
	}
	if config.hoverable {
		el = with_hover(el)
	}
	return Element{
		...el
		key:                 'row:' + table_row_key(row, index)
		accessibility_role:  'row'
		accessibility_label: table_row_label(row)
	}
}

// table_row_label reads a row out as its cell texts, for assistive technology.
fn table_row_label(row TableRow) string {
	mut parts := []string{cap: row.cells.len}
	for cell in row.cells {
		if cell.text.len > 0 {
			parts << cell.text
		}
	}
	return parts.join(', ')
}

pub enum TableEventKind {
	hover_row // row is the row under the pointer, or -1 when it left the hovered row.
	click_row
}

pub struct TableEvent {
pub:
	kind TableEventKind
	row  int = -1
}

// table_event decodes what a table emitted: hover reports (with hoverable) and
// row clicks (with clickable_rows). It ignores events for other elements, rows
// the table does not show, and hover reports that change nothing.
pub fn table_event(config TableConfig, event string) ?TableEvent {
	shown := table_geometry(config).rows
	if pointer := parse_pointer_event(event) {
		if !config.hoverable || pointer.phase !in ['enter', 'leave'] {
			return none
		}
		index := table_part_index(config.id, pointer.action, 'row:', shown)?
		if pointer.phase == 'enter' {
			return if index == config.hovered_row {
				none
			} else {
				TableEvent{
					kind: .hover_row
					row:  index
				}
			}
		}
		return if index == config.hovered_row {
			TableEvent{
				kind: .hover_row
				row:  -1
			}
		} else {
			none
		}
	}
	if !config.clickable_rows {
		return none
	}
	index := table_part_index(config.id, event, 'row:', shown)?
	return TableEvent{
		kind: .click_row
		row:  index
	}
}
