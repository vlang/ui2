module ui2

fn test_symbol_names_resolve_to_material_icons_glyphs() {
	assert symbol_known('magnifyingglass')
	assert symbol_glyph('magnifyingglass') == ''
	assert !symbol_known('no.such.symbol')
	assert symbol_glyph('no.such.symbol') == symbol_unknown_glyph
	names := symbol_names()
	assert names.len == symbol_glyphs.len
	for i, name in names {
		if i > 0 {
			assert names[i - 1] < name
		}
		glyph := symbol_glyph(name).runes()
		assert glyph.len == 1, name
		// Material Icons keeps its glyphs in the Private Use Area.
		assert glyph[0] >= 0xe000 && glyph[0] <= 0xf8ff, name
	}
}

fn test_symbol_name_only_accepts_symbol_paths() {
	assert (symbol_name('symbol:star') or { '' }) == 'star'
	for path in ['star', 'symbol:', 'assets/symbol:star.png', ''] {
		assert (symbol_name(path) or { 'none' }) == 'none'
	}
}
