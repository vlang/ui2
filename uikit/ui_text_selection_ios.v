module ui2

pub fn text_area_set_selection(id string, location int, length int) {
	view := g_views[id] or { return }
	selection := clamped_text_area_selection(text(id), location, length)
	native_text_view_set_selected_range(view, u64(selection.location), u64(selection.length))
}

pub fn text_area_set_caret(id string, pos int) {
	text_area_set_selection(id, pos, 0)
}

pub fn text_area_caret(id string) int {
	view := g_views[id] or { return 0 }
	return int(native_text_view_selected_range(view).location)
}

pub fn text_area_selection_length(id string) int {
	view := g_views[id] or { return 0 }
	return int(native_text_view_selected_range(view).length)
}
