module ui2

fn cascade_test_button(id string) Element {
	return Element{
		kind:    .button
		id:      id
		enabled: true
	}
}

fn test_cascade_type_and_class() {
	sheet := parse_stylesheet('Button { background: #2563eb; } Button.primary { color: white; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		cascade_test_button('a'),
		with_classes(cascade_test_button('b'), 'primary'),
	])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x2563eb
	assert root.children[1].box.bg == 0x2563eb
	assert root.children[0].text_style.color == 0x111111 // no .primary
	assert root.children[1].text_style.color == 0xffffff
}

fn test_cascade_specificity_and_order() {
	sheet := parse_stylesheet('Button { background: #ff0000; } Button { background: #0000ff; } Button#go { background: #00ff00; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('go')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x00ff00 // id wins over later type rule
}

fn test_cascade_inline_wins() {
	sheet := parse_stylesheet('Button { background: #2563eb; }')!
	already := Element{
		kind:    .button
		id:      'styled'
		enabled: true
		box:     BoxStyle{
			bg: 0xff0000
		}
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [already])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0xff0000
}

fn test_cascade_scoped_sheet_beats_global_on_tie() {
	global := parse_stylesheet('Button { background: #ff0000; }')!
	scoped := parse_stylesheet('Button { background: #0000ff; }')!
	inner := with_stylesheet(view('card', rect(0, 0, 100, 100), BoxStyle{}, [
		cascade_test_button('x'),
	]), scoped)
	mut root := view('root', rect(0, 0, 200, 200), BoxStyle{}, [inner])
	root = apply_stylesheet(root, global, StyleMatchEnv{})
	assert root.children[0].children[0].box.bg == 0x0000ff
}

fn test_cascade_pseudo_state() {
	sheet := parse_stylesheet('Button:hover { background: #111111; } Button:disabled { opacity: 0.5; }')!
	mut plain := cascade_test_button('a')
	plain.classes << 'x'
	disabled := Element{
		kind:    .button
		id:      'b'
		enabled: false
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [plain, disabled])
	out := apply_stylesheet(root, sheet, StyleMatchEnv{
		hovered: 'a'
	})
	assert out.children[0].box.bg == 0x111111
	assert out.children[0].box.opacity == 1.0
	assert out.children[1].box.opacity == 0.5
}

fn test_cascade_structural_pseudo() {
	sheet := parse_stylesheet('Button:first-child { background: #ff0000; } Button:nth-child(2) { background: #0000ff; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		cascade_test_button('a'),
		cascade_test_button('b'),
	])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0xff0000
	assert root.children[1].box.bg == 0x0000ff
}

fn test_cascade_descendant_and_child() {
	sheet := parse_stylesheet('View Button { background: #ff0000; } View > Button { color: white; }')!
	inner_view := view('inner', rect(0, 0, 50, 50), BoxStyle{}, [cascade_test_button('deep')])
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [inner_view])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	deep := root.children[0].children[0]
	assert deep.box.bg == 0xff0000
	assert deep.text_style.color == 0xffffff
}

fn test_cascade_variables_and_dark() {
	sheet := parse_stylesheet('@bg: #111111; light { @bg: #eeeeee; } dark { @bg: #222222; } Button { background: @bg; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	light := apply_stylesheet(root, sheet, StyleMatchEnv{ dark: false })
	dark := apply_stylesheet(root, sheet, StyleMatchEnv{ dark: true })
	assert light.children[0].box.bg == 0xeeeeee
	assert dark.children[0].box.bg == 0x222222
}

fn test_cascade_tailwind_names() {
	// Named colors follow the theme grammar: bare names are Tailwind 500s.
	sheet := parse_stylesheet('Button { background: red; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0xef4444
}

fn test_cascade_ignore_and_warnings() {
	sheet := parse_stylesheet('Button { background: #ff0000; padding: 8px; bogus-prop: 1; }')!
	ignored := Element{
		...cascade_test_button('skip')
		ignore_stylesheet: true
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [ignored, cascade_test_button('warned')])
	out, warnings := apply_stylesheet_ex(root, sheet, StyleMatchEnv{})
	assert out.children[0].box.bg == 0xffffff // untouched by the sheet
	assert out.children[1].box.bg == 0xff0000 // matched normally
	assert warnings.any(it.prop == 'padding')
	assert warnings.any(it.prop == 'bogus-prop')
}

fn test_stylesheet_dsl_matches_parser() {
	rule := style_rule('Button.primary:hover', {
		'background': '#2563eb'
	})!
	sheet := stylesheet_from_rules([rule], map[string]string{})
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		with_classes(cascade_test_button('a'), 'primary'),
	])
	out := apply_stylesheet(root, sheet, StyleMatchEnv{
		hovered: 'a'
	})
	assert out.children[0].box.bg == 0x2563eb
}
