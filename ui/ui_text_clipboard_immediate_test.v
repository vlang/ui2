// vfmt off
@[has_globals]
module ui2

$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import gg

	// FakeClipboard stands in for the system clipboard so the tests can
	// observe what was copied and simulate a backend that refuses the write.
	struct FakeClipboard {
	mut:
		accepts bool = true
		text    string
		copies  int
	}

	fn (mut cb FakeClipboard) copy(text string) bool {
		cb.copies++
		if !cb.accepts {
			return false
		}
		cb.text = text
		return true
	}

	fn (mut cb FakeClipboard) paste() string {
		return cb.text
	}

	__global clipboard_test_events = []string{}

	fn capture_clipboard_test_event(id string) {
		clipboard_test_events << id
	}

	// primary_modifier is the shortcut chord for the platform the test runs on.
	fn primary_modifier() u32 {
		$if macos {
			return u32(gg.Modifier.super)
		} $else {
			return u32(gg.Modifier.ctrl)
		}
	}

	fn reset_clipboard_test(text string, kind Kind) {
		g_text_values = map[string]string{}
		g_text_props = map[string]string{}
		g_text_editors = map[string]TextEditor{}
		g_text_kinds = {
			'field': kind
		}
		g_text_secure = map[string]bool{}
		g_active_fields = {
			'field': true
		}
		g_focused_field = 'field'
		g_hit_targets = [HitTarget{id: 'field', action_id: 'changed', text_field: kind == .text_field, text_area: kind == .text_area, emit_change: true}]
		g_event_handler = capture_clipboard_test_event
		clipboard_test_events = []string{}
		replace_text_value('field', text)
		replace_text_editor('field', text_editor(text.clone()))
	}

	fn finish_clipboard_test() {
		forget_text_state('field')
		g_active_fields = map[string]bool{}
		g_focused_field = ''
		g_hit_targets = []HitTarget{}
		g_event_handler = EventFn(unsafe { nil })
		g_clipboard_override = none
	}

	fn select_field_range(anchor int, caret int) {
		mut editor := g_text_editors['field'] or { panic('missing editor') }
		editor.set_selection(anchor, caret)
		replace_text_editor('field', editor)
	}

	fn test_text_editor_replaces_owned_state_after_caret_moves() {
		reset_clipboard_test('abc', .text_field)
		handle_key_down(.left, 0)
		handle_key_down(.backspace, 0)
		handle_char_input(`x`, 0)
		assert text('field') == 'axc'
		assert clipboard_test_events == ['changed', 'changed']
		finish_clipboard_test()
	}

	fn test_char_input_drops_shortcut_letters_and_control_characters() {
		reset_clipboard_test('', .text_field)
		// The chord's own letter arrives as a char event on macOS and X11.
		handle_char_input(`v`, u32(gg.Modifier.ctrl))
		handle_char_input(`v`, u32(gg.Modifier.super))
		handle_char_input(`v`, u32(gg.Modifier.ctrl) | u32(gg.Modifier.shift))
		// Backspace on macOS also reports DEL after the key event.
		handle_char_input(127, 0)
		handle_char_input(8, 0)
		assert text('field') == ''
		assert clipboard_test_events == []
		// Windows reports AltGr as Ctrl+Alt, and AltGr characters are text.
		handle_char_input(`@`, u32(gg.Modifier.ctrl) | u32(gg.Modifier.alt))
		handle_char_input(`a`, u32(gg.Modifier.shift))
		handle_char_input(`b`, 0)
		assert text('field') == '@ab'
		assert clipboard_test_events == ['changed', 'changed', 'changed']
		finish_clipboard_test()
	}

	fn test_copy_and_cut_use_the_selection() {
		reset_clipboard_test('hello world', .text_field)
		mut fake := &FakeClipboard{}
		g_clipboard_override = fake
		select_field_range(0, 5)
		handle_key_down(.c, primary_modifier())
		assert fake.text == 'hello'
		assert text('field') == 'hello world'
		assert clipboard_test_events == []

		select_field_range(5, 11)
		handle_key_down(.x, primary_modifier())
		assert fake.text == ' world'
		assert text('field') == 'hello'
		editor := g_text_editors['field'] or { panic('missing editor') }
		assert editor.selection.anchor == 5
		assert editor.selection.caret == 5
		assert clipboard_test_events == ['changed']

		// Without a selection nothing reaches the clipboard, and the chord is
		// still consumed rather than typed.
		handle_key_down(.c, primary_modifier())
		handle_key_down(.x, primary_modifier())
		assert fake.copies == 2
		assert text('field') == 'hello'
		finish_clipboard_test()
	}

	fn test_cut_keeps_the_text_when_the_clipboard_rejects_it() {
		reset_clipboard_test('hello world', .text_field)
		mut fake := &FakeClipboard{accepts: false}
		g_clipboard_override = fake
		select_field_range(6, 11)
		handle_key_down(.x, primary_modifier())
		assert fake.copies == 1
		assert fake.text == ''
		assert text('field') == 'hello world'
		editor := g_text_editors['field'] or { panic('missing editor') }
		assert editor.selection.anchor == 6
		assert editor.selection.caret == 11
		assert clipboard_test_events == []
		finish_clipboard_test()
	}

	fn test_paste_replaces_the_selection_and_flattens_newlines_in_single_line_fields() {
		reset_clipboard_test('hello world', .text_field)
		mut fake := &FakeClipboard{text: 'big\r\nwide\nnew\rworld'}
		g_clipboard_override = fake
		select_field_range(6, 11)
		handle_key_down(.v, primary_modifier())
		assert text('field') == 'hello big wide new world'
		assert clipboard_test_events == ['changed']

		fake.text = ''
		handle_key_down(.v, primary_modifier())
		assert text('field') == 'hello big wide new world'
		assert clipboard_test_events == ['changed']
		finish_clipboard_test()

		reset_clipboard_test('first', .text_area)
		g_clipboard_override = &FakeClipboard{text: '\nsecond\n'}
		handle_key_down(.v, primary_modifier())
		assert text('field') == 'first\nsecond\n'
		assert clipboard_test_events == ['changed']
		finish_clipboard_test()
	}

	fn test_secure_fields_never_export_their_contents() {
		// A password field masks only at draw time, so the editor holds the
		// plaintext; copy and cut must be consumed without reaching the clipboard.
		reset_clipboard_test('secret', .text_field)
		g_text_secure['field'] = true
		mut fake := &FakeClipboard{text: 'pasted'}
		g_clipboard_override = fake
		select_field_range(0, 6)
		handle_key_down(.c, primary_modifier())
		handle_key_down(.x, primary_modifier())
		assert fake.copies == 0
		assert fake.text == 'pasted'
		assert text('field') == 'secret'
		cut_editor := g_text_editors['field'] or { panic('missing editor') }
		assert cut_editor.selection.anchor == 0
		assert cut_editor.selection.caret == 6
		assert clipboard_test_events == []

		// Paste stays available so the field can still be filled from a manager.
		handle_key_down(.v, primary_modifier())
		assert text('field') == 'pasted'
		assert clipboard_test_events == ['changed']
		finish_clipboard_test()

		// The same field id without the flag copies as usual.
		reset_clipboard_test('secret', .text_field)
		mut plain := &FakeClipboard{}
		g_clipboard_override = plain
		select_field_range(0, 6)
		handle_key_down(.c, primary_modifier())
		assert plain.text == 'secret'
		finish_clipboard_test()
	}

	fn test_clipboard_shortcuts_need_the_primary_modifier() {
		reset_clipboard_test('hello', .text_field)
		mut fake := &FakeClipboard{text: 'pasted'}
		g_clipboard_override = fake
		select_field_range(0, 5)
		handle_key_down(.c, 0)
		handle_key_down(.v, u32(gg.Modifier.shift))
		handle_key_down(.v, u32(gg.Modifier.ctrl) | u32(gg.Modifier.alt))
		assert fake.copies == 0
		assert text('field') == 'hello'
		finish_clipboard_test()
	}
}
