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
