module ui2

pub fn text_area_set_selection(id string, location int, length int) {
	record_portable_text_area_selection(id, TextAreaSelectionRange{
		location: if location < 0 { 0 } else { location }
		length:   if length < 0 { 0 } else { length }
	})
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
