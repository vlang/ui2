// ui2 declares text sizes in points, the unit both native backends take. The
// custom renderer draws through fontstash, which sizes a glyph by the font's
// ascender-to-descender height instead of by its em square, so the very same
// declared size comes out a different height for every font file. That is why
// a Linux window reads smaller than the Windows one, and why it changes from
// distribution to distribution: `fc-match` hands gg whatever sans face sorts
// first. Resolving the point size against the metrics of the font actually
// being drawn, and picking that font on purpose, makes the two match.
module ui2

import os

// FontMetrics holds the `head` and `hhea` values stb_truetype scales glyphs
// with. The defaults describe Roboto, so a font file that cannot be read still
// sizes text sensibly instead of collapsing to the em square.
pub struct FontMetrics {
pub:
	units_per_em int = 2048
	ascender     int = 1900
	descender    int = -500
}

// ── Point sizes ────────────────────────────────────────────────────

// font_pixels_per_point resolves a point the way the platform's own toolkit
// does. Win32 and the Linux desktops render type at 96 dpi, AppKit and UIKit
// at 72, so a declared size lines up with the native controls beside it.
fn font_pixels_per_point() f64 {
	$if linux || windows {
		return 96.0 / 72.0
	} $else {
		return 1.0
	}
}

// font_em_pixels is the height of the em square that `points` sized text draws
// at, which is the size every native backend is given.
fn font_em_pixels(points f64) f64 {
	return points * font_pixels_per_point()
}

// font_render_size converts a point size into the size fontstash expects: the
// ascender-to-descender height rather than the em square.
fn font_render_size(points f64, metrics FontMetrics) f64 {
	span := metrics.ascender - metrics.descender
	if span <= 0 || metrics.units_per_em <= 0 {
		return font_em_pixels(points)
	}
	return font_em_pixels(points) * f64(span) / f64(metrics.units_per_em)
}

// font_line_height spaces the lines of a multi-line label. Fontstash reports a
// font's own line height only after a draw, so the em square plus the usual
// quarter of leading is what keeps the lines apart.
fn font_line_height(points f64) f64 {
	return font_em_pixels(points) * 1.25
}

// ── Font files ─────────────────────────────────────────────────────

fn font_u16(data []u8, offset int) int {
	if offset < 0 || offset + 2 > data.len {
		return 0
	}
	return int(u32(data[offset]) << 8 | u32(data[offset + 1]))
}

fn font_i16(data []u8, offset int) int {
	value := font_u16(data, offset)
	return if value >= 0x8000 { value - 0x10000 } else { value }
}

fn font_u32(data []u8, offset int) int {
	if offset < 0 || offset + 4 > data.len {
		return 0
	}
	// Table offsets and the sfnt version all sit well inside `int`.
	return int(u32(data[offset]) << 24 | u32(data[offset + 1]) << 16 | u32(data[offset + 2]) << 8 | u32(data[offset + 3]))
}

fn font_tag(data []u8, offset int) string {
	if offset < 0 || offset + 4 > data.len {
		return ''
	}
	return data[offset..offset + 4].bytestr()
}

// parse_font_metrics walks a font's table directory for `head` and `hhea`.
// Those two tables are all stb_truetype uses to scale a glyph, so they are all
// the renderer has to read to size text the way the native backends do.
fn parse_font_metrics(data []u8) !FontMetrics {
	// A collection keeps its own header up front and the first font's table
	// directory further in.
	base := if font_tag(data, 0) == 'ttcf' { font_u32(data, 12) } else { 0 }
	tag := font_tag(data, base)
	if tag != 'OTTO' && tag != 'true' && font_u32(data, base) != 0x00010000 {
		return error('not a TrueType or OpenType font')
	}
	num_tables := font_u16(data, base + 4)
	mut head := 0
	mut hhea := 0
	for i in 0 .. num_tables {
		record := base + 12 + i * 16
		match font_tag(data, record) {
			'head' {
				head = font_u32(data, record + 8)
			}
			'hhea' {
				hhea = font_u32(data, record + 8)
			}
			else {}
		}
	}
	if head == 0 || hhea == 0 {
		return error('font is missing its head or hhea table')
	}
	metrics := FontMetrics{
		units_per_em: font_u16(data, head + 18)
		ascender: font_i16(data, hhea + 4)
		descender: font_i16(data, hhea + 6)
	}
	if metrics.units_per_em <= 0 || metrics.ascender - metrics.descender <= 0 {
		return error('font has no usable vertical metrics')
	}
	return metrics
}

// font_file_metrics reads the metrics of the font stored at `path`.
fn font_file_metrics(path string) !FontMetrics {
	return parse_font_metrics(os.read_bytes(path)!)!
}

// font_key normalizes a family or file name down to letters and digits, so
// 'Times New Roman', 'TimesNewRoman.ttf' and 'timesnewroman' all match.
fn font_key(name string) string {
	mut out := []u8{cap: name.len}
	for c in name.to_lower() {
		if (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) {
			out << c
		}
	}
	return out.bytestr()
}

// font_variant_keys lists the file names a family uses for one weight and
// slant, in the order they are worth trying. Foundries disagree about the
// suffix: Roboto ships `-Bold`, Ubuntu `-B`, Arial `bd`.
fn font_variant_keys(family string, bold bool, italic bool) []string {
	base := font_key(family)
	if base.len == 0 {
		return []
	}
	if bold && italic {
		return [base + 'bolditalic', base + 'boldoblique', base + 'bi', base + 'z']
	}
	if bold {
		return [base + 'bold', base + 'bd', base + 'b']
	}
	if italic {
		return [base + 'italic', base + 'oblique', base + 'i']
	}
	return [base, base + 'regular', base + 'r', base + 'book']
}

// font_index maps every static font file under `dirs` to its normalized name.
// Variable fonts are left out on purpose: stb_truetype, the rasterizer
// fontstash builds with, ignores the `fvar` and `gvar` tables, so a variable
// file would draw every weight at its default instance and bold text would
// stop being bold.
fn font_index(dirs []string) map[string]string {
	mut index := map[string]string{}
	for dir in dirs {
		if !os.is_dir(dir) {
			continue
		}
		for ext in ['.ttf', '.otf'] {
			for path in os.walk_ext(dir, ext) {
				name := os.file_name(path).all_before_last('.')
				if name.contains('[') || name.to_lower().contains('variablefont') {
					continue
				}
				key := font_key(name)
				if key.len > 0 && key !in index {
					index[key] = path
				}
			}
		}
	}
	return index
}

// font_lookup returns the file `family` is drawn from, or '' when this machine
// does not have it.
fn font_lookup(index map[string]string, family string, bold bool, italic bool) string {
	for key in font_variant_keys(family, bold, italic) {
		if path := index[key] {
			return path
		}
	}
	return ''
}

// font_bundle_dirs are the places an application ships its own font in, so a
// binary can look the same on a machine with nothing useful installed.
fn font_bundle_dirs() []string {
	exe_dir := os.dir(os.executable())
	return [
		os.join_path(exe_dir, 'fonts'),
		os.join_path(exe_dir, 'assets', 'fonts'),
		os.join_path(@VMODROOT, 'assets', 'fonts'),
	]
}

// font_system_dirs are the font trees the platform installs into.
fn font_system_dirs() []string {
	home := os.home_dir()
	$if android {
		return ['/system/fonts', '/data/fonts']
	} $else $if linux {
		return [
			os.join_path(home, '.local', 'share', 'fonts'),
			os.join_path(home, '.fonts'),
			'/usr/local/share/fonts',
			'/usr/share/fonts',
			// The host's fonts as a Flatpak sandbox sees them.
			'/run/host/fonts',
		]
	} $else $if macos {
		return [os.join_path(home, 'Library', 'Fonts'), '/Library/Fonts', '/System/Library/Fonts']
	} $else $if windows {
		windir := os.getenv('WINDIR')
		return if windir.len > 0 { [os.join_path(windir, 'Fonts')] } else { [] }
	} $else {
		return []
	}
}

// font_preferences ranks the faces worth defaulting to. Inter and Roboto read
// closest to Segoe UI, the font the Windows backend draws with; the rest are
// the sans faces a desktop is nearly certain to already have.
fn font_preferences() []string {
	$if windows {
		return ['Segoe UI', 'Inter', 'Roboto', 'Arial']
	} $else $if macos {
		return ['SFNS', 'SFNSText', 'Inter', 'Roboto', 'Helvetica']
	} $else {
		return ['Inter', 'Roboto', 'Noto Sans', 'Open Sans', 'DejaVu Sans', 'Liberation Sans',
			'Ubuntu', 'Cantarell', 'FreeSans', 'Arial']
	}
}

// font_mono_preferences ranks the monospace faces to fall back to when an
// element asks for one the machine does not have. `ui2` ships Roboto Mono, so
// the first entry is always there unless the application replaced the bundle.
fn font_mono_preferences() []string {
	return ['Roboto Mono', 'JetBrains Mono', 'DejaVu Sans Mono', 'Liberation Mono', 'Noto Sans Mono',
		'Ubuntu Mono', 'Cascadia Mono', 'Consolas', 'Menlo', 'Courier New']
}

// ── Symbols ────────────────────────────────────────────────────────

// font_symbol_families ranks the faces that carry symbols rather than the
// letters a paragraph is set in. A text face only draws the scripts it was cut
// for: the bundled Roboto stops at 927 code points, so the triangles, arrows
// and check marks an interface labels its rows with land on glyph 0, the empty
// box. `ui2` ships Noto Sans Symbols 2 and Noto Emoji for that reason, so those
// boxes are gone with nothing installed on the machine; the rest are the symbol
// faces the three desktops come with. Symbols are looked for before emoji: the
// two overlap around the dingbats, and a ✔ beside a line of text should be the
// text-weight one rather than the emoji.
fn font_symbol_families() []string {
	return ['Material Icons', 'Noto Sans Symbols 2', 'Noto Sans Symbols', 'Segoe UI Symbol',
		'Apple Symbols', 'Symbola', 'Noto Emoji']
}

// font_color_emoji_families lists the faces that keep their emoji as bitmaps or
// as stacks of colored layers. `stb_truetype`, the rasterizer fontstash builds
// with, reads neither, and the outline such a face leaves at the base glyph is
// empty, so searching one would trade the empty box for an empty space. They
// are named only so the renderer does not settle on one for its text.
fn font_color_emoji_families() []string {
	return ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji', 'Twemoji Mozilla', 'JoyPixels']
}

// font_symbol_fallback_families ranks every face worth looking in for a glyph
// the text font does not have. The symbol faces come first, then the text faces
// with a wide enough repertoire to cover what Noto Sans Symbols 2 leaves out —
// the arrows at U+2190 and the box drawing at U+2500, most visibly.
fn font_symbol_fallback_families() []string {
	mut families := font_symbol_families()
	$if windows {
		families << ['Arial Unicode MS', 'Lucida Sans Unicode']
	} $else $if macos {
		families << ['Arial Unicode MS']
	} $else {
		families << ['DejaVu Sans', 'FreeSerif', 'Noto Sans']
	}
	return families
}

// font_is_symbol_family reports whether a face holds symbols or emoji instead
// of letters, so the renderer never settles on it for its text font: a window
// drawn in Noto Sans Symbols 2 would be nothing but empty boxes.
fn font_is_symbol_family(family string) bool {
	key := font_key(family)
	if key.len == 0 {
		return false
	}
	mut candidates := font_symbol_families()
	candidates << font_color_emoji_families()
	for candidate in candidates {
		if key.starts_with(font_key(candidate)) {
			return true
		}
	}
	return false
}

// font_symbol_paths lists the files to search for a glyph the text font has no
// outline for, in the order they are searched. Everything the application ships
// comes first, and then at most one face off the machine, so an installed
// symbol font can cover what the bundle does not without the window holding
// another few megabytes of glyphs it will never draw. `UI2_FONT_SYMBOLS` names
// a file to put ahead of both.
fn font_symbol_paths() []string {
	families := font_symbol_fallback_families()
	mut paths := []string{}
	env_symbols := os.getenv('UI2_FONT_SYMBOLS')
	if env_symbols.len > 0 && os.is_file(env_symbols) {
		paths << env_symbols
	}
	bundled := font_index(font_bundle_dirs())
	for family in families {
		path := font_lookup(bundled, family, false, false)
		if path != '' && path !in paths {
			paths << path
		}
	}
	installed := font_first_available(font_index(font_system_dirs()), families, false, false)
	if installed != '' && installed !in paths {
		paths << installed
	}
	return paths
}

// font_is_mono_family reports whether a declared family asks for a fixed-pitch
// face, so an unavailable one falls back to another monospace rather than to
// the proportional default. It covers the CSS generic names and the faces a
// cross-platform application usually names.
fn font_is_mono_family(family string) bool {
	key := font_key(family)
	if key.ends_with('mono') || key.contains('monospace') {
		return true
	}
	return key in ['courier', 'couriernew', 'consolas', 'menlo', 'monaco', 'terminal']
}

// font_first_available returns the file for the first of `families` that this
// machine has, in the requested weight and slant.
fn font_first_available(index map[string]string, families []string, bold bool, italic bool) string {
	for family in families {
		path := font_lookup(index, family, bold, italic)
		if path != '' {
			return path
		}
	}
	return ''
}

// font_fallback settles for whatever upright sans face is installed once none
// of the preferred families turned up, so the size math still has real metrics
// to work from.
fn font_fallback(index map[string]string) string {
	mut keys := index.keys()
	keys.sort()
	for pass in 0 .. 2 {
		for key in keys {
			if key.contains('bold') || key.contains('italic') || key.contains('oblique') {
				continue
			}
			if font_is_symbol_family(key) {
				continue
			}
			if pass == 0 && (!key.contains('sans') || key.contains('mono')) {
				continue
			}
			return index[key]
		}
	}
	return ''
}

// font_pick chooses the first preferred family present in `dirs` and returns
// its regular and bold files.
fn font_pick(dirs []string) (string, string) {
	index := font_index(dirs)
	if index.len == 0 {
		return '', ''
	}
	for family in font_preferences() {
		regular := font_lookup(index, family, false, false)
		if regular != '' {
			return regular, font_lookup(index, family, true, false)
		}
	}
	return font_fallback(index), ''
}

// font_mono_path returns the monospace file to draw `family` with, falling back
// through the preferred mono faces when the machine has no such family. gg
// keeps a mono slot of its own, but sizes it two pixels smaller than it is
// asked for, so the renderer resolves a path here instead of using it.
fn font_mono_path(index map[string]string, family string, bold bool, italic bool) string {
	mut families := [family]
	families << font_mono_preferences()
	path := font_first_available(index, families, bold, italic)
	if path != '' {
		return path
	}
	// Roboto Mono ships no italic here, and neither do most of the system
	// faces, so an upright mono still reads better than a proportional italic.
	return font_first_available(index, families, bold, false)
}

// font_paths reports the regular and bold files the custom renderer draws with.
// `UI2_FONT` overrides everything, for a one-off comparison; after that a font
// shipped beside the binary wins over the ones the system has installed. An
// empty result leaves gg to fall back to `fc-match` as before.
fn font_paths() (string, string) {
	env_regular := os.getenv('UI2_FONT')
	if env_regular.len > 0 && os.is_file(env_regular) {
		env_bold := os.getenv('UI2_FONT_BOLD')
		return env_regular, if os.is_file(env_bold) { env_bold } else { '' }
	}
	bundled, bundled_bold := font_pick(font_bundle_dirs())
	if bundled != '' {
		return bundled, bundled_bold
	}
	return font_pick(font_system_dirs())
}
