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
}
