module ui2

fn test_stylesheet_lint_clean_sheet() {
	notes := stylesheet_lint_source('Button { background: #123456; color: white; }')!
	assert !notes.has_errors()
	assert notes.warnings.len == 0
}

fn test_stylesheet_lint_unknown_property_is_error() {
	notes := stylesheet_lint_source('Button { bogus-prop: 1; }')!
	assert notes.has_errors()
	assert notes.errors.any(it.contains('bogus-prop'))
}

fn test_stylesheet_lint_layout_prop_warns() {
	notes := stylesheet_lint_source('Button { background: red; padding: 8px; }')!
	assert !notes.has_errors()
	assert notes.warnings.any(it.contains('padding'))
}

fn test_stylesheet_lint_unknown_variable_is_error() {
	notes := stylesheet_lint_source('Button { background: @nope; }')!
	assert notes.has_errors()
	assert notes.errors.any(it.contains('@nope'))
}

fn test_stylesheet_lint_known_variable_passes() {
	notes := stylesheet_lint_source('@accent: #123456;
Button { background: @accent; }')!
	assert !notes.has_errors()
}

fn test_stylesheet_lint_empty_is_error() {
	notes := stylesheet_lint_source('/* nothing here */')!
	assert notes.has_errors()
}

fn test_stylesheet_lint_custom_property_skipped() {
	notes := stylesheet_lint_source('View { --gap: 12px; } Button { background: red; }')!
	assert !notes.has_errors()
	assert notes.warnings.len == 0
}

fn test_stylesheet_lint_var_needs_tree_or_fallback() {
	tree := stylesheet_lint_source('Button { font-size: var(--pad); }')!
	assert !tree.has_errors()
	assert tree.warnings.any(it.contains('--pad'))
	fallback := stylesheet_lint_source('Button { font-size: var(--pad, red); }')!
	assert fallback.warnings.any(it.contains('--pad'))
	// @pad and --pad are different variables; matching names stay quiet.
	known := stylesheet_lint_source('--pad: 12px; Button { font-size: var(--pad); }')!
	assert known.warnings.len == 0
}

fn test_stylesheet_border_shorthand() {
	sheet := parse_stylesheet('Button { border: 2px solid #123456; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		Element{
			kind:    .button
			id:      'a'
			enabled: true
		},
	])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.border_left == 2
	assert root.children[0].box.border_color == 0x123456
}

fn test_stylesheet_background_gradient_alias() {
	sheet := parse_stylesheet('Button { background-gradient: linear-gradient(135deg, #4f46e5, #06b6d4); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		Element{
			kind:    .button
			id:      'a'
			enabled: true
		},
	])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.gradient.stops.len == 2
}

fn test_stylesheet_lint_finds_references_anywhere() {
	notes := stylesheet_lint_source('Button { border: 1px solid @brand; box-shadow: --off 0 2px --unknown; }')!
	assert notes.errors.any(it.contains('@brand'))
	assert notes.warnings.any(it.contains('--off'))
	assert notes.warnings.any(it.contains('--unknown'))
}

fn test_stylesheet_lint_bare_and_var_custom_properties_agree() {
	bare := stylesheet_lint_source('Button { color: --accent; }')!
	wrapped := stylesheet_lint_source('Button { color: var(--accent); }')!
	assert !bare.has_errors()
	assert !wrapped.has_errors()
	assert bare.warnings.len == 1
	assert wrapped.warnings.len == 1
}

fn test_stylesheet_lint_var_needs_custom_property_name() {
	notes := stylesheet_lint_source('@x: red; Button { color: var(@x); }')!
	assert notes.errors.any(it.contains('var()'))
}

fn test_stylesheet_lint_var_fallback_keeps_commas() {
	notes := stylesheet_lint_source('--x: 1px; Button { box-shadow: var(--x, #000000 2px, 4px); }')!
	assert !notes.has_errors()
	assert notes.warnings.len == 0
	nested := stylesheet_lint_source('Button { color: var(--x, @missing); }')!
	assert nested.errors.any(it.contains('@missing'))
}

fn test_stylesheet_lint_reports_declaration_lines() {
	notes := stylesheet_lint_source('Button {\n\tcolor: red;\n\tbogus: 1;\n}')!
	assert notes.errors.any(it.starts_with('line 3:'))
}

fn test_stylesheet_lint_import_only_is_not_empty() {
	notes := stylesheet_lint_source('@import "base.vss";')!
	assert !notes.has_errors()
}

fn test_stylesheet_lint_lone_sigil() {
	notes := stylesheet_lint_source('Button { color: @; }')!
	assert notes.has_errors()
}

fn test_style_rule_keeps_declaration_order() {
	rule := style_rule('Button', {
		'color':      'red'
		'background': 'blue'
	})!
	assert rule.declarations.map(it.prop) == ['color', 'background']
}
