@[has_globals]
module ui2

// MeasureTextFn reports how wide a label must be to show `text` on one line in
// `style`, as the backend that draws it lays the text out.
pub type MeasureTextFn = fn (text string, style TextStyle) f64

// The running backend's measurer and the widths it has reported. A build can
// measure the same words many times (the custom renderer builds every frame),
// so widths are kept until the cache grows past text_measure_cache_limit.
__global g_text_measurer = MeasureTextFn(unsafe { nil })
__global g_text_widths = map[string]f64{}

const text_measure_cache_limit = 8192

// configure_text_measurer is how a backend makes measure_text_width exact once
// its window system is up.
fn configure_text_measurer(measure MeasureTextFn) {
	g_text_measurer = measure
	g_text_widths.clear()
}

// measure_text_width returns how wide a label must be to show `text` on one
// line in `style`: the drawn width of its glyphs plus whatever inset the
// backend's labels put around them. Newlines are not broken at. Until a window
// is running (in tests, say) it is an estimate, as text_measurement_exact
// reports.
pub fn measure_text_width(text string, style TextStyle) f64 {
	if text.len == 0 {
		return 0
	}
	measure := g_text_measurer
	if measure == unsafe { nil } {
		return text_width_estimate(text, style)
	}
	key := text_measure_key(text, style)
	if width := g_text_widths[key] {
		return width
	}
	width := measure(text, style)
	if g_text_widths.len >= text_measure_cache_limit {
		g_text_widths.clear()
	}
	g_text_widths[key] = width
	return width
}

// text_measurement_exact reports whether measure_text_width asks the backend
// (a window is running) or estimates.
pub fn text_measurement_exact() bool {
	return g_text_measurer != unsafe { nil }
}

// wrap_text_to_width breaks text into the lines a label `width` wide shows it
// on: at its own newlines and at the space before a word that would not fit. A
// word wider than the line stays whole on a line of its own.
pub fn wrap_text_to_width(text string, style TextStyle, width f64) []string {
	return wrap_text_lines_measured(text, width, text_lines_unlimited, fn [style] (line string) f64 {
		return measure_text_width(line, style)
	})
}

// text_width_estimate guesses a width from the character count, wide enough for
// typical proportional text so a label laid out with it is not cut short.
fn text_width_estimate(text string, style TextStyle) f64 {
	mut ems := 0.0
	for r in text.runes() {
		ems += if r >= 0x2e80 { 1.0 } else { 0.62 }
	}
	width := ems * font_em_pixels(if style.size > 0 { style.size } else { 15.0 })
	return if style.bold { width * 1.06 } else { width }
}

fn text_measure_key(text string, style TextStyle) string {
	mut flags := 0
	if style.bold {
		flags |= 1
	}
	if style.italic {
		flags |= 2
	}
	return '${style.size}|${style.font_family}|${flags}|${text}'
}
