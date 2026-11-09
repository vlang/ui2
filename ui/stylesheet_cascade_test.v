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

fn test_cascade_uppercase_kind_matches() {
	// Kinds normalize to lowercase at parse; matching stays case-insensitive.
	sheet := parse_stylesheet('BUTTON { background: #123456; }')!
	assert sheet.rules[0].selectors[0].parts[0].kind == 'button'
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x123456
}

fn test_cascade_plain_length_cache_stays_ctx_sensitive() {
	mut cache := map[string]f64{}
	narrow := StyleLengthCtx{
		win_w:  400
		win_h:  300
		cont_w: 100
		cont_h: 100
	}
	wide := StyleLengthCtx{
		win_w:  800
		win_h:  600
		cont_w: 100
		cont_h: 100
	}
	// Plain numbers cache and ignore the context.
	plain_narrow := cascade_length_px('12px', narrow, mut cache) or { panic('plain length failed') }
	plain_wide := cascade_length_px('12px', wide, mut cache) or { panic('plain length failed') }
	assert plain_narrow == 12.0
	assert plain_wide == 12.0
	assert cache['12px'] == 12.0
	// Viewport units always take the slow path and follow the window.
	vw_narrow := cascade_length_px('50vw', narrow, mut cache) or { panic('vw length failed') }
	vw_wide := cascade_length_px('50vw', wide, mut cache) or { panic('vw length failed') }
	assert vw_narrow == 200.0
	assert vw_wide == 400.0
	assert '50vw' !in cache
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

fn test_cascade_theme_only_scoped_sheet_activates() {
	global := parse_stylesheet('Button { background: @bg; }')!
	scoped := parse_stylesheet('dark { @bg: #111111; }')!
	inner := with_stylesheet(view('card', rect(0, 0, 100, 100), BoxStyle{}, [
		cascade_test_button('x'),
	]), scoped)
	mut root := view('root', rect(0, 0, 200, 200), BoxStyle{}, [inner])
	root = apply_stylesheet(root, global, StyleMatchEnv{ dark: true })
	assert root.children[0].children[0].box.bg == 0x111111
}

fn test_cascade_opacity_garbage_warns() {
	sheet := parse_stylesheet('Button { opacity: banana; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	out, warnings := apply_stylesheet_ex(root, sheet, StyleMatchEnv{})
	assert out.children[0].box.opacity == 1.0
	assert warnings.any(it.prop == 'opacity')
}

fn test_cascade_duplicate_property_later_wins() {
	sheet := parse_stylesheet('Button { background: #ff0000; background: #0000ff; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x0000ff
}

fn test_cascade_variables_inside_gradient() {
	sheet := parse_stylesheet('@a: #4f46e5;
Button { background: linear-gradient(135deg, @a, #06b6d4); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.gradient.stops.len == 2
	assert root.children[0].box.gradient.stops[0].color == 0x4f46e5
}

fn test_cascade_unknown_variable_inside_gradient_warns() {
	sheet := parse_stylesheet('Button { background: linear-gradient(135deg, @nope, #06b6d4); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	out, warnings := apply_stylesheet_ex(root, sheet, StyleMatchEnv{})
	assert out.children[0].box.gradient.stops.len == 0
	assert warnings.any(it.prop == 'background')
}

fn test_cascade_container_units_use_query_target() {
	sheet := parse_stylesheet('@container wide (min-width: 200px) { Button { font-size: 10cqw; } }')!
	wide_card := with_classes(view('card1', rect(0, 0, 500, 100), BoxStyle{}, [
		cascade_test_button('a'),
	]), 'wide')
	plain_card := view('card2', rect(0, 0, 500, 100), BoxStyle{}, [cascade_test_button('b')])
	mut root := view('root', rect(0, 0, 1000, 100), BoxStyle{}, [wide_card, plain_card])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].children[0].text_style.size == 50.0
	assert root.children[1].children[0].text_style.size == 15.0
}

fn test_cascade_calc_values() {
	parsed := parse_stylesheet('Button { font-size: calc(2 * 7px); border-radius: min(4px, 2px); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, parsed, StyleMatchEnv{})
	assert root.children[0].text_style.size == 14.0
	assert root.children[0].box.radius == 2.0
}

fn test_cascade_color_mix_background() {
	sheet := parse_stylesheet('Button { background: color-mix(in srgb, #ff0000, #0000ff); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x800080
}

fn test_cascade_nested_base_loses_to_matching_container() {
	sheet := parse_stylesheet('View.card { Label.card-title { font-size: 14px; } } @container card (min-width: 280px) { View.card Label.card-title { font-size: 18px; } }')!
	// The outer View.card block carries no declarations itself, so only the
	// flattened nested rule and the container rule remain.
	assert sheet.rules.len == 2
	wide := with_classes(view('wide', rect(0, 0, 500, 100), BoxStyle{}, [
		with_classes(label('t', 'Wide', rect(0, 0, 100, 20), TextStyle{}), 'card-title'),
	]), 'card')
	narrow := with_classes(view('narrow', rect(0, 0, 200, 100), BoxStyle{}, [
		with_classes(label('u', 'Narrow', rect(0, 0, 100, 20), TextStyle{}), 'card-title'),
	]), 'card')
	mut root := view('root', rect(0, 0, 1000, 100), BoxStyle{}, [wide, narrow])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	// Nested base (0,1,2) vs container override (0,1,2, later): the wide
	// card matches the container and takes 18px, the narrow one keeps 14px.
	assert root.children[0].children[0].text_style.size == 18.0
	assert root.children[1].children[0].text_style.size == 14.0
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

fn test_cascade_var_function() {
	sheet := parse_stylesheet('@base: 12px;
Button { font-size: var(--size, @base); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].text_style.size == 12.0
}

fn test_cascade_var_fallback_chain() {
	sheet := parse_stylesheet('Button { font-size: var(--missing, var(--also-missing, 20px)); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].text_style.size == 20.0
}

fn test_cascade_custom_property_inherits() {
	sheet := parse_stylesheet('View { --pad: 30px; } Button { font-size: var(--pad); }')!
	inner := view('inner', rect(0, 0, 400, 100), BoxStyle{}, [cascade_test_button('a')])
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [inner])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].children[0].text_style.size == 30.0
}

fn test_cascade_custom_property_inner_wins() {
	sheet := parse_stylesheet('View { --pad: 30px; } View.inner { --pad: 18px; } Button { font-size: var(--pad); }')!
	inner := with_classes(view('inner', rect(0, 0, 400, 100), BoxStyle{}, [
		cascade_test_button('a'),
	]), 'inner')
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [inner])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].children[0].text_style.size == 18.0
}

fn test_cascade_unknown_custom_property_warns() {
	sheet := parse_stylesheet('Button { font-size: var(--nope); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	out, warnings := apply_stylesheet_ex(root, sheet, StyleMatchEnv{})
	assert out.children[0].text_style.size == 15.0
	assert warnings.any(it.prop == 'font-size')
}

fn test_cascade_light_dark_function() {
	sheet := parse_stylesheet('Button { background: light-dark(#eeeeee, #111111); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	light := apply_stylesheet(root, sheet, StyleMatchEnv{ dark: false })
	dark := apply_stylesheet(root, sheet, StyleMatchEnv{ dark: true })
	assert light.children[0].box.bg == 0xeeeeee
	assert dark.children[0].box.bg == 0x111111
}

fn test_cascade_nested_rule_applies() {
	sheet := parse_stylesheet('View.card { Label.card-title { font-size: 19px; } &:hover { border-color: red; } }')!
	card := with_classes(view('card', rect(0, 0, 300, 100), BoxStyle{}, [
		with_classes(label('t', 'Hi', rect(0, 0, 100, 20), TextStyle{}), 'card-title'),
	]), 'card')
	mut root := view('root', rect(0, 0, 1000, 100), BoxStyle{}, [card])
	plain := apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert plain.children[0].children[0].text_style.size == 19.0
	hovered := apply_stylesheet(root, sheet, StyleMatchEnv{ hovered: 'card' })
	assert hovered.children[0].box.border_color == 0xef4444
	// The container rule from the queries test still matches: covered there.
}

fn test_cascade_translucent_background_keeps_raw_color() {
	// The alpha becomes fill opacity once; the color is not pre-blended.
	sheet := parse_stylesheet('Button { background: rgba(255, 0, 0, 0.5); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0xff0000
	assert root.children[0].box.opacity == 0.5
}

fn test_cascade_later_opaque_background_resets_alpha() {
	sheet := parse_stylesheet('Button { background: rgba(255, 0, 0, 0.5); } Button.solid { background: #00ff00; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		with_classes(cascade_test_button('a'), 'solid'),
	])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x00ff00
	assert root.children[0].box.opacity == 1.0
}

fn test_cascade_solid_background_clears_gradient() {
	sheet := parse_stylesheet('Button { background: linear-gradient(#ff0000, #0000ff); } Button.primary { background: #ff0000; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		with_classes(cascade_test_button('a'), 'primary'),
	])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.gradient.stops.len == 0
	assert root.children[0].box.bg == 0xff0000
}

fn test_cascade_background_alpha_keeps_inline_opacity() {
	sheet := parse_stylesheet('Button { background: rgba(0, 0, 255, 0.5); opacity: 0.2; }')!
	el := Element{
		kind:    .button
		id:      'a'
		enabled: true
		box:     BoxStyle{
			opacity: 0.8
		}
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [el])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	// Builder opacity survives (the sheet's `opacity` loses) and still
	// multiplies the color's alpha.
	assert root.children[0].box.opacity > 0.39 && root.children[0].box.opacity < 0.41
}

fn test_cascade_opacity_and_background_alpha_multiply() {
	sheet := parse_stylesheet('Button { opacity: 0.5; background: rgba(0, 0, 255, 0.5); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.opacity == 0.25
}

fn test_cascade_invalid_later_value_keeps_earlier() {
	// CSS drops an invalid declaration; folding must not let it hide the
	// earlier valid one.
	sheet := parse_stylesheet('Button { color: #ff0000; } Button { color: notacolor; }')!
	root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	styled, warnings := apply_stylesheet_ex(root, sheet, StyleMatchEnv{})
	assert styled.children[0].text_style.color == 0xff0000
	assert warnings.len == 1
}

fn test_cascade_text_decoration_none_resets() {
	sheet := parse_stylesheet('Label { text-decoration: underline; } Label.plain { text-decoration: none; }')!
	label := Element{
		kind:    .label
		id:      'l'
		classes: ['plain']
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [label])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert !root.children[0].text_style.underline
}

fn test_cascade_font_weight_and_style_validate() {
	sheet := parse_stylesheet('Label { font-weight: banana; font-style: oblique; }')!
	label := Element{
		kind: .label
		id:   'l'
	}
	root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [label])
	styled, warnings := apply_stylesheet_ex(root, sheet, StyleMatchEnv{})
	assert !styled.children[0].text_style.bold
	assert styled.children[0].text_style.italic
	assert warnings.len == 1
	assert warnings[0].prop == 'font-weight'
}

fn test_cascade_border_without_width_warns() {
	sheet := parse_stylesheet('Button { border: red; }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	_, warnings := apply_stylesheet_ex(root, sheet, StyleMatchEnv{})
	assert warnings.len == 1
	assert warnings[0].message.contains('width')
	solid := parse_stylesheet('Button { border: 2px solid #ff0000; }')!
	root = apply_stylesheet(root, solid, StyleMatchEnv{})
	assert root.children[0].box.border_left == 2.0
	assert root.children[0].box.border_color == 0xff0000
}

fn test_cascade_element_custom_property_beats_inherited() {
	sheet := parse_stylesheet('View { --pad: 30px; } Button { --pad: 18px; font-size: var(--pad); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].text_style.size == 18.0
}

fn test_cascade_var_fallback_keeps_commas() {
	sheet := parse_stylesheet('Button { box-shadow: var(--missing, #000000 4px 0 2px); }')!
	root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	styled, warnings := apply_stylesheet_ex(root, sheet, StyleMatchEnv{})
	assert warnings.len == 0
	assert styled.children[0].box.shadow.blur == 4.0
	first, rest := style_split_first_comma('--x, 2px, 4px')
	assert first == '--x'
	assert rest or { '' } == ' 2px, 4px'
}

fn test_cascade_bare_variable_rescans() {
	sheet := parse_stylesheet('--base: #123456; @accent: var(--base); Button { background: @accent; }')!
	root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	styled, warnings := apply_stylesheet_ex(root, sheet, StyleMatchEnv{})
	assert warnings.len == 0
	assert styled.children[0].box.bg == 0x123456
}

fn test_cascade_inherited_cycle_terminates() {
	sheet := parse_stylesheet('View { --a: var(--a); } Button { color: var(--a, #ff0000); }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [cascade_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].text_style.color == 0xff0000
}

fn test_cascade_group_uses_best_matching_specificity() {
	// `#save` matches with id specificity even though `Button.primary` is
	// listed first, so the group beats the later class rule.
	sheet := parse_stylesheet('Button.primary, #save { background: #00ff00; } Button.cta { background: #ff0000; }')!
	el := Element{
		kind:    .button
		id:      'save'
		enabled: true
		classes: ['primary', 'cta']
	}
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [el])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x00ff00
}

fn test_with_classes_appends() {
	el := with_classes(with_classes(cascade_test_button('a'), 'one'), 'two', 'one')
	assert el.classes == ['one', 'two']
}

fn test_cascade_variables_only_global_feeds_scopes() {
	global := parse_stylesheet('--brand: #abcdef;')!
	scoped := parse_stylesheet('Button { background: var(--brand); }')!
	root := with_stylesheet(view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		cascade_test_button('a'),
	]), scoped)
	styled, warnings := apply_stylesheet_ex(root, global, StyleMatchEnv{})
	assert warnings.len == 0
	assert styled.children[0].box.bg == 0xabcdef
}

fn test_stylesheet_apply_frame_runs_scopes_without_global() {
	clear_global_stylesheet()
	scoped := parse_stylesheet('Button { background: #345678; }')!
	root := with_stylesheet(view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		cascade_test_button('a'),
	]), scoped)
	out := stylesheet_apply_frame(root, stylesheet_frame_env('', '', ''))
	assert out.children[0].box.bg == 0x345678
}
