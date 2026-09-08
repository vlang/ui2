module ui2

$if !ui2_custom_rendering ? {
	fn test_windows_widget_kind_mapping_covers_every_native_control() {
		assert windows_widget_kind(.screen) == 0
		assert windows_widget_kind(.view) == 1
		assert windows_widget_kind(.scroll) == 2
		assert windows_widget_kind(.label) == 3
		assert windows_widget_kind(.image) == 4
		assert windows_widget_kind(.button) == 5
		assert windows_widget_kind(.checkbox) == 9
		assert windows_widget_kind(.dropdown) == 6
		assert windows_widget_kind(.text_field) == 7
		assert windows_widget_kind(.text_area) == 8
		assert windows_widget_kind(.slider) == 10
		assert windows_widget_kind(.switch_control) == 11
		assert windows_widget_kind(.toggle_button) == 12
	}

	fn test_windows_structural_transitions_recreate_controls() {
		plain := Element{
			kind: .text_field
		}
		secure := Element{
			kind: .text_field
			secure: true
		}
		assert windows_structural_signature(plain) != windows_structural_signature(secure)

		area := Element{
			kind: .text_area
		}
		area_without_scroll := Element{
			kind: .text_area
			disable_scroll: true
		}
		assert windows_structural_signature(area) != windows_structural_signature(area_without_scroll)

		styled_button := Element{
			kind: .button
			native_style: true
		}
		plain_button := Element{
			kind: .button
		}
		assert windows_structural_signature(styled_button) != windows_structural_signature(plain_button)

		horizontal_slider := Element{
			kind: .slider
		}
		vertical_slider := Element{
			kind: .slider
			orientation: .vertical
		}
		assert windows_structural_signature(horizontal_slider) != windows_structural_signature(vertical_slider)
	}

	fn test_windows_scroll_content_height_uses_child_extent() {
		children := [
			Element{
				kind: .label
				frame: rect(0, 10, 50, 20)
			},
			Element{
				kind: .button
				frame: rect(0, 80, 50, 35)
			},
		]
		assert windows_content_height(children) == 115
	}

	fn windows_test_font_family(font voidptr) string {
		mut buffer := []u16{len: 32}
		C.ui2_win_font_family(font, unsafe { &buffer[0] }, buffer.len)
		return unsafe { string_from_wide(&buffer[0]) }
	}

	fn test_windows_font_glyph_key_only_tracks_characters_that_may_need_a_fallback() {
		assert windows_font_glyph_key('Bond, James') == ''
		assert windows_font_glyph_key('Andr\u00e9') == ''
		assert windows_font_glyph_key('\u2713 Bond, James') == '2713'
		assert windows_font_glyph_key('\u2713\u2713') == '2713'
		assert windows_font_glyph_key('\U0001f642\u2713') == '2713.1f642'
	}

	fn test_windows_font_text_covers_every_string_a_control_draws() {
		field := Element{
			kind: .text_field
			text: 'Andr\u00e9'
			placeholder: 'Name'
		}
		assert windows_font_text(field) == 'Andr\u00e9Name'

		dropdown := Element{
			kind: .dropdown
			text: 'one'
			menu: [MenuEntry{
				id: 'two'
				title: '\u2713 two'
			}]
		}
		assert windows_font_text(dropdown) == 'one\u2713 two'

		// Context menu entries are drawn by the menu, not by the control font.
		button := Element{
			kind: .button
			text: 'Create'
			menu: [MenuEntry{
				id: 'copy'
				title: 'Copy'
			}]
		}
		assert windows_font_text(button) == 'Create'
	}

	fn test_windows_fonts_fall_back_to_a_family_that_has_the_glyphs() {
		default_family := ''.to_wide()
		plain := 'Bond, James'.to_wide()
		symbols := '\u2713 Bond, James'.to_wide()
		plain_font := C.ui2_win_create_font(unsafe { nil }, 13, default_family, 0, 0, 0,
			0, plain)
		symbol_font := C.ui2_win_create_font(unsafe { nil }, 13, default_family, 0, 0, 0,
			0, symbols)
		assert plain_font != unsafe { nil }
		assert symbol_font != unsafe { nil }
		// Text the UI font can draw keeps the UI font.
		assert windows_test_font_family(plain_font) == 'Segoe UI'
		assert C.ui2_win_font_missing_glyphs(plain_font, plain) == 0
		// A check mark is not in Segoe UI, so it must come from another family.
		assert C.ui2_win_font_missing_glyphs(symbol_font, symbols) == 0
		C.ui2_win_delete_object(plain_font)
		C.ui2_win_delete_object(symbol_font)
		unsafe {
			free(default_family)
			free(plain)
			free(symbols)
		}
	}

	fn test_windows_native_buttons_keep_the_system_font_until_glyphs_are_missing() {
		assert C.ui2_win_register_classes() != 0
		title := 'font test'.to_wide()
		root := C.ui2_win_create_main_window(title, 320, 200)
		unsafe {
			free(title)
		}
		assert root != unsafe { nil }
		defer {
			C.ui2_win_destroy(root)
		}

		plain := 'Bond, James'.to_wide()
		symbols := '\u2713 Bond, James'.to_wide()
		button := C.ui2_win_create_widget(windows_widget_kind(.button), root, 0, 0, 200,
			30, plain, 0, 0, 0, 0, 0)
		assert button != unsafe { nil }
		system_font := C.ui2_win_widget_font(button)
		C.ui2_win_apply_text_font(button, plain)
		assert C.ui2_win_widget_font(button) == system_font

		C.ui2_win_apply_text_font(button, symbols)
		assert C.ui2_win_font_missing_glyphs(C.ui2_win_widget_font(button), symbols) == 0
		unsafe {
			free(plain)
			free(symbols)
		}
	}

	fn test_windows_native_controls_keep_compact_text_layout() {
		assert C.ui2_win_register_classes() != 0
		assert C.ui2_win_visual_styles_enabled() != 0
		title := 'layout test'.to_wide()
		root := C.ui2_win_create_main_window(title, 320, 200)
		unsafe {
			free(title)
		}
		assert root != unsafe { nil }
		defer {
			C.ui2_win_destroy(root)
		}

		empty := ''.to_wide()
		field := C.ui2_win_create_widget(windows_widget_kind(.text_field), root, 0, 0, 200, 32, empty, 0, 0, 0, 0, 0)
		placeholder := 'First name'.to_wide()
		C.ui2_win_set_edit_options(field, placeholder, 0, 12)
		assert C.ui2_win_placeholder_matches(field, placeholder) != 0

		label := C.ui2_win_create_widget(windows_widget_kind(.label), root, 0, 40, 200, 32, empty, 0, 0, 0, 0, 0)
		checkbox := C.ui2_win_create_widget(windows_widget_kind(.checkbox), root, 0, 80, 210, 30, empty, 0, 0, 0, 0, 0)
		switch_view := C.ui2_win_create_widget(windows_widget_kind(.switch_control), root, 0, 120, 60, 32, empty, 0, 0, 0, 0, 0)
		assert C.ui2_win_widget_style(label) & usize(0x0200) != 0
		assert C.ui2_win_widget_style(checkbox) & usize(0x2000) == 0
		assert C.ui2_win_widget_style(switch_view) & usize(0x1000) != 0
		C.ui2_win_set_checked(switch_view, 1)
		assert C.ui2_win_get_checked(switch_view) != 0

		unsafe {
			free(empty)
			free(placeholder)
		}
	}
}
