module ui2

fn test_stylesheet_parses_type_id_class() {
	sheet := parse_stylesheet('Button#login.primary { background: #2563eb; color: white; }')!
	assert sheet.rules.len == 1
	rule := sheet.rules[0]
	assert rule.selectors.len == 1
	sel := rule.selectors[0]
	assert sel.parts.len == 1
	assert sel.parts[0].kind == 'button'
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
	assert first.parts[0].kind == 'view'
	assert first.parts[1].kind == 'label'
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

fn test_stylesheet_nesting_implicit_descendant() {
	sheet := parse_stylesheet('View.card { background: white; Label.title { font-size: 20px; } }')!
	assert sheet.rules.len == 2
	assert sheet.rules[0].selectors[0].parts.len == 1
	inner := sheet.rules[1].selectors[0]
	assert inner.parts.len == 2
	assert inner.parts[0].kind == 'view'
	assert inner.parts[1].kind == 'label'
	assert inner.combinators == [.descendant]
	assert sheet.rules[1].declarations[0].prop == 'font-size'
}

fn test_stylesheet_nesting_parent_ref() {
	sheet := parse_stylesheet('Button.primary { color: white; &:hover { background: red; } &.ghost { color: blue; } }')!
	assert sheet.rules.len == 3
	hover := sheet.rules[1].selectors[0]
	assert hover.parts.len == 1
	assert hover.parts[0].kind == 'button'
	assert hover.parts[0].classes == ['primary']
	assert hover.parts[0].pseudos.map(it.name) == ['hover']
	ghost := sheet.rules[2].selectors[0]
	assert ghost.parts[0].classes == ['primary', 'ghost']
}

fn test_stylesheet_nesting_explicit_child() {
	sheet := parse_stylesheet('View { > Button { background: red; } }')!
	inner := sheet.rules[0].selectors[0]
	assert inner.parts.len == 2
	assert inner.combinators == [.child]
}

fn test_stylesheet_nesting_rejects_nonleading_ref() {
	if _ := parse_stylesheet('View { Button & { background: red; } }') {
		assert false, 'non-leading & must fail'
	} else {
		assert err.msg().contains('leading `&`')
	}
}

fn test_stylesheet_nesting_rejects_conflicting_merge() {
	if _ := parse_stylesheet('Button { &Label { background: red; } }') {
		assert false, 'conflicting type merge must fail'
	} else {
		assert err.msg().contains('redefines the type')
	}
}

fn test_stylesheet_nesting_rejects_top_level_ref() {
	if _ := parse_stylesheet('& Button { background: red; }') {
		assert false, 'top-level & must fail'
	} else {
		assert err.msg().contains('nested inside another rule')
	}
}

fn test_stylesheet_nesting_composes_with_queries() {
	sheet := parse_stylesheet('@media (platform: windows) { View.card { Label.title { font-size: 18px; } } }')!
	assert sheet.rules.len == 1
	assert sheet.rules[0].media.len == 1
	assert sheet.rules[0].selectors[0].parts.len == 2
}

fn test_stylesheet_value_keeps_functions() {
	sheet := parse_stylesheet('Card { background: linear-gradient(135deg, #4f46e5, #06b6d4); }')!
	assert sheet.rules[0].declarations[0].value == 'linear-gradient(135deg, #4f46e5, #06b6d4)'
}

fn test_stylesheet_nested_type_pseudo_rule() {
	// `Button:hover {` looks like a declaration until the `{`.
	sheet := parse_stylesheet('View { Button:hover { color: #ff0000; } color: #00ff00; }')!
	assert sheet.rules.len == 2
	assert sheet.rules[0].declarations[0].prop == 'color'
	nested := sheet.rules[1]
	assert nested.selectors[0].parts.len == 2
	assert nested.selectors[0].parts[1].kind == 'button'
	assert nested.selectors[0].parts[1].pseudos[0].name == 'hover'
}

fn test_stylesheet_value_drops_comments() {
	sheet := parse_stylesheet('Button { color: #f00 /* accent */; border: 1px/**/solid red; }')!
	assert sheet.rules[0].declarations[0].value == '#f00'
	assert sheet.rules[0].declarations[1].value == '1px solid red'
}

fn test_stylesheet_value_keeps_escaped_quotes() {
	sheet := parse_stylesheet('Label { font-family: "A \\"quoted; } name"; color: red; }')!
	assert sheet.rules[0].declarations.len == 2
	assert sheet.rules[0].declarations[0].value == '"A \\"quoted; } name"'
}

fn test_stylesheet_skips_utf8_bom() {
	sheet := parse_stylesheet('\xef\xbb\xbfButton { color: red; }')!
	assert sheet.rules.len == 1
}

fn test_stylesheet_rejects_empty_value() {
	if _ := parse_stylesheet('Button { color: ; }') {
		assert false, 'empty value must fail'
	} else {
		assert err.msg().contains('empty value')
	}
}

fn test_stylesheet_comment_between_compounds() {
	sheet := parse_stylesheet('View /* c */ Label { color: red; } View/* c */>/* d */Label { color: blue; }')!
	assert sheet.rules[0].selectors[0].parts.len == 2
	assert sheet.rules[0].selectors[0].combinators == [StyleCombinator.descendant]
	assert sheet.rules[1].selectors[0].combinators == [StyleCombinator.child]
}

fn test_stylesheet_nested_child_ref_is_rejected() {
	if _ := parse_stylesheet('View { > &:hover { color: red; } }') {
		assert false, '`> &` must not silently drop the combinator'
	} else {
		assert err.msg().contains('> &')
	}
}

fn test_stylesheet_nth_child_overflow_is_rejected() {
	if _ := parse_stylesheet('Button:nth-child(99999999999) { color: red; }') {
		assert false, 'huge nth-child must fail'
	} else {
		assert err.msg().contains('too large')
	}
}
