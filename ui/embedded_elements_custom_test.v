// vtest build: macos && ui2_custom_rendering?
@[has_globals]
module ui2

$if ui2_custom_rendering ? {
	import gg

	fn test_embedded_field_selection_uses_the_requested_control_and_rune_offsets() {
		id := 'editor'
		g_hit_targets = [HitTarget{ id: id, text_field: true }]
		g_active_fields[id] = true
		g_text_kinds[id] = .text_field
		replace_text_value(id, 'a😀中b')
		defer {
			forget_text_state(id)
			g_active_fields.delete(id)
			g_hit_targets = []
			g_focused_field = ''
		}
		select_embedded_textbox(id)
		assert focused_id() == id
		all := g_text_editors[id] or { panic('missing editor') }
		assert all.selection.anchor == 0 && all.selection.caret == 4
		select_embedded_text_range(id, 1, 3)
		selected := g_text_editors[id] or { panic('missing selected editor') }
		assert selected.selection.anchor == 1 && selected.selection.caret == 3
	}

	fn test_readonly_embedded_fields_allow_selection_without_mutating_text() {
		id := 'readonly-editor'
		g_hit_targets = [HitTarget{ id: id, text_field: true }]
		g_active_fields[id] = true
		g_text_kinds[id] = .text_field
		replace_text_value(id, 'initial')
		g_text_readonly[id] = true
		defer {
			forget_text_state(id)
			g_active_fields.delete(id)
			g_hit_targets = []
			g_focused_field = ''
		}
		select_embedded_textbox(id)
		handle_char_input(u32(`x`), 0)
		handle_key_down(.backspace, 0)
		handle_key_down(.delete, 0)
		handle_key_down(.x, u32(gg.Modifier.super))
		handle_key_down(.v, u32(gg.Modifier.super))
		assert text(id) == 'initial'
		handle_key_down(.left, 0)
		editor := g_text_editors[id] or { panic('missing readonly editor') }
		assert editor.selection.collapsed()
		assert text(id) == 'initial'
	}
}
