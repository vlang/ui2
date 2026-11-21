module ui2

import os

// The shipped example sheets must always parse and lint clean: they are the
// first thing users copy from.

const gallery_sheet_source = $embed_file('../examples/stylesheet_gallery/gallery.vss').to_string()

fn test_shipped_gallery_sheet_parses_and_lints() {
	sheet := parse_stylesheet(gallery_sheet_source)!
	assert sheet.rules.len > 10
	notes := stylesheet_lint(sheet)
	assert !notes.has_errors(), notes.errors.join('; ')
}

// The plugins example registers these hooks in its main.v; the test mirrors
// the parts the sheet needs so it can load the shipped files from disk.
fn embed_test_supports(name string, prelude string, body string) !string {
	_ = name
	feature := prelude.trim_space().trim_string_left('(').trim_string_right(')').trim_space()
	if feature.to_lower() in ['container-queries', 'color-mix', 'nesting'] {
		return '@media all { ${body} }'
	}
	return ''
}

fn embed_test_theme(name string, inner string, ctx StyleLengthCtx) !StyleFnValue {
	_ = name
	_ = inner
	_ = ctx
	return StyleFnValue(ComponentThemeToken{
		color: 0x2563eb
	})
}

fn embed_test_has_tooltip(pseudo StylePseudo, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool {
	return el.tooltip.len > 0
}

fn test_shipped_plugins_sheet_loads() {
	register_style_plugin(StylePlugin{
		name:           'embed-demo-kit'
		functions:      ['theme']
		eval_function:  embed_test_theme
		at_rules:       ['supports']
		expand_at_rule: embed_test_supports
		pseudos:        ['--has-tooltip']
		match_pseudo:   embed_test_has_tooltip
	})
	path := os.join_path(os.dir(@FILE), '..', 'examples', 'stylesheet_plugins', 'theme.vss')
	sheet := load_stylesheet(path) or {
		unregister_style_plugin('embed-demo-kit')
		panic(err)
	}
	unregister_style_plugin('embed-demo-kit')
	// The @supports block expands to `@media all`, which must match.
	supported := sheet.rules.filter(it.media.len == 1 && it.media[0].media_type == 'all')
	assert supported.len == 1
	assert media_list_matches(supported[0].media, StyleQueryEnv{
		width:  640
		height: 480
	})
}
