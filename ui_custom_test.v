module ui2

$if ui2_custom_rendering ? {
	fn custom_test_key_handler(_key string) {}

	fn custom_test_scroll_handler(_id string) {}

	fn custom_test_drop_handler(_event DropEvent) {}

	fn test_custom_desktop_backend_defaults() {
		assert bounds() == Rect{
			width: 800
			height: 600
		}
		assert control_support(.button) == .supported
		assert control_support(.text_field) == .supported
		assert control_support(.dropdown) == .partial
		assert control_support(.text_area) == .partial
	}

	fn test_custom_desktop_backend_exposes_desktop_hooks() {
		on_key(custom_test_key_handler)
		on_scroll(custom_test_scroll_handler)
		on_drop(custom_test_drop_handler)
		request_refresh()
		refresh_element('missing', Element{})
		insert_text_area_text('missing', 'text')
		scroll_to_rect('missing', 0, 0, 10, 10)
		assert scroll_offset('missing') == 0
		assert text_area_runs('missing').len == 0
		assert text_area_format_state('missing') == TextFormatState{}
		assert !clipboard_has_image()
		assert !save_clipboard_image_png('unused.png')
		quit()
	}
}
