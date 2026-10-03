@[has_globals]
module ui2

import fontstash
import os
import os.font
import sync

// A CPU-only fontstash context supplies real glyph advances before a window
// exists. It shares UI2's font discovery, point conversion and fallback chain;
// no GPU, gg context, font parser or extra dependency is involved.
@[heap]
struct LayoutMeasureFonts {
	mutex &sync.Mutex = sync.new_mutex()
mut:
	stash     &fontstash.Context = unsafe { nil }
	regular   string
	bold      string
	index     map[string]string
	indexed   bool
	font_ids  map[string]int
	metrics   map[string]FontMetrics
	fallbacks []int
}

__global g_layout_measure_fonts = &LayoutMeasureFonts{}

fn (mut fonts LayoutMeasureFonts) initialize() ! {
	if fonts.stash != unsafe { nil } { return }
	regular, bold := font_paths()
	if regular.len == 0 {
		return error('intrinsic text sizing needs an installed or bundled font; supply LayoutTextMeasureFn')
	}
	fonts.stash = fontstash.create_internal(&C.FONSparams{ width: 256, height: 256 })
	if fonts.stash == unsafe { nil } {
		return error('could not create CPU font measurement context')
	}
	fonts.regular = regular
	fonts.bold = if bold.len > 0 { bold } else { regular }
	for path in font_symbol_paths() {
		data := os.read_bytes(path) or { continue }
		id := fonts.stash.add_font_mem(path, data, true)
		if id != fontstash.invalid {
			fonts.fallbacks << id
			fonts.font_ids[path] = id
		}
	}
}

fn (mut fonts LayoutMeasureFonts) path(style TextStyle) string {
	if style.font_family.len > 0 {
		if os.is_file(style.font_family) { return style.font_family }
		if !fonts.indexed {
			mut dirs := font_bundle_dirs()
			dirs << font_system_dirs()
			fonts.index = font_index(dirs)
			fonts.indexed = true
		}
		mut path := font_lookup(fonts.index, style.font_family, style.bold, style.italic)
		if path.len == 0 && (style.bold || style.italic) {
			path = font_lookup(fonts.index, style.font_family, false, false)
		}
		if path.len == 0 && font_is_mono_family(style.font_family) {
			path = font_mono_path(fonts.index, style.font_family, style.bold, style.italic)
		}
		if path.len > 0 { return path }
	}
	if style.bold { return fonts.bold }
	if style.italic {
		italic := font.get_path_variant(fonts.regular, .italic)
		if os.is_file(italic) { return italic }
	}
	return fonts.regular
}

fn (mut fonts LayoutMeasureFonts) load(path string) !int {
	if id := fonts.font_ids[path] { return id }
	data := os.read_bytes(path)!
	id := fonts.stash.add_font_mem(path, data, true)
	if id == fontstash.invalid { return error('cannot measure font `${path}`') }
	for fallback in fonts.fallbacks {
		if fallback != id { fonts.stash.add_fallback_font(id, fallback) }
	}
	fonts.font_ids[path] = id
	return id
}

fn layout_measure_cpu_text(text string, style TextStyle, max_width f64) !LayoutSize {
	return layout_measure_cpu_fontstash(text, style, max_width, false)
}

fn layout_measure_cpu_fontstash(text string, style TextStyle, max_width f64, text_area bool) !LayoutSize {
	mut fonts := g_layout_measure_fonts
	fonts.mutex.lock()
	defer { fonts.mutex.unlock() }
	fonts.initialize()!
	path := fonts.path(style)
	id := fonts.load(path)!
	metrics := fonts.metrics[path] or {
		loaded := font_file_metrics(path) or { FontMetrics{} }
		fonts.metrics[path] = loaded
		loaded
	}
	stash := fonts.stash
	stash.set_font(id)
	stash.set_size(f32(int(font_render_size(style.size, metrics) + 0.5)))
	stash.set_align(int(fontstash.Align.left) | int(fontstash.Align.baseline))
	if text_area {
		return layout_measure_text_area_lines(text, style, max_width, font_line_height(style.size), fn [stash] (line string) f64 {
			mut glyph_bounds := [4]f32{}
			return f64(stash.text_bounds(0, 0, line, &glyph_bounds[0]))
		})
	}
	return layout_measure_text_lines(text, style, max_width, font_line_height(style.size), fn [stash] (line string) f64 {
		mut glyph_bounds := [4]f32{}
		return f64(stash.text_bounds(0, 0, line, &glyph_bounds[0]))
	})
}
