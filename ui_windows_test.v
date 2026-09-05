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
		field := C.ui2_win_create_widget(windows_widget_kind(.text_field), root, 0, 0, 200, 32, empty, 0, 0, 0, 0)
		placeholder := 'First name'.to_wide()
		C.ui2_win_set_edit_options(field, placeholder, 0, 12)
		assert C.ui2_win_placeholder_matches(field, placeholder) != 0

		label := C.ui2_win_create_widget(windows_widget_kind(.label), root, 0, 40, 200, 32, empty, 0, 0, 0, 0)
		checkbox := C.ui2_win_create_widget(windows_widget_kind(.checkbox), root, 0, 80, 210, 30, empty, 0, 0, 0, 0)
		assert C.ui2_win_widget_style(label) & usize(0x0200) != 0
		assert C.ui2_win_widget_style(checkbox) & usize(0x2000) == 0

		unsafe {
			free(empty)
			free(placeholder)
		}
	}
}
