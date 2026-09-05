module ui2

$if !ui2_custom_rendering ? {
	pub fn text_area_set_selection(id string, location int, length int) {
		selection := clamped_text_area_selection(text(id), location, length)
		record_portable_text_area_selection(id, selection)
		hwnd := windows_text_area_handle(id) or { return }
		windows_native_set_selection(hwnd, selection)
	}

	pub fn text_area_set_caret(id string, pos int) {
		text_area_set_selection(id, pos, 0)
	}

	pub fn text_area_caret(id string) int {
		hwnd := windows_text_area_handle(id) or { return portable_text_area_selection(id).location }
		selection := windows_native_get_selection(hwnd)
		record_portable_text_area_selection(id, selection)
		return selection.location
	}

	pub fn text_area_selection_length(id string) int {
		hwnd := windows_text_area_handle(id) or { return portable_text_area_selection(id).length }
		selection := windows_native_get_selection(hwnd)
		record_portable_text_area_selection(id, selection)
		return selection.length
	}
}
