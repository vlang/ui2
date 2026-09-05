module ui2

fn test_linux_immediate_backend_defaults() {
	assert bounds() == Rect{
		width: 800
		height: 600
	}
	assert control_support(.button) == .supported
	assert control_support(.text_field) == .supported
	assert control_support(.dropdown) == .partial
	assert control_support(.text_area) == .partial
}
