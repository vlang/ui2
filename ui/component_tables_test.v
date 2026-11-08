module ui2

import math

// ── Helpers ─────────────────────────────────────────────────────────

fn tables_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := tables_find(child, id) {
			return found
		}
	}
	return none
}

fn tables_find_key(el Element, key string) ?Element {
	if el.key == key {
		return el
	}
	for child in el.children {
		if found := tables_find_key(child, key) {
			return found
		}
	}
	return none
}

fn tables_labels(el Element) []string {
	mut found := []string{}
	if el.kind == .label {
		found << el.text
	}
	for child in el.children {
		found << tables_labels(child)
	}
	return found
}

fn tables_count(el Element, kind Kind) int {
	mut count := if el.kind == kind { 1 } else { 0 }
	for child in el.children {
		count += tables_count(child, kind)
	}
	return count
}

fn tables_assert_inside(el Element) {
	component_validate_frame(el.frame) or { panic(err) }
	for child in el.children {
		assert child.frame.x >= -1e-9 && child.frame.y >= -1e-9
		assert child.frame.x + child.frame.width <= el.frame.width + 1e-9
		assert child.frame.y + child.frame.height <= el.frame.height + 1e-9
		tables_assert_inside(child)
	}
}

fn tables_columns() []TableColumn {
	return [
		TableColumn{
			key:   'invoice'
			title: 'Invoice'
			width: 100
		},
		TableColumn{
			key:   'status'
			title: 'Status'
		},
		TableColumn{
			key:   'amount'
			title: 'Amount'
			width: 120
			align: .right
		},
	]
}

fn tables_rows(count int) []TableRow {
	mut rows := []TableRow{}
	for i in 0 .. count {
		rows << TableRow{
			key:   'inv-${i}'
			cells: [TableCell{
				text: 'INV${i}'
			}, TableCell{
				text: 'Paid'
			}, TableCell{
				text: '$${i}00.00'
			}]
		}
	}
	return rows
}

@[heap]
struct TablesSource {
mut:
	count    int
	selected map[int]bool
	disabled map[int]bool
	calls    []int
}

fn tables_source(count int) &TablesSource {
	return &TablesSource{
		count: count
	}
}

fn (source &TablesSource) row_fn() TableRowFn {
	return fn [source] (index int) TableRow {
		mut s := unsafe { source }
		s.calls << index
		return TableRow{
			key:      'r${index}'
			cells:    [TableCell{
				text: 'Row ${index}'
			}, TableCell{
				text: 'Name ${index}'
			}, TableCell{
				text: '${index * 3}'
			}]
			selected: index in source.selected
			enabled:  index !in source.disabled
		}
	}
}

fn tables_data_columns() []TableColumn {
	return [
		TableColumn{
			key:       'id'
			title:     'ID'
			width:     80
			sortable:  true
			min_width: 50
		},
		TableColumn{
			key:      'name'
			title:    'Name'
			width:    200
			sortable: true
		},
		TableColumn{
			key:       'score'
			title:     'Score'
			width:     120
			align:     .right
			resizable: false
		},
	]
}

fn tables_data_config(source &TablesSource) DataTableConfig {
	return DataTableConfig{
		id:             'people'
		frame:          rect(0, 0, 400, 300)
		columns:        tables_data_columns()
		row_count:      source.count
		row:            source.row_fn()
		selection:      .multiple
		selected_count: source.selected.len
	}
}

// ── Column widths ───────────────────────────────────────────────────

fn test_table_column_widths_share_the_rest_by_flex() {
	columns := [
		TableColumn{
			width: 100
		},
		TableColumn{
			flex: 1
		},
		TableColumn{
			flex: 3
		},
	]
	assert table_column_widths(columns, 500) == [100.0, 100, 300]
	// Fixed widths are held between the bounds.
	bounded := [TableColumn{
		width:     10
		min_width: 30
	}, TableColumn{
		width:     900
		max_width: 200
	}]
	assert table_column_widths(bounded, 1000) == [30.0, 200]
}

fn test_table_column_widths_respect_min_and_max_while_sharing() {
	columns := [
		TableColumn{
			min_width: 150
		},
		TableColumn{},
		TableColumn{
			max_width: 60
		},
	]
	widths := table_column_widths(columns, 300)
	// The first column's share (100) is below its minimum, the last one's above
	// its maximum; the middle one takes what they leave.
	assert widths[0] == 150
	assert widths[2] == 60
	assert widths[1] == 90
	// Too little room: every flexible column keeps its minimum, so the total is
	// wider than the space.
	narrow := table_column_widths([TableColumn{}, TableColumn{}], 50)
	assert narrow == [40.0, 40]
	// Zero flex shares equally rather than vanishing; nothing available is 0.
	assert table_column_widths([TableColumn{
		flex:      0
		min_width: 0
	}, TableColumn{
		flex:      0
		min_width: 0
	}], 100) == [50.0, 50]
	assert table_column_widths([TableColumn{
		min_width: 0
	}], math.nan()) == [0.0]
	assert table_column_widths([]TableColumn{}, 100).len == 0
}

// ── Sorting ─────────────────────────────────────────────────────────

fn test_table_compare_text_is_natural_and_ignores_case() {
	assert table_compare_text('Item 9', 'Item 10') < 0
	assert table_compare_text('item 10', 'Item 9') > 0
	assert table_compare_text('abc', 'ABC') == 0
	assert table_compare_text('a', 'b') < 0
	assert table_compare_text('a', 'a1') < 0
	assert table_compare_text('x007', 'x7') == 0
	assert table_compare_text('x08', 'x7') > 0
	assert table_compare_text('', 'a') < 0
	assert table_compare_text('INV-100', 'INV-99') > 0
}

fn test_table_sort_order_text_is_stable_both_ways() {
	values := ['b', 'a', 'B', 'c', 'A']
	assert table_sort_order_text(values, .ascending) == [1, 4, 0, 2, 3]
	// Descending reverses the groups but keeps equal values in their order.
	assert table_sort_order_text(values, .descending) == [3, 0, 2, 1, 4]
	assert table_sort_order_text(values, .none) == [0, 1, 2, 3, 4]
	assert table_sort_order_text([]string{}, .ascending).len == 0
	assert table_sort_order_text(['row 10', 'row 2', 'row 1'], .ascending) == [2, 1, 0]
}

fn test_table_sort_order_numbers_puts_nan_last() {
	values := [3.0, math.nan(), 1, 3, -2, math.nan()]
	assert table_sort_order_numbers(values, .ascending) == [4, 2, 0, 3, 1, 5]
	assert table_sort_order_numbers(values, .descending) == [0, 3, 2, 4, 1, 5]
	assert table_sort_order_numbers(values, .none) == [0, 1, 2, 3, 4, 5]
	// A larger input exercises every merge width.
	mut many := []f64{}
	for i in 0 .. 1000 {
		many << f64((i * 7919) % 101)
	}
	order := table_sort_order_numbers(many, .ascending)
	for i in 1 .. order.len {
		a := many[order[i - 1]]
		b := many[order[i]]
		assert a < b || (a == b && order[i - 1] < order[i])
	}
}

fn test_table_sort_direction_cycles() {
	assert TableSortDirection.none.next() == .ascending
	assert TableSortDirection.ascending.next() == .descending
	assert TableSortDirection.descending.next() == .none
}

// ── Range, keys, check state, resizing ──────────────────────────────

fn test_table_visible_rows_follow_the_offset() {
	assert table_visible_rows(100, 32, 320, 0, 0) == TableRowRange{0, 10}
	assert table_visible_rows(100, 32, 320, 16, 0) == TableRowRange{0, 11}
	assert table_visible_rows(100, 32, 320, 3200, 2) == TableRowRange{98, 100}
	assert table_visible_rows(5000, 32, 320, 32000, 4) == TableRowRange{996, 1014}
	r := table_visible_rows(5000, 32, 320, 32000, 4)
	assert r.len() == 18 && r.contains(1000) && !r.contains(1014)
	assert table_visible_rows(0, 32, 320, 0, 4).len() == 0
	assert table_visible_rows(10, 0, 320, 0, 4).len() == 0
	assert table_visible_rows(10, 32, -1, 0, 4).len() == 0
	assert table_visible_rows(10, 32, 320, math.nan(), -3) == TableRowRange{0, 10}
	assert table_visible_rows(10, 32, 320, -50, 0) == TableRowRange{0, 10}
}

fn test_table_row_after_key_moves_and_stops_at_the_ends() {
	assert table_row_after_key(5, 100, 10, .up)? == 4
	assert table_row_after_key(5, 100, 10, .down)? == 6
	assert table_row_after_key(5, 100, 10, .page_up)? == 0
	assert table_row_after_key(50, 100, 10, .page_down)? == 60
	assert table_row_after_key(95, 100, 10, .page_down)? == 99
	assert table_row_after_key(5, 100, 10, .home)? == 0
	assert table_row_after_key(5, 100, 10, .end)? == 99
	assert table_row_after_key(0, 100, 10, .up) == none
	assert table_row_after_key(99, 100, 10, .down) == none
	assert table_row_after_key(0, 100, 10, .home) == none
	assert table_row_after_key(5, 100, 10, .a) == none
	assert table_row_after_key(-1, 100, 10, .down)? == 0
	assert table_row_after_key(-1, 100, 10, .up)? == 0
	assert table_row_after_key(-1, 100, 10, .end)? == 99
	assert table_row_after_key(500, 100, 10, .home)? == 0
	assert table_row_after_key(3, 0, 10, .down) == none
	assert table_row_after_key(5, 100, 0, .page_down)? == 6
}

fn test_table_check_state() {
	assert table_check_state(0, 10) == .unchecked
	assert table_check_state(3, 10) == .mixed
	assert table_check_state(10, 10) == .checked
	assert table_check_state(0, 0) == .unchecked
}

fn test_table_resize_width_holds_the_bounds() {
	column := TableColumn{
		min_width: 50
		max_width: 300
	}
	assert table_resize_width(column, 100, 40) == 140
	assert table_resize_width(column, 100, -80) == 50
	assert table_resize_width(column, 100, 500) == 300
	assert table_resize_width(column, 100, math.nan()) == 100
	assert table_resize_width(column, math.inf(1), 10) == 60
	columns := [column, column]
	assert table_resized_widths(columns, [100.0, 120], 1, 120, 30) == [100.0, 150]
	assert table_resized_widths(columns, [100.0, 120], 5, 120, 30) == [100.0, 120]
}

// ── Table ───────────────────────────────────────────────────────────

fn test_table_builds_header_rows_footer_and_caption() {
	config := TableConfig{
		id:      'invoices'
		frame:   rect(10, 20, 500, 400)
		columns: tables_columns()
		rows:    tables_rows(3)
		footer:  [table_text_row(['Total', '', '$300.00'])]
		caption: 'Recent invoices'
	}
	el := table(config)!
	tables_assert_inside(el)
	assert el.accessibility_role == 'table'
	assert el.accessibility_label == 'Recent invoices'
	texts := tables_labels(el)
	assert texts[..3] == ['Invoice', 'Status', 'Amount']
	assert 'INV2' in texts && '$200.00' in texts && 'Total' in texts
	assert texts.last() == 'Recent invoices'
	box := tables_find_key(el, 'box')?
	metrics := table_metrics(.medium)
	// Border, header, three rows and the footer.
	assert box.frame.height == 2 + metrics.row_height * 5
	assert table_height(config) == box.frame.height + metrics.gap + metrics.row_height
	row := tables_find_key(el, 'row:inv-1')?
	assert row.accessibility_role == 'row'
	assert row.accessibility_label == 'INV1, Paid, $100.00'
	assert row.box.border_top == 1
	assert tables_find_key(el, 'row:inv-0')?.box.border_top == 0
	// Fixed columns keep their widths and the flexible one takes the rest.
	amount := tables_find_key(row, 'cell:2')?
	assert amount.text_style.align == .right
	assert amount.frame.x == 498 - 120 + metrics.padding
	// Without hover or clicks, rows are plain views with no ids.
	assert row.id == '' && !row.hoverable && !row.button_behavior
}

fn test_table_fits_its_frame_and_cuts_overflow() {
	config := TableConfig{
		frame:   rect(0, 0, 150, 100)
		columns: tables_columns()
		rows:    tables_rows(10)
	}
	el := table(config)!
	tables_assert_inside(el)
	// 100 points hold the border, the header and two rows.
	assert tables_find_key(el, 'row:inv-1') != none
	assert tables_find_key(el, 'row:inv-2') == none
	// The 150-point frame cuts the third column off and the second one short.
	row := tables_find_key(el, 'row:inv-0')?
	assert tables_find_key(row, 'cell:2') == none
	status := tables_find_key(row, 'cell:1')?
	assert status.frame.x + status.frame.width <= 148
}

fn test_table_stripes_hover_and_empty_state() {
	config := TableConfig{
		id:          'list'
		frame:       rect(0, 0, 400, 300)
		columns:     tables_columns()
		rows:        tables_rows(4)
		striped:     true
		hoverable:   true
		hovered_row: 2
	}
	el := table(config)!
	colors := table_colors(config.theme)
	assert tables_find_key(el, 'row:inv-0')?.box.transparent
	assert tables_find_key(el, 'row:inv-1')?.box.bg == colors.stripe
	hovered := tables_find_key(el, 'row:inv-2')?
	assert hovered.box.bg == colors.hover && hovered.hoverable
	assert hovered.id == component_part_id('list', 'row:2')
	// The last row meets the rounded corners, so its fill is a rounded shape.
	last := tables_find_key(el, 'row:inv-3')?
	assert last.box.transparent
	assert last.children[0].box.bg == colors.stripe && last.children[0].box.radius > 0
	empty := table(TableConfig{
		frame:      rect(0, 0, 400, 300)
		columns:    tables_columns()
		empty_text: 'No invoices'
	})!
	assert 'No invoices' in tables_labels(empty)
	icon := tables_find_key(empty, 'empty:icon')?
	assert icon.image_path == 'symbol:tray' && symbol_known('tray')
	assert table_height(TableConfig{
		columns: tables_columns()
	}) == 2 + table_metrics(.medium).row_height * 4
}

fn test_table_validates_its_config() {
	if _ := table(TableConfig{
		frame:     rect(0, 0, 100, 100)
		hoverable: true
	}) {
		assert false
	}
	if _ := table(TableConfig{
		frame:   rect(0, 0, 100, 100)
		columns: [TableColumn{
			width: math.nan()
		}]
	}) {
		assert false
	}
	if _ := table(TableConfig{
		frame: rect(0, 0, -1, 100)
	}) {
		assert false
	}
}

fn test_table_event_decodes_hover_and_clicks() {
	config := TableConfig{
		id:             'list'
		frame:          rect(0, 0, 400, 300)
		columns:        tables_columns()
		rows:           tables_rows(4)
		hoverable:      true
		clickable_rows: true
		hovered_row:    1
	}
	row2 := component_part_id('list', 'row:2')
	row1 := component_part_id('list', 'row:1')
	assert table_event(config, 'pointer:enter:${row2}:10:20')? == TableEvent{
		kind: .hover_row
		row:  2
	}
	assert table_event(config, 'pointer:enter:${row1}:10:20') == none
	assert table_event(config, 'pointer:leave:${row1}:10:20')? == TableEvent{
		kind: .hover_row
		row:  -1
	}
	assert table_event(config, 'pointer:leave:${row2}:10:20') == none
	assert table_event(config, row2)? == TableEvent{
		kind: .click_row
		row:  2
	}
	assert table_event(config, component_part_id('list', 'row:4')) == none
	assert table_event(config, component_part_id('list', 'row:02')) == none
	assert table_event(config, component_part_id('other', 'row:2')) == none
	assert table_event(TableConfig{
		...config
		clickable_rows: false
	}, row2) == none
}

// ── DataTable layout and build ──────────────────────────────────────

fn test_data_table_layout_places_the_parts() {
	source := tables_source(5000)
	config := DataTableConfig{
		...tables_data_config(source)
		footer:  [table_text_row(['', 'Total', '15'])]
		caption: '5000 people'
	}
	layout := data_table_layout(config)
	metrics := table_metrics(.medium)
	assert layout.box == rect(0, 0, 400, 300 - metrics.gap - metrics.row_height)
	assert layout.header == rect(1, 1, 398, metrics.row_height)
	assert layout.footer.height == metrics.row_height
	assert layout.footer.y + layout.footer.height == layout.box.height - 1
	assert layout.body.y == 1 + metrics.row_height
	assert layout.body.y + layout.body.height == layout.footer.y
	assert layout.selection_width == metrics.checkbox_column
	assert layout.xs == [40.0, 120, 320]
	assert layout.content_width == 440
	assert layout.caption.y == layout.box.height + metrics.gap
	// Without a footer the body stops short of the rounded bottom corners.
	plain := data_table_layout(tables_data_config(source))
	assert plain.body.y + plain.body.height == plain.box.height - 1 - plain.corner
	assert plain.corner == metrics.radius - 1
	// Offsets are held to the scroll range.
	far := data_table_layout(DataTableConfig{
		...config
		scroll_x: 1000
		scroll_y: 1e9
	})
	assert far.scroll_x == 440 - 398
	assert far.scroll_y == 5000 * metrics.row_height + 16 - far.body.height
	assert data_table_layout(DataTableConfig{
		...config
		scroll_x: -5
		scroll_y: math.nan()
	}).scroll_y == 0
}

fn test_data_table_builds_only_the_rows_in_view() {
	mut source := tables_source(5000)
	rh := table_metrics(.medium).row_height
	config := DataTableConfig{
		...tables_data_config(source)
		scroll_y: 1000 * rh
		overscan: 2
	}
	el := data_table(config)!
	body := tables_find(el, data_table_body_id('people'))?
	assert body.kind == .scroll && body.scroll_mode == .both
	layout := data_table_layout(config)
	assert layout.rows.start == 998
	rows := body.children.filter(it.key.starts_with('row:'))
	assert rows.len == layout.rows.len()
	assert rows[0].key == 'row:r998'
	assert rows[0].frame.y == 998 * rh
	assert rows[0].id == component_part_id('people', 'row:998')
	// The callback ran for those rows only.
	assert source.calls.len == layout.rows.len()
	assert source.calls[0] == 998
	// The spacer keeps the full scroll height.
	spacer := tables_find_key(body, 'spacer')?
	assert spacer.frame.y + spacer.frame.height == 5000 * rh
	// Rows are as wide as the columns, which here overflow the body.
	assert rows[0].frame.width == 440
	assert scroll_content_width(body.children) == 440
}

fn test_data_table_header_follows_the_horizontal_offset() {
	source := tables_source(10)
	config := DataTableConfig{
		...tables_data_config(source)
		scroll_x: 30
	}
	el := data_table(config)!
	layout := data_table_layout(config)
	strip := tables_find_key(el, 'header')?
	assert strip.kind == .scroll && strip.id == '' && strip.scroll_mode == .horizontal_only
	// The strip starts below the rounded corner, and nothing in it reaches past
	// its right edge, so it clips without a range of its own.
	assert strip.frame.y == layout.header.y + layout.corner
	assert scroll_content_width(strip.children) == strip.frame.width
	content := strip.children[0]
	assert content.frame.x == -30 && content.frame.y == -layout.corner
	name := tables_find(content, component_part_id('people', 'head:1'))?
	assert name.frame.x == 120 && name.button_behavior
	assert name.accessibility_label == 'Name'
	// The non-sortable column is a plain header label.
	score := tables_find_key(content, 'head:score')?
	assert score.kind == .label && score.accessibility_role == 'columnheader'
	// Resize handles straddle the dividers of resizable columns only.
	handle := tables_find(content, component_part_id('people', 'resize:0'))?
	assert handle.draggable && handle.cursor == cursor_resize_ew
	assert handle.frame.x == 120 - data_table_handle_reach
	assert tables_find(content, component_part_id('people', 'resize:2')) == none
}

fn test_data_table_header_shows_sort_and_selection_state() {
	mut source := tables_source(10)
	source.selected[3] = true
	config := DataTableConfig{
		...tables_data_config(source)
		sort_column:    1
		sort_direction: .descending
	}
	el := data_table(config)!
	name := tables_find(el, component_part_id('people', 'head:1'))?
	assert name.accessibility_value == 'sorted descending'
	assert name.children[1].image_path == 'symbol:arrow.down'
	idcol := tables_find(el, component_part_id('people', 'head:0'))?
	assert idcol.children[1].image_path == 'symbol:arrow.up.arrow.down'
	for symbol in ['arrow.up', 'arrow.down', 'arrow.up.arrow.down', 'checkmark', 'minus', 'tray'] {
		assert symbol_known(symbol)
	}
	all := tables_find(el, component_part_id('people', 'check_all'))?
	assert all.accessibility_value == 'mixed'
	assert all.children[0].children[0].image_path == 'symbol:minus'
	row3 := tables_find(el, component_part_id('people', 'row:3'))?
	assert row3.accessibility_value == 'selected'
	assert row3.box.bg == table_colors(config.theme).selected
	check3 := tables_find(el, component_part_id('people', 'check:3'))?
	assert check3.accessibility_value == 'checked'
	check4 := tables_find(el, component_part_id('people', 'check:4'))?
	assert check4.accessibility_value == 'unchecked'
	assert check4.children[0].children.len == 0
}

fn test_data_table_rows_show_hover_stripes_and_the_active_row() {
	mut source := tables_source(10)
	source.disabled[5] = true
	config := DataTableConfig{
		...tables_data_config(source)
		striped:     true
		hovered_row: 2
		active_row:  4
	}
	el := data_table(config)!
	colors := table_colors(config.theme)
	row1 := tables_find(el, component_part_id('people', 'row:1'))?
	assert row1.box.bg == colors.stripe && row1.box.border_bottom == 1
	row2 := tables_find(el, component_part_id('people', 'row:2'))?
	assert row2.box.bg == colors.hover && row2.hoverable && row2.button_behavior
	assert row2.accessibility_role == 'row'
	row4 := tables_find(el, component_part_id('people', 'row:4'))?
	assert row4.box.border_color == colors.accent && row4.box.border_left == 1
	row5 := tables_find(el, component_part_id('people', 'row:5'))?
	assert !row5.enabled
	cell := tables_find_key(row5, 'cell:0')?
	assert cell.text_style.color == colors.dimmed_text
	assert cell.frame.x == 40 + table_metrics(.medium).padding
}

fn test_data_table_loading_and_empty_states() {
	source := tables_source(5000)
	loading := data_table(DataTableConfig{
		...tables_data_config(source)
		loading: true
	})!
	body := tables_find(loading, data_table_body_id('people'))?
	assert body.children.len == 0
	skeleton := tables_find_key(loading, 'loading')?
	assert skeleton.accessibility_role == 'status'
	assert tables_count(skeleton, .view) > 10
	tables_assert_inside(skeleton)
	assert loading.accessibility_value == 'loading'
	all := tables_find(loading, component_part_id('people', 'check_all'))?
	assert !all.enabled
	empty := data_table(DataTableConfig{
		...tables_data_config(tables_source(0))
		empty_text: 'Nobody here'
	})!
	assert 'Nobody here' in tables_labels(empty)
	assert empty.accessibility_value == '0 rows'
}

fn test_data_table_custom_cells_and_footer() {
	badge_el := view('badge', rect(0, 6, 60, 20), BoxStyle{ bg: 0x22c55e }, []Element{})
	config := DataTableConfig{
		id:        'custom'
		frame:     rect(0, 0, 400, 300)
		columns:   tables_data_columns()
		row_count: 3
		row:       fn [badge_el] (index int) TableRow {
			return TableRow{
				cells: [TableCell{
					text: '${index}'
				}, TableCell{
					content: if index == 1 { [badge_el] } else { []Element{} }
					text:    'plain'
				}]
			}
		}
		footer:    [table_text_row(['', 'Sum', '3'])]
	}
	el := data_table(config)!
	row1 := tables_find(el, component_part_id('custom', 'row:1'))?
	content := tables_find_key(row1, 'cell:1')?
	assert content.kind == .view && content.children[0].id == 'badge'
	assert content.frame.x == 80 + table_metrics(.medium).padding
	// Missing cells are blank and a row without selection is not a button.
	assert tables_find_key(row1, 'cell:2') == none
	assert !row1.button_behavior
	footer := tables_find_key(el, 'footer')?
	assert footer.kind == .scroll && footer.scroll_mode == .horizontal_only
	assert 'Sum' in tables_labels(footer)
}

fn test_data_table_validates_its_config() {
	if _ := data_table(DataTableConfig{
		frame: rect(0, 0, 100, 100)
	}) {
		assert false
	}
	if _ := data_table(DataTableConfig{
		id:        'x'
		frame:     rect(0, 0, 100, 100)
		row_count: 3
	}) {
		assert false
	}
	if _ := data_table(DataTableConfig{
		id:        'x'
		frame:     rect(0, 0, 100, 100)
		row_count: -1
	}) {
		assert false
	}
	// Duplicate row keys are rejected by the tree validation.
	if _ := data_table(DataTableConfig{
		id:        'x'
		frame:     rect(0, 0, 100, 100)
		row_count: 2
		row:       fn (index int) TableRow {
			return TableRow{
				key: 'same'
			}
		}
	}) {
		assert false
	}
}

// ── DataTable events ────────────────────────────────────────────────

fn test_data_table_event_sorts_sortable_columns() {
	source := tables_source(10)
	config := tables_data_config(source)
	head1 := component_part_id('people', 'head:1')
	first := data_table_event(config, head1)?
	assert first.kind == .sort && first.column == 1 && first.direction == .ascending
	sorted := DataTableConfig{
		...config
		sort_column:    1
		sort_direction: .ascending
	}
	assert data_table_event(sorted, head1)?.direction == .descending
	assert data_table_event(DataTableConfig{
		...sorted
		sort_direction: .descending
	}, head1)?.direction == .none
	// Another column starts ascending; unsortable or unknown columns do nothing.
	assert data_table_event(sorted, component_part_id('people', 'head:0'))?.direction == .ascending
	assert data_table_event(config, component_part_id('people', 'head:2')) == none
	assert data_table_event(config, component_part_id('people', 'head:3')) == none
	assert data_table_event(config, component_part_id('people', 'head:01')) == none
	assert data_table_event(DataTableConfig{
		...config
		loading: true
	}, head1) == none
	assert data_table_event(DataTableConfig{
		...config
		enabled: false
	}, head1) == none
}

fn test_data_table_event_selects_and_toggles_rows() {
	mut source := tables_source(10)
	config := tables_data_config(source)
	row3 := component_part_id('people', 'row:3')
	assert data_table_event(config, row3)? == DataTableEvent{
		kind: .select_row
		row:  3
	}
	check3 := component_part_id('people', 'check:3')
	assert data_table_event(config, check3)? == DataTableEvent{
		kind:    .toggle_row
		row:     3
		checked: true
	}
	source.selected[3] = true
	selected := DataTableConfig{
		...tables_data_config(source)
		active_row: 3
	}
	assert data_table_event(selected, check3)?.checked == false
	// Clicking the only selected, active row changes nothing.
	assert data_table_event(selected, row3) == none
	assert data_table_event(DataTableConfig{
		...selected
		active_row: -1
	}, row3) != none
	// Select all, then clear all once everything is selected.
	all := component_part_id('people', 'check_all')
	assert data_table_event(selected, all)? == DataTableEvent{
		kind:    .select_all
		checked: true
	}
	assert data_table_event(DataTableConfig{
		...selected
		selected_count: 10
	}, all)?.checked == false
	// Disabled rows, rows that do not exist and checkboxes in single mode.
	source.disabled[4] = true
	assert data_table_event(config, component_part_id('people', 'row:4')) == none
	assert data_table_event(config, component_part_id('people', 'check:4')) == none
	assert data_table_event(config, component_part_id('people', 'row:10')) == none
	single := DataTableConfig{
		...config
		selection: .single
	}
	assert data_table_event(single, check3) == none
	assert data_table_event(single, all) == none
	assert data_table_event(single, component_part_id('people', 'row:2'))?.kind == .select_row
	assert data_table_event(DataTableConfig{
		...config
		selection: .none
	}, row3) == none
	assert data_table_event(config, 'people') == none
	assert data_table_event(config, component_part_id('people', 'body')) == none
}

fn test_data_table_event_reports_hover() {
	source := tables_source(10)
	config := DataTableConfig{
		...tables_data_config(source)
		hovered_row: 2
	}
	row2 := component_part_id('people', 'row:2')
	row5 := component_part_id('people', 'row:5')
	assert data_table_event(config, 'pointer:enter:${row5}:1:2')? == DataTableEvent{
		kind: .hover_row
		row:  5
	}
	assert data_table_event(config, 'pointer:enter:${row2}:1:2') == none
	assert data_table_event(config, 'pointer:leave:${row2}:1:2')?.row == -1
	assert data_table_event(config, 'pointer:leave:${row5}:1:2') == none
	assert data_table_event(DataTableConfig{
		...config
		hoverable: false
	}, 'pointer:enter:${row5}:1:2') == none
	assert data_table_event(config, 'pointer:down:${row5}:1:2') == none
}

fn test_data_table_event_resizes_columns_by_dragging() {
	source := tables_source(10)
	config := tables_data_config(source)
	handle := component_part_id('people', 'resize:1')
	start := data_table_event(config, 'pointer:down:${handle}:500:10')?
	assert start.kind == .resize_start && start.column == 1
	assert start.drag == TableResizeDrag{
		column:      1
		start_x:     500
		start_width: 200
	}
	dragging := DataTableConfig{
		...config
		resize_drag: start.drag
	}
	moved := data_table_event(dragging, 'pointer:drag:${handle}:540:10')?
	assert moved.kind == .resize && moved.width == 240
	assert moved.widths == [80.0, 240, 120]
	// The width is held to the column's minimum.
	assert data_table_event(dragging, 'pointer:drag:${handle}:100:10')?.width == 40
	ended := data_table_event(DataTableConfig{
		...dragging
		columns: [config.columns[0], TableColumn{
			...config.columns[1]
			width: 240
		}, config.columns[2]]
	}, 'pointer:up:${handle}:540:10')?
	assert ended.kind == .resize_end && ended.width == 240
	// A drag that does not move the width, one without a press, a column that
	// does not resize and a forged column do nothing.
	assert data_table_event(dragging, 'pointer:drag:${handle}:500:10') == none
	assert data_table_event(config, 'pointer:drag:${handle}:540:10') == none
	fixed := component_part_id('people', 'resize:2')
	assert data_table_event(config, 'pointer:down:${fixed}:540:10') == none
	assert data_table_event(config, 'pointer:down:${component_part_id('people', 'resize:9')}:540:10') == none
	assert data_table_event(config, handle) == none
	assert data_table_event(DataTableConfig{
		...config
		loading: true
	}, 'pointer:down:${handle}:500:10') == none
}

fn test_data_table_keyboard_and_scrolling_helpers() {
	mut source := tables_source(100)
	config := DataTableConfig{
		...tables_data_config(source)
		active_row: 5
	}
	page := data_table_page_rows(config)
	assert page == int(math.floor(data_table_layout(config).body.height / 32))
	down := data_table_event_from_key(config, KeyEvent{ code: .down })?
	assert down == DataTableEvent{
		kind: .select_row
		row:  6
	}
	assert data_table_event_from_key(config, KeyEvent{ code: .page_down })?.row == 5 + page
	assert data_table_event_from_key(config, KeyEvent{ code: .end })?.row == 99
	assert data_table_event_from_key(config, KeyEvent{ code: .space })? == DataTableEvent{
		kind:    .toggle_row
		row:     5
		checked: true
	}
	assert data_table_event_from_key(config, KeyEvent{ code: .a, cmd: true })?.kind == .select_all
	assert data_table_event_from_key(config, KeyEvent{ code: .a, ctrl: true })?.checked
	assert data_table_event_from_key(config, KeyEvent{ code: .escape }) == none
	assert data_table_event_from_key(config, KeyEvent{ code: .down, shift: true }) == none
	source.selected[5] = true
	selected := DataTableConfig{
		...tables_data_config(source)
		active_row: 5
	}
	assert data_table_event_from_key(selected, KeyEvent{ code: .escape })?.kind == .clear_selection
	single := DataTableConfig{
		...selected
		selection: .single
	}
	assert data_table_event_from_key(single, KeyEvent{ code: .space }) == none
	assert data_table_event_from_key(single, KeyEvent{ code: .a, cmd: true }) == none
	assert data_table_event_from_key(single, KeyEvent{ code: .up })?.row == 4
	assert data_table_event_from_key(DataTableConfig{
		...selected
		selection: .none
	}, KeyEvent{ code: .down }) == none
	// Scrolling a row into view.
	rh := table_metrics(.medium).row_height
	body := data_table_layout(config).body.height
	assert data_table_scroll_to_row(config, 2) == none
	assert data_table_scroll_to_row(config, 50)? == 51 * rh - body
	scrolled := DataTableConfig{
		...config
		scroll_y: 40 * rh
	}
	assert data_table_scroll_to_row(scrolled, 10)? == 10 * rh
	assert data_table_scroll_to_row(scrolled, 41) == none
	assert data_table_scroll_to_row(config, 100) == none
}

fn test_tables_are_valid_trees_on_every_size_and_theme() {
	for size in [ComponentSize.small, .medium, .large] {
		for dark in [false, true] {
			theme := component_theme(dark)
			simple := table(TableConfig{
				frame:           rect(0, 0, 300, 400)
				columns:         tables_columns()
				rows:            tables_rows(3)
				footer:          [table_text_row(['Total'])]
				caption:         'Caption'
				striped:         true
				column_dividers: true
				size:            size
				theme:           theme
			})!
			tables_assert_inside(simple)
			source := tables_source(50)
			grid := data_table(DataTableConfig{
				...tables_data_config(source)
				column_dividers: true
				striped:         true
				size:            size
				theme:           theme
			})!
			validate_element_tree(grid)!
			colors := table_colors(theme)
			assert choice_contrast(colors.head_text, colors.head) >= 3
			assert choice_contrast(colors.text, colors.selected_hover) >= 4.5
			assert colors.hover != colors.stripe
		}
	}
}

fn test_data_table_keyboard_skips_disabled_rows() {
	mut source := tables_source(10)
	source.disabled[6] = true
	source.disabled[7] = true
	config := DataTableConfig{
		...tables_data_config(source)
		active_row: 5
	}
	// Down lands past the disabled rows; Up from below them lands above.
	assert data_table_event_from_key(config, KeyEvent{ code: .down })?.row == 8
	assert data_table_event_from_key(DataTableConfig{
		...config
		active_row: 8
	}, KeyEvent{ code: .up })?.row == 5
	// End on a disabled last row comes back to the nearest enabled one.
	source.disabled[9] = true
	assert data_table_event_from_key(config, KeyEvent{ code: .end })?.row == 8
	// Home on a disabled first row goes on toward the active row.
	source.disabled[0] = true
	assert data_table_event_from_key(config, KeyEvent{ code: .home })?.row == 1
	// Nothing enabled in reach: no move.
	for i in 0 .. 5 {
		source.disabled[i] = true
	}
	assert data_table_event_from_key(config, KeyEvent{ code: .home }) == none
	assert data_table_event_from_key(config, KeyEvent{ code: .up }) == none
}

fn test_data_table_skeleton_and_single_selection_layout() {
	source := tables_source(20)
	config := DataTableConfig{
		...tables_data_config(source)
		selection: .single
		loading:   true
	}
	layout := data_table_layout(config)
	assert layout.selection_width == 0 && layout.xs[0] == 0
	el := data_table(config)!
	assert tables_find(el, component_part_id('people', 'check_all')) == none
	skeleton := tables_find_key(el, 'loading')?
	pad := table_metrics(.medium).padding
	// Bars sit where each column's text would: the right-aligned score column's
	// bars end at its right padding, the others start at their left padding.
	bars := skeleton.children.filter(it.key == '' && it.frame.y < layout.row_height)
	assert bars.len == 3
	assert bars[0].frame.x == pad
	assert bars[1].frame.x == 80 + pad
	assert math.abs(bars[2].frame.x + bars[2].frame.width - (280 + 120 - pad)) < 1e-9
}
