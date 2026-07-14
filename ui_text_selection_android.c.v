module ui2

pub fn text_area_set_selection(id string, location int, length int) {
	record_portable_text_area_selection(id, clamped_text_area_selection(text(id), location, length))
}

pub fn text_area_set_caret(id string, pos int) {
	text_area_set_selection(id, pos, 0)
}

pub fn text_area_caret(id string) int {
	return portable_text_area_selection(id).location
}

pub fn text_area_selection_length(id string) int {
	return portable_text_area_selection(id).length
}
