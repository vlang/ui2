module ui2

import os

// synthetic_font builds the smallest file parse_font_metrics accepts: an sfnt
// header, a table directory, and the two tables it reads.
fn synthetic_font(units_per_em int, ascender int, descender int) []u8 {
	head_offset := 44
	hhea_offset := 96
	mut data := []u8{len: 160}
	put_u32(mut data, 0, 0x00010000)
	put_u16(mut data, 4, 2)
	copy_tag(mut data, 12, 'head')
	put_u32(mut data, 20, head_offset)
	put_u32(mut data, 24, 54)
	copy_tag(mut data, 28, 'hhea')
	put_u32(mut data, 36, hhea_offset)
	put_u32(mut data, 40, 36)
	put_u16(mut data, head_offset + 18, units_per_em)
	put_u16(mut data, hhea_offset + 4, ascender & 0xffff)
	put_u16(mut data, hhea_offset + 6, descender & 0xffff)
	return data
}

fn put_u16(mut data []u8, offset int, value int) {
	data[offset] = u8((value >> 8) & 0xff)
	data[offset + 1] = u8(value & 0xff)
}

fn put_u32(mut data []u8, offset int, value int) {
	data[offset] = u8((value >> 24) & 0xff)
	data[offset + 1] = u8((value >> 16) & 0xff)
	data[offset + 2] = u8((value >> 8) & 0xff)
	data[offset + 3] = u8(value & 0xff)
}

fn copy_tag(mut data []u8, offset int, tag string) {
	for i, c in tag {
		data[offset + i] = c
	}
}

fn test_font_metrics_come_from_the_head_and_hhea_tables() {
	metrics := parse_font_metrics(synthetic_font(1000, 1069, -293))!
	assert metrics.units_per_em == 1000
	assert metrics.ascender == 1069
	assert metrics.descender == -293
}

fn test_font_metrics_reject_a_file_that_is_not_a_font() {
	if _ := parse_font_metrics('not a font at all, just bytes'.bytes()) {
		assert false, 'a plain text file was accepted as a font'
	}
	if _ := parse_font_metrics([]u8{}) {
		assert false, 'an empty file was accepted as a font'
	}
	mut headerless := synthetic_font(2048, 1900, -500)
	copy_tag(mut headerless, 12, 'cmap')
	if _ := parse_font_metrics(headerless) {
		assert false, 'a font without a head table was accepted'
	}
}

fn test_font_metrics_reject_zero_vertical_metrics() {
	if _ := parse_font_metrics(synthetic_font(0, 1900, -500)) {
		assert false, 'a font with no em square was accepted'
	}
	if _ := parse_font_metrics(synthetic_font(2048, 0, 0)) {
		assert false, 'a font with no ascender or descender was accepted'
	}
}

// Fontstash asks for the ascender-to-descender height, so the same declared
// size has to be stretched by however much taller than the em square that is.
fn test_render_size_scales_the_em_square_by_the_font_metrics() {
	roboto := FontMetrics{
		units_per_em: 2048
		ascender: 1900
		descender: -500
	}
	noto := FontMetrics{
		units_per_em: 1000
		ascender: 1069
		descender: -293
	}
	assert font_render_size(15, roboto) == font_em_pixels(15) * 2400.0 / 2048.0
	assert font_render_size(15, noto) == font_em_pixels(15) * 1362.0 / 1000.0
	// The two fonts differ by more than a third at the same declared size,
	// which is exactly the drift this conversion removes.
	assert font_render_size(15, noto) > font_render_size(15, roboto) * 1.15
}

fn test_render_size_falls_back_to_the_em_square_for_unusable_metrics() {
	broken := FontMetrics{
		units_per_em: 0
		ascender: 0
		descender: 0
	}
	assert font_render_size(15, broken) == font_em_pixels(15)
}

// Windows resolves a point at 96 dpi and AppKit at 72. The custom renderer
// follows whichever platform it is drawing on, so Linux stops rendering the
// same declared size a third smaller than Windows does.
fn test_point_sizes_follow_the_platform_convention() {
	$if linux || windows {
		assert font_em_pixels(15) == 20.0
		assert font_line_height(15) == 25.0
	} $else {
		assert font_em_pixels(15) == 15.0
		assert font_line_height(15) == 18.75
	}
}

fn test_font_key_ignores_spacing_case_and_punctuation() {
	assert font_key('Times New Roman') == 'timesnewroman'
	assert font_key('TimesNewRoman') == 'timesnewroman'
	assert font_key('DejaVu Sans-Bold') == 'dejavusansbold'
	assert font_key('Ubuntu-R') == 'ubuntur'
	assert font_key('  ') == ''
}

fn test_font_variant_keys_cover_the_usual_file_naming() {
	assert font_variant_keys('Roboto', false, false) == ['roboto', 'robotoregular', 'robotor',
		'robotobook']
	assert font_variant_keys('Roboto', true, false) == ['robotobold', 'robotobd', 'robotob']
	assert font_variant_keys('Arial', false, true) == ['arialitalic', 'arialoblique', 'ariali']
	assert font_variant_keys('Arial', true, true) == ['arialbolditalic', 'arialboldoblique', 'arialbi',
		'arialz']
	assert font_variant_keys('', false, false) == []
}

fn test_font_lookup_matches_each_foundrys_variant_suffix() {
	index := {
		'dejavusans':      '/fonts/DejaVuSans.ttf'
		'dejavusansbold':  '/fonts/DejaVuSans-Bold.ttf'
		'ubuntur':         '/fonts/Ubuntu-R.ttf'
		'ubuntub':         '/fonts/Ubuntu-B.ttf'
		'arial':           '/fonts/arial.ttf'
		'arialbd':         '/fonts/arialbd.ttf'
		'notosansregular': '/fonts/NotoSans-Regular.ttf'
	}
	assert font_lookup(index, 'DejaVu Sans', false, false) == '/fonts/DejaVuSans.ttf'
	assert font_lookup(index, 'DejaVu Sans', true, false) == '/fonts/DejaVuSans-Bold.ttf'
	assert font_lookup(index, 'Ubuntu', false, false) == '/fonts/Ubuntu-R.ttf'
	assert font_lookup(index, 'Ubuntu', true, false) == '/fonts/Ubuntu-B.ttf'
	assert font_lookup(index, 'Arial', true, false) == '/fonts/arialbd.ttf'
	assert font_lookup(index, 'Noto Sans', false, false) == '/fonts/NotoSans-Regular.ttf'
	assert font_lookup(index, 'Helvetica', false, false) == ''
	assert font_lookup(index, 'Ubuntu', false, true) == ''
}

fn font_test_dir(name string, files []string) string {
	dir := os.join_path(os.temp_dir(), 'ui2_font_test', name)
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir) or { panic(err) }
	for file in files {
		os.write_file(os.join_path(dir, file), 'x') or { panic(err) }
	}
	return dir
}

fn test_font_index_skips_variable_fonts_and_collections() {
	dir := font_test_dir('index', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto[wdth,wght].ttf',
		'Inter-VariableFont_opsz.ttf', 'Helvetica.ttc', 'notes.txt'])
	defer {
		os.rmdir_all(dir) or {}
	}
	index := font_index([dir])
	assert index.keys().len == 2
	assert index['robotoregular'] == os.join_path(dir, 'Roboto-Regular.ttf')
	assert index['robotobold'] == os.join_path(dir, 'Roboto-Bold.ttf')
}

fn test_font_pick_prefers_a_known_ui_family() {
	dir := font_test_dir('pick', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'AaaSans.ttf'])
	defer {
		os.rmdir_all(dir) or {}
	}
	regular, bold := font_pick([dir])
	assert regular == os.join_path(dir, 'Roboto-Regular.ttf')
	assert bold == os.join_path(dir, 'Roboto-Bold.ttf')
}

fn test_font_pick_settles_for_any_upright_sans_face() {
	dir := font_test_dir('fallback', ['ZzzSans.ttf', 'ZzzSans-Bold.ttf', 'AaaMono.ttf'])
	defer {
		os.rmdir_all(dir) or {}
	}
	regular, bold := font_pick([dir])
	assert regular == os.join_path(dir, 'ZzzSans.ttf')
	assert bold == ''
}

fn test_font_pick_reports_nothing_for_an_empty_tree() {
	dir := font_test_dir('empty', [])
	defer {
		os.rmdir_all(dir) or {}
	}
	regular, bold := font_pick([dir])
	assert regular == ''
	assert bold == ''
}

fn test_ui2_font_overrides_the_chosen_family() {
	dir := font_test_dir('env', ['Custom.ttf', 'Custom-Bold.ttf'])
	defer {
		os.rmdir_all(dir) or {}
		os.setenv('UI2_FONT', '', true)
		os.setenv('UI2_FONT_BOLD', '', true)
	}
	os.setenv('UI2_FONT', os.join_path(dir, 'Custom.ttf'), true)
	os.setenv('UI2_FONT_BOLD', os.join_path(dir, 'Custom-Bold.ttf'), true)
	regular, bold := font_paths()
	assert regular == os.join_path(dir, 'Custom.ttf')
	assert bold == os.join_path(dir, 'Custom-Bold.ttf')

	os.setenv('UI2_FONT_BOLD', os.join_path(dir, 'Missing-Bold.ttf'), true)
	_, missing_bold := font_paths()
	assert missing_bold == ''
}

// The metrics of a real font file, so the parser is checked against something
// a foundry shipped rather than only against the bytes the test writes.
fn test_font_metrics_read_an_installed_font() {
	for path in ['/System/Library/Fonts/Supplemental/Arial.ttf',
		'/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 'C:\\Windows\\Fonts\\segoeui.ttf'] {
		if !os.is_file(path) {
			continue
		}
		metrics := font_file_metrics(path)!
		assert metrics.units_per_em >= 16
		assert metrics.ascender > 0
		assert metrics.descender < 0
		// Every text face is taller than its em square once the descender is
		// counted, which is why the conversion is needed at all.
		assert metrics.ascender - metrics.descender > metrics.units_per_em
		return
	}
}

// The font ui2 ships is the one the custom renderer draws with on every
// platform, so it has to be present, readable by the same parser the renderer
// uses, and reachable without anything installed on the machine.
fn test_the_bundled_roboto_is_what_the_renderer_picks() {
	regular, bold := font_pick(font_bundle_dirs())
	assert os.file_name(regular) == 'Roboto-Regular.ttf'
	assert os.file_name(bold) == 'Roboto-Bold.ttf'

	metrics := font_file_metrics(regular)!
	assert metrics.units_per_em == 2048
	assert metrics.ascender == 1900
	assert metrics.descender == -500

	// gg derives the italic face from the regular one by name.
	dir := os.dir(regular)
	for face in ['Roboto-Italic.ttf', 'Roboto-BoldItalic.ttf'] {
		font_file_metrics(os.join_path(dir, face))!
	}
	assert os.is_file(os.join_path(dir, 'Roboto-OFL.txt'))
}

// gg fills its own mono slot by rewriting `-Regular` to `Mono-Regular` in the
// path it was given, so the two files have to keep those names and sit in the
// same directory.
fn test_the_bundled_roboto_mono_sits_where_gg_looks_for_it() {
	regular, _ := font_pick(font_bundle_dirs())
	mono := regular.replace('-Regular.ttf', 'Mono-Regular.ttf')
	assert os.file_name(mono) == 'RobotoMono-Regular.ttf'

	metrics := font_file_metrics(mono)!
	assert metrics.units_per_em == 2048
	assert metrics.ascender == 2146
	assert metrics.descender == -555

	dir := os.dir(regular)
	font_file_metrics(os.join_path(dir, 'RobotoMono-Bold.ttf'))!
	assert os.is_file(os.join_path(dir, 'RobotoMono-OFL.txt'))
}

// Roboto Mono is a third taller than Roboto between ascender and descender, so
// without the per-font conversion a mono label would draw noticeably smaller
// than the sans one beside it at the same declared size.
fn test_mono_and_sans_draw_the_same_em_square() {
	regular, _ := font_pick(font_bundle_dirs())
	sans := font_file_metrics(regular)!
	mono := font_file_metrics(regular.replace('-Regular.ttf', 'Mono-Regular.ttf'))!
	assert font_render_size(15, sans) == font_em_pixels(15) * 2400.0 / 2048.0
	assert font_render_size(15, mono) == font_em_pixels(15) * 2701.0 / 2048.0
	assert font_render_size(15, mono) > font_render_size(15, sans) * 1.1
}

fn test_mono_families_are_recognized_by_name() {
	for family in ['monospace', 'Mono', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New', 'Consolas',
		'Menlo', 'Monaco'] {
		assert font_is_mono_family(family), '${family} should read as monospace'
	}
	for family in ['Inter', 'Roboto', 'Helvetica', 'Mona Sans', 'Times New Roman'] {
		assert !font_is_mono_family(family), '${family} should not read as monospace'
	}
}

fn test_an_unavailable_mono_family_falls_back_to_another_mono() {
	dir := font_test_dir('mono', ['Roboto-Regular.ttf', 'RobotoMono-Regular.ttf',
		'RobotoMono-Bold.ttf'])
	defer {
		os.rmdir_all(dir) or {}
	}
	index := font_index([dir])
	// Nothing here is called Consolas, but the request is still for a
	// fixed-pitch face.
	assert font_mono_path(index, 'Consolas', false, false) == os.join_path(dir, 'RobotoMono-Regular.ttf')
	assert font_mono_path(index, 'monospace', true, false) == os.join_path(dir, 'RobotoMono-Bold.ttf')
	// No italic mono is installed, so the upright one is used rather than the
	// proportional default.
	assert font_mono_path(index, 'Courier New', false, true) == os.join_path(dir, 'RobotoMono-Regular.ttf')
	// A family that is present wins over the fallback list.
	assert font_mono_path(index, 'Roboto Mono', false, false) == os.join_path(dir, 'RobotoMono-Regular.ttf')
}

fn test_mono_fallback_reports_nothing_when_no_mono_face_exists() {
	dir := font_test_dir('nomono', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'])
	defer {
		os.rmdir_all(dir) or {}
	}
	assert font_mono_path(font_index([dir]), 'Consolas', false, false) == ''
}

// ── Symbols ────────────────────────────────────────────────────────

// The faces ui2 ships are what keep a triangle, an arrow, a check mark or an
// emoji from coming out as an empty box on a machine with nothing installed, so
// they have to be present, readable by the same parser the renderer uses, and
// searched before anything else. Symbols come before emoji: the two overlap
// around the dingbats, and the text-weight glyph is the one to draw.
fn test_the_bundled_faces_lead_the_fallback_chain() {
	paths := font_symbol_paths()
	assert paths.len >= 3
	assert os.file_name(paths[0]) == 'MaterialIcons-Regular.ttf'
	assert os.file_name(paths[1]) == 'NotoSansSymbols2-Regular.ttf'
	assert os.file_name(paths[2]) == 'NotoEmoji-Regular.ttf'
	for path in paths[..3] {
		font_file_metrics(path)!
	}
	dir := os.dir(paths[0])
	assert os.is_file(os.join_path(dir, 'MaterialIcons-LICENSE.txt'))
	assert os.is_file(os.join_path(dir, 'NotoSansSymbols2-OFL.txt'))
	assert os.is_file(os.join_path(dir, 'NotoEmoji-OFL.txt'))
}

// Noto Emoji is drawn at the size Roboto is, and the renderer resolves a point
// size against the metrics of the text font alone, so an emoji only sits right
// on the line while the two agree about the em square.
fn test_the_bundled_emoji_face_shares_robotos_metrics() {
	regular, _ := font_pick(font_bundle_dirs())
	text := font_file_metrics(regular)!
	emoji := font_file_metrics(os.join_path(os.dir(regular), 'NotoEmoji-Regular.ttf'))!
	assert emoji.units_per_em == text.units_per_em
	assert emoji.ascender == text.ascender
	assert emoji.descender == text.descender
}

// Every face in the chain is read into memory and kept there for as long as the
// window lives, so the machine contributes one at most. The point of the tail
// is to cover the blocks Noto Sans Symbols 2 leaves out, not to load every
// symbol font that happens to be installed.
fn test_the_symbol_chain_takes_at_most_one_installed_face() {
	bundled := font_index(font_bundle_dirs())
	mut shipped := 0
	for family in font_symbol_fallback_families() {
		if font_lookup(bundled, family, false, false) != '' {
			shipped++
		}
	}
	assert shipped > 0
	assert font_symbol_paths().len <= shipped + 1
}

fn test_ui2_font_symbols_is_searched_before_the_bundled_face() {
	regular, _ := font_pick(font_bundle_dirs())
	os.setenv('UI2_FONT_SYMBOLS', regular, true)
	defer {
		os.unsetenv('UI2_FONT_SYMBOLS')
	}
	paths := font_symbol_paths()
	assert paths[0] == regular
	assert os.file_name(paths[1]) == 'MaterialIcons-Regular.ttf'

	// A path that names no file is ignored rather than searched.
	os.setenv('UI2_FONT_SYMBOLS', os.join_path(os.temp_dir(), 'ui2_no_such_font.ttf'), true)
	assert os.file_name(font_symbol_paths()[0]) == 'MaterialIcons-Regular.ttf'
}

// A face made of symbols or emoji has no letters in it, so a window that settled
// on one for its text would draw every word as a row of empty boxes. The color
// emoji faces are named for that reason alone: they are never searched for a
// missing glyph, since stb_truetype cannot read a bitmap or a layered one.
fn test_a_symbol_face_is_never_settled_on_for_text() {
	for family in ['Material Icons', 'MaterialIcons-Regular', 'Noto Sans Symbols 2',
		'NotoSansSymbols2-Regular', 'Noto Sans Symbols', 'Segoe UI Symbol', 'Apple Symbols', 'Symbola',
		'Noto Emoji', 'NotoEmoji-Regular', 'Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'] {
		assert font_is_symbol_family(family), '${family} should read as a symbol face'
	}
	for family in ['Roboto', 'Noto Sans', 'DejaVu Sans', 'Inter', 'Arial', ''] {
		assert !font_is_symbol_family(family), '${family} should read as a text face'
	}

	dir := font_test_dir('symbols', ['MaterialIcons-Regular.ttf', 'NotoSansSymbols2-Regular.ttf',
		'NotoEmoji-Regular.ttf', 'Roboto-Regular.ttf'])
	defer {
		os.rmdir_all(dir) or {}
	}
	// The symbol file sorts first and its name says "sans", so nothing but that
	// check keeps the search from settling on it.
	assert font_fallback(font_index([dir])) == os.join_path(dir, 'Roboto-Regular.ttf')

	only_symbols := font_test_dir('symbols_only', ['MaterialIcons-Regular.ttf',
		'NotoSansSymbols2-Regular.ttf', 'NotoEmoji-Regular.ttf'])
	defer {
		os.rmdir_all(only_symbols) or {}
	}
	assert font_fallback(font_index([only_symbols])) == ''
	regular, bold := font_pick([only_symbols])
	assert regular == ''
	assert bold == ''
}
