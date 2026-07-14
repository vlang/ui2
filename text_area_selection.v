@[has_globals]
module ui2

// TextAreaSelectionRange is stored in UTF-16 code units to match the native
// NSTextView, UITextView, Win32 and Qt text-control APIs.
pub struct TextAreaSelectionRange {
pub:
	location int
	length   int
}

__global portable_text_area_selections = map[string]TextAreaSelectionRange{}

fn clamped_text_area_selection(text string, location int, length int) TextAreaSelectionRange {
	text_length := text_area_utf16_length(text)
	start := clamp_int(location, 0, text_length)
	return TextAreaSelectionRange{
		location: start
		length:   clamp_int(length, 0, text_length - start)
	}
}

fn record_portable_text_area_selection(id string, selection TextAreaSelectionRange) {
	if id.len > 0 {
		portable_text_area_selections[id] = selection
	}
}

fn portable_text_area_selection(id string) TextAreaSelectionRange {
	return portable_text_area_selections[id] or { TextAreaSelectionRange{} }
}

fn text_area_utf16_length(text string) int {
	mut length := 0
	for value in text.runes() {
		length += if value > 0xffff { 2 } else { 1 }
	}
	return length
}
