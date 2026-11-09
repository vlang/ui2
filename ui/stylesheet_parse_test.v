module ui2

fn test_stylesheet_parses_type_id_class() {
	sheet := parse_stylesheet('Button#login.primary { background: #2563eb; color: white; }')!
	assert sheet.rules.len == 1
	rule := sheet.rules[0]
	assert rule.selectors.len == 1
	sel := rule.selectors[0]
	assert sel.parts.len == 1
	assert sel.parts[0].kind == 'Button'
	assert sel.parts[0].id == 'login'
	assert sel.parts[0].classes == ['primary']
	assert sel.specificity == 1000000 + 1000 + 1
	assert rule.declarations.len == 2
	assert rule.declarations[0].prop == 'background'
	assert rule.declarations[0].value == '#2563eb'
}

fn test_stylesheet_parses_group_descendant_child() {
	sheet := parse_stylesheet('View.card > Label.title, Input:disabled { opacity: 0.5; }')!
	assert sheet.rules.len == 1
	rule := sheet.rules[0]
	assert rule.selectors.len == 2
	first := rule.selectors[0]
	assert first.parts.len == 2
	assert first.combinators == [.child]
	assert first.parts[0].kind == 'View'
	assert first.parts[1].kind == 'Label'
	second := rule.selectors[1]
	assert second.parts.len == 1
	assert second.parts[0].pseudos.len == 1
	assert second.parts[0].pseudos[0].name == 'disabled'
}

fn test_stylesheet_variables_and_theme_blocks() {
	sheet := parse_stylesheet('
		@primary: #2563eb;
		--card-pad: 12px;
		light { @bg: #ffffff; }
		dark { @bg: #172033; }
		Button { background: @primary; }
	')!
	assert sheet.variables['@primary'] == '#2563eb'
	assert sheet.variables['--card-pad'] == '12px'
	assert sheet.light_vars['@bg'] == '#ffffff'
	assert sheet.dark_vars['@bg'] == '#172033'
	assert sheet.resolve_var('@primary', false) or { '' } == '#2563eb'
	assert sheet.resolve_var('@bg', true) or { '' } == '#172033'
	assert sheet.resolve_var('@bg', false) or { '' } == '#ffffff'
}

fn test_stylesheet_nth_child_args() {
	for arg in ['2', 'odd', 'even'] {
		sheet := parse_stylesheet('Item:nth-child(${arg}) { background: white; }')!
		assert sheet.rules[0].selectors[0].parts[0].pseudos[0].arg == arg
	}
}

fn test_stylesheet_rejects_unknown_pseudo() {
	if _ := parse_stylesheet('Button:blink { background: red; }') {
		assert false, 'unknown pseudo-class must fail'
	} else {
		assert err.msg().contains('unknown pseudo-class')
		assert err.msg().contains('stylesheet:')
	}
}

fn test_stylesheet_rejects_unclosed_block() {
	if _ := parse_stylesheet('Button { background: red;') {
		assert false, 'unclosed block must fail'
	} else {
		assert err.msg().len > 0
	}
}

fn test_stylesheet_rejects_rule_in_theme_block() {
	if _ := parse_stylesheet('light { Button { background: red; } }') {
		assert false, 'rules in theme blocks must fail'
	} else {
		assert err.msg().contains('only variables')
	}
}

fn test_stylesheet_parses_type_prefixing_theme_keyword_as_rule() {
	// `lights` is not a theme block (no word boundary): it parses as a type
	// rule that simply never matches a real kind.
	sheet := parse_stylesheet('lights { background: red; }')!
	assert sheet.rules.len == 1
	assert sheet.rules[0].selectors[0].parts[0].kind == 'lights'
	assert sheet.light_vars.len == 0
	assert sheet.dark_vars.len == 0
}

fn test_stylesheet_value_keeps_functions() {
	sheet := parse_stylesheet('Card { background: linear-gradient(135deg, #4f46e5, #06b6d4); }')!
	assert sheet.rules[0].declarations[0].value == 'linear-gradient(135deg, #4f46e5, #06b6d4)'
}
