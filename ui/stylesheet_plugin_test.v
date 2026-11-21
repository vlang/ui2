module ui2

import os

fn plugin_test_button(id string) Element {
	return Element{
		kind:    .button
		id:      id
		enabled: true
	}
}

fn plugin_test_cleanup(name string) {
	unregister_style_plugin(name)
}

// A custom pseudo-class matching one element id.
fn plugin_test_toggled(pseudo StylePseudo, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool {
	_ = pseudo
	_ = ancestors
	_ = index
	_ = count
	_ = env
	return el.id == 'special'
}

fn test_plugin_custom_pseudo_matches() {
	register_style_plugin(StylePlugin{
		name:         'test-pseudo'
		pseudos:      ['--toggled']
		match_pseudo: plugin_test_toggled
	})
	sheet := parse_stylesheet('Button:--toggled { background: #123456; }') or {
		plugin_test_cleanup('test-pseudo')
		panic(err)
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		plugin_test_button('special'),
		plugin_test_button('plain'),
	])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x123456
	assert root.children[1].box.bg == 0xffffff
	plugin_test_cleanup('test-pseudo')
}

fn test_plugin_unknown_pseudo_still_errors() {
	if _ := parse_stylesheet('Button:--nope { background: red; }') {
		assert false, 'unregistered pseudo must fail'
	} else {
		assert err.msg().contains('unknown pseudo-class')
	}
}

// A @dark-only at-rule: wraps the body in a dark-mode media query.
fn plugin_test_dark_only(name string, prelude string, body string) !string {
	_ = name
	_ = prelude
	return '@media (prefers-color-scheme: dark) { ${body} }'
}

fn test_plugin_at_rule_expands() {
	register_style_plugin(StylePlugin{
		name:           'test-atrule'
		at_rules:       ['dark-only']
		expand_at_rule: plugin_test_dark_only
	})
	sheet := parse_stylesheet('@dark-only { Button { background: #111111; } }') or {
		plugin_test_cleanup('test-atrule')
		panic(err)
	}
	assert sheet.rules.len == 1
	assert sheet.rules[0].media.len == 1
	assert sheet.rules[0].media[0].conditions[0].feature == 'prefers-color-scheme'
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [plugin_test_button('a')])
	light := apply_stylesheet(root, sheet, StyleMatchEnv{ dark: false })
	assert light.children[0].box.bg == 0xffffff
	dark := apply_stylesheet(root, sheet, StyleMatchEnv{ dark: true })
	assert dark.children[0].box.bg == 0x111111
	plugin_test_cleanup('test-atrule')
}

// A custom media feature matching a brand name.
fn plugin_test_brand_media(feature string, op string, value string, env StyleQueryEnv) bool {
	_ = feature
	_ = op
	_ = env
	return value == 'acme'
}

fn test_plugin_custom_media_feature() {
	register_style_plugin(StylePlugin{
		name:           'test-media'
		media_features: ['brand']
		match_media:    plugin_test_brand_media
	})
	sheet := parse_stylesheet('@media (brand: acme) { Button { background: #123456; } } @media (brand: other) { Button { color: white; } }') or {
		plugin_test_cleanup('test-media')
		panic(err)
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [plugin_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x123456
	assert root.children[0].text_style.color == 0x111111
	plugin_test_cleanup('test-media')
}

// A custom numeric function: double(4px) -> 8px.
fn plugin_test_double(name string, inner string, ctx StyleLengthCtx) !StyleFnValue {
	_ = name
	trimmed := inner.trim_space()
	mut parser := StyleMathParser{
		raw_source: trimmed
		tokens:     style_math_tokenize(trimmed) or { return error('bad double() argument') }
		ctx:        ctx
	}
	value := parser.parse_expr() or { return error('bad double() argument') }
	if !parser.eof() {
		return error('bad double() argument')
	}
	if value.dim != .px && value.dim != .scalar {
		return error('double() needs a length')
	}
	return StyleValue{
		dim:   .px
		value: value.value * 2
	}
}

fn test_plugin_custom_number_function() {
	register_style_plugin(StylePlugin{
		name:          'test-fn'
		functions:     ['double']
		eval_function: plugin_test_double
	})
	sheet := parse_stylesheet('Button { font-size: double(7px); }') or {
		plugin_test_cleanup('test-fn')
		panic(err)
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [plugin_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].text_style.size == 14.0
	plugin_test_cleanup('test-fn')
}

// A custom color function: brand(name) looks up a fixed palette.
fn plugin_test_brand(name string, inner string, ctx StyleLengthCtx) !StyleFnValue {
	_ = name
	_ = ctx
	match inner.trim_space().to_lower() {
		'primary' {
			return StyleFnValue(ComponentThemeToken{ color: 0x123456, opacity: 1.0 })
		}
		'accent' {
			return StyleFnValue(ComponentThemeToken{ color: 0xabcdef, opacity: 1.0 })
		}
		else {
			return error('unknown brand color "${inner.trim_space()}"')
		}
	}
}

fn test_plugin_custom_color_function() {
	register_style_plugin(StylePlugin{
		name:          'test-brand'
		functions:     ['brand']
		eval_function: plugin_test_brand
	})
	sheet := parse_stylesheet('Button { background: brand(primary); }') or {
		plugin_test_cleanup('test-brand')
		panic(err)
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [plugin_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x123456
	plugin_test_cleanup('test-brand')
}

fn test_plugin_function_mismatch_warns() {
	register_style_plugin(StylePlugin{
		name:          'test-brand-mismatch'
		functions:     ['brand2']
		eval_function: fn (name string, inner string, ctx StyleLengthCtx) !StyleFnValue {
			_ = name
			_ = inner
			_ = ctx
			return StyleFnValue(StyleValue{ dim: .scalar, value: 3.0 })
		}
	})
	sheet := parse_stylesheet('Button { background: brand2(x); }') or {
		plugin_test_cleanup('test-brand-mismatch')
		panic(err)
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [plugin_test_button('a')])
	out, warnings := apply_stylesheet_ex(root, sheet, StyleMatchEnv{})
	assert out.children[0].box.bg == 0xffffff
	assert warnings.any(it.prop == 'background')
	plugin_test_cleanup('test-brand-mismatch')
}

// A transform that outlines every id-bearing element in red.
fn plugin_test_outline(el Element, env StyleMatchEnv) Element {
	_ = env
	if el.id == '' {
		return el
	}
	return Element{
		...el
		box: BoxStyle{
			...el.box
			border_color:  0xff0000
			border_left:   2
			border_top:    2
			border_right:  2
			border_bottom: 2
		}
	}
}

fn test_plugin_transform_runs_and_preserves_identity() {
	register_style_plugin(StylePlugin{
		name:      'test-transform'
		transform: plugin_test_outline
	})
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [plugin_test_button('a')])
	out := apply_stylesheet(root, Stylesheet{}, StyleMatchEnv{})
	assert out.children[0].box.border_color == 0xff0000
	assert out.children[0].box.border_left == 2
	// Identity survives even a hostile transform.
	register_style_plugin(StylePlugin{
		name:      'test-hostile'
		transform: fn (el Element, env StyleMatchEnv) Element {
			_ = env
			return Element{
				...el
				id:   'hijacked'
				kind: .screen
			}
		}
	})
	mut root2 := view('root', rect(0, 0, 100, 100), BoxStyle{}, [plugin_test_button('b')])
	out2 := apply_stylesheet(root2, Stylesheet{}, StyleMatchEnv{})
	assert out2.children[0].id == 'b'
	assert out2.children[0].kind == .button
	plugin_test_cleanup('test-transform')
	plugin_test_cleanup('test-hostile')
}

// A lint rule that forbids the literal color red.
fn plugin_test_no_red(sheet Stylesheet) StylesheetLintNotes {
	mut warnings := []string{}
	for rule in sheet.rules {
		for decl in rule.declarations {
			if decl.value.trim_space().to_lower() == 'red' {
				warnings << 'line ${rule.line}: use a theme token instead of red'
			}
		}
	}
	return StylesheetLintNotes{ warnings: warnings }
}

fn test_plugin_lint_merges() {
	register_style_plugin(StylePlugin{
		name: 'test-lint'
		lint: plugin_test_no_red
	})
	notes := stylesheet_lint_source('Button { background: red; }')!
	assert !notes.has_errors()
	assert notes.warnings.any(it.contains('theme token'))
	plugin_test_cleanup('test-lint')
}

fn test_plugin_reregister_replaces() {
	register_style_plugin(StylePlugin{
		name:         'test-replace'
		pseudos:      ['--x']
		match_pseudo: fn (pseudo StylePseudo, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool {
			_ = pseudo
			_ = ancestors
			_ = index
			_ = count
			_ = env
			return false
		}
	})
	register_style_plugin(StylePlugin{
		name:         'test-replace'
		pseudos:      ['--x']
		match_pseudo: fn (pseudo StylePseudo, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool {
			_ = pseudo
			_ = ancestors
			_ = index
			_ = count
			_ = env
			return el.id == 'yes'
		}
	})
	sheet := parse_stylesheet('Button:--x { background: #123456; }') or {
		plugin_test_cleanup('test-replace')
		panic(err)
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [plugin_test_button('yes')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x123456
	plugin_test_cleanup('test-replace')
	// Unknown names still fail after unregistering.
	if _ := parse_stylesheet('Button:--x { background: red; }') {
		assert false, 'removed plugin must not match'
	} else {
		assert err.msg().contains('unknown pseudo-class')
	}
}

// An at-rule that passes its body through unchanged.
fn plugin_test_passthrough(name string, prelude string, body string) !string {
	_ = name
	_ = prelude
	return body
}

// An at-rule whose expansion re-emits itself.
fn plugin_test_self_wrap(name string, prelude string, body string) !string {
	_ = prelude
	return '@${name} { ${body} }'
}

fn test_plugin_at_rule_body_keeps_strings() {
	register_style_plugin(StylePlugin{
		name:           'test-pass'
		at_rules:       ['pass']
		expand_at_rule: plugin_test_passthrough
	})
	sheet := parse_stylesheet('@pass { Label { font-family: "Inter } \\" x"; background: url(http://x/y.png); } }') or {
		plugin_test_cleanup('test-pass')
		panic(err)
	}
	plugin_test_cleanup('test-pass')
	assert sheet.rules.len == 1
	assert sheet.rules[0].declarations[0].value == '"Inter } \\" x"'
	assert sheet.rules[0].declarations[1].value == 'url(http://x/y.png)'
}

fn test_plugin_self_expanding_at_rule_errors() {
	register_style_plugin(StylePlugin{
		name:           'test-loop'
		at_rules:       ['loop']
		expand_at_rule: plugin_test_self_wrap
	})
	if _ := parse_stylesheet('@loop { Button { color: red; } }') {
		plugin_test_cleanup('test-loop')
		assert false, 'a self-expanding at-rule must fail'
	} else {
		plugin_test_cleanup('test-loop')
		assert err.msg().contains('expands into itself')
	}
}

fn test_plugin_claims_never_shadow_builtins() {
	register_style_plugin(StylePlugin{
		name:           'test-shadow'
		at_rules:       ['import', 'accent']
		functions:      ['rgb']
		expand_at_rule: plugin_test_passthrough
		eval_function:  plugin_test_double
	})
	sheet := parse_stylesheet('@import "x.vss"; @accent: #ff0000; Button { color: rgb(0, 0, 255); }') or {
		plugin_test_cleanup('test-shadow')
		panic(err)
	}
	plugin_test_cleanup('test-shadow')
	assert sheet.imports == ['x.vss']
	assert sheet.variables['@accent'] == '#ff0000'
	token := component_theme_token('rgb(0, 0, 255)') or { panic(err) }
	assert token.color == 0x0000ff
}

fn plugin_test_decline(name string, inner string, ctx StyleLengthCtx) !StyleFnValue {
	_ = name
	_ = inner
	_ = ctx
	return error('declined')
}

fn test_plugin_second_claimant_is_consulted() {
	register_style_plugin(StylePlugin{
		name:          'test-first'
		functions:     ['double']
		eval_function: plugin_test_decline
	})
	register_style_plugin(StylePlugin{
		name:          'test-second'
		functions:     ['double']
		eval_function: plugin_test_double
	})
	sheet := parse_stylesheet('Button { font-size: double(5px); }') or {
		plugin_test_cleanup('test-first')
		plugin_test_cleanup('test-second')
		panic(err)
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [plugin_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	plugin_test_cleanup('test-first')
	plugin_test_cleanup('test-second')
	assert root.children[0].text_style.size == 10.0
}
