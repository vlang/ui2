module main

import ui2

fn test_column_browser_is_a_sideways_strip_of_vertically_scrolling_columns() {
	browser := &ColumnBrowser{
		selected: [3, 2]
	}
	root := browser_screen(browser, ui2.rect(0, 0, 720, 440))
	ui2.validate_element_tree(root) or { panic(err) }
	strip := root.children.last()
	assert strip.kind == .scroll
	assert strip.id == 'columns'
	assert strip.scroll_mode == .horizontal_only
	// A column and its divider for each chosen folder, and for the one left open.
	assert strip.children.len == 6
	for index in 0 .. 3 {
		column := strip.children[index * 2]
		assert column.kind == .scroll
		assert column.scroll_mode == .vertical_only
		assert column.frame.x == index * columns_column_width
		assert column.frame.height == strip.frame.height
	}
	assert browser.content_width() == 3 * columns_column_width
	assert browser.path() == '/Documents/Pictures'
}

fn test_opening_a_row_replaces_the_columns_to_its_right() {
	mut browser := ColumnBrowser{
		selected: [3, 2, 6, 1]
	}
	browser.open(1, 4)
	assert browser.selected == [3, 4]
	assert browser.column_count() == 3
	// A row the column does not have, or a column that is not open, changes nothing.
	browser.open(0, 500)
	browser.open(7, 0)
	assert browser.selected == [3, 4]
}
