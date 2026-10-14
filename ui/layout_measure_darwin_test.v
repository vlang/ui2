// vtest build: macos && !ui2_custom_rendering? && !ui2_headless?
module ui2

$if macos && !ui2_custom_rendering ?&& !ui2_headless ? {
	import macos

	fn test_layout_native_content_sized_label_fits_its_appkit_cell() {
		pool := macos.autorelease_pool_new()
		defer { macos.release(pool) }
		for caption in ['Created: 1', 'iii', 'WWW'] {
			style := TextStyle{ size: 14 }
			element := label('caption', caption, Rect{}, style)
			measured := measure_layout_element(element, LayoutConstraints{}, measure_layout_text)!
			frame := NativeRect{ width: measured.width, height: measured.height }
			native := native_new_label(frame, caption, style.color, style.size, false,
				false, false, align_value(style.align), 1, .top, false)
			cell := macos.msg_id(native, 'cell')
			cell_size := macos.msg_point(cell, 'cellSize')
			macos.release(native)
			assert measured.width >= cell_size.x, 'content-sized `${caption}` must include the NSTextField cell insets: ${measured.width} < ${cell_size.x}'
		}
	}
}
