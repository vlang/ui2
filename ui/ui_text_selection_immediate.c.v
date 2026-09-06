module ui2

$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	pub fn text_area_set_selection(id string, location int, length int) {
		if id !in g_active_fields || (g_text_kinds[id] or { Kind.screen }) != .text_area {
			return
		}
		value := text(id)
		selection := clamped_text_area_selection(value, location, length)
		record_portable_text_area_selection(id, selection)
		mut editor := g_text_editors[id] or { text_editor(value) }
		start := utf16_offset_to_rune_index(value, selection.location)
		end := utf16_offset_to_rune_index(value, selection.location + selection.length)
		editor.set_selection(start, end)
		g_text_editors[id] = editor
	}

	pub fn text_area_set_caret(id string, pos int) {
		text_area_set_selection(id, pos, 0)
	}

	pub fn text_area_caret(id string) int {
		if (g_text_kinds[id] or { Kind.screen }) != .text_area {
			return 0
		}
		editor := g_text_editors[id] or { return portable_text_area_selection(id).location }
		return rune_index_to_utf16_offset(editor.text, editor.selection.caret)
	}

	pub fn text_area_selection_length(id string) int {
		if (g_text_kinds[id] or { Kind.screen }) != .text_area {
			return 0
		}
		editor := g_text_editors[id] or { return portable_text_area_selection(id).length }
		start, end := editor.selection.ordered()
		return rune_index_to_utf16_offset(editor.text, end) - rune_index_to_utf16_offset(editor.text,
			start)
	}
}
