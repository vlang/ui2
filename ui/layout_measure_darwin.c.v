// Keep AppKit imports behind the native backend switch so custom builds do not
// mix AppKit's MRC bridge with Sokol's ARC sources.
module ui2

$if macos && !ui2_custom_rendering ?&& !ui2_headless ? {
	import macos

	fn layout_measure_appkit_text(text string, style TextStyle, max_width f64) !LayoutSize {
		pool := macos.autorelease_pool_new()
		defer { macos.release(pool) }
		font := native_text_style_font(style)
		line_height := macos.msg_f64(font, 'ascender') - macos.msg_f64(font, 'descender') +
			macos.msg_f64(font, 'leading')
		attrs := native_text_attributes(style.color, 0, style.size, style.font_family,
			style.bold, style.italic, style.underline, style.strikethrough, style.vertical_align)
		return layout_measure_text_lines(text, style, max_width, line_height, fn [attrs] (line string) f64 {
			attributed := macos.msg_id2(macos.alloc('NSAttributedString'), 'initWithString:attributes:', macos.nsstring(line), attrs)
			size := macos.msg_point(attributed, 'size')
			macos.release(attributed)
			return size.x
		})
	}
}
