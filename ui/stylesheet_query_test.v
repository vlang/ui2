module ui2

fn query_test_button(id string) Element {
	return Element{
		kind:    .button
		id:      id
		enabled: true
	}
}

fn query_test_env() StyleQueryEnv {
	return StyleQueryEnv{
		width:    800
		height:   600
		dpi:      2.0
		platform: 'windows'
		coarse:   false
		dark:     false
	}
}

// ── @media parsing ──────────────────────────────────────────────

fn test_media_parses_single_condition() {
	sheet := parse_stylesheet('@media (orientation: landscape) { Button { background: red; } }')!
	assert sheet.rules.len == 1
	media := sheet.rules[0].media
	assert media.len == 1
	assert media[0].negate == false
	assert media[0].conditions == [MediaCondition{
		feature: 'orientation'
		op:      ''
		value:   'landscape'
	}]
}

fn test_media_parses_and_not_and_or() {
	sheet := parse_stylesheet('@media (min-width: 700px) and (orientation: landscape), not (platform: ios) { Button { background: red; } }')!
	media := sheet.rules[0].media
	assert media.len == 2
	assert media[0].conditions.len == 2
	assert media[0].conditions[0].op == 'min'
	assert media[1].negate == true
}

fn test_media_nesting_accumulates() {
	sheet := parse_stylesheet('@media (platform: windows) { @media (orientation: landscape) { Button { background: red; } } }')!
	rule := sheet.rules[0]
	assert rule.media.len == 1
	assert rule.media[0].conditions[0].feature == 'orientation'
	assert rule.outer_media.len == 1
	assert rule.outer_media[0][0].conditions[0].feature == 'platform'
}

fn test_media_nesting_intersects() {
	// Nested blocks need both levels to hold, not either.
	sheet := parse_stylesheet('@media (platform: windows) { @media (orientation: portrait) { Button { background: #ff0000; } } }')!
	mut root := view('root', rect(0, 0, 800, 600), BoxStyle{}, [query_test_button('b')])
	env := query_test_env() // windows, landscape
	assert !rule_media_matches(sheet.rules[0], env)
	portrait := StyleQueryEnv{
		...env
		width:  400
		height: 800
	}
	assert rule_media_matches(sheet.rules[0], portrait)
	other := StyleQueryEnv{
		...portrait
		platform: 'macos'
	}
	assert !rule_media_matches(sheet.rules[0], other)
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	_ = root
}

fn test_container_nesting_intersects() {
	sheet := parse_stylesheet('@container (min-width: 300px) { @container (min-height: 500px) { Button { background: #ff0000; } } }')!
	assert sheet.rules[0].outer_containers.len == 1
	tall := view('root', rect(0, 0, 400, 600), BoxStyle{}, [query_test_button('b')])
	short := view('root', rect(0, 0, 400, 200), BoxStyle{}, [query_test_button('b')])
	assert apply_stylesheet(tall, sheet, StyleMatchEnv{}).children[0].box.bg == 0xff0000
	assert apply_stylesheet(short, sheet, StyleMatchEnv{}).children[0].box.bg == 0xffffff
}

fn test_media_rejects_unknown_feature() {
	if _ := parse_stylesheet('@media (colormode: dark) { Button { background: red; } }') {
		assert false, 'unknown media feature must fail'
	} else {
		assert err.msg().contains('unknown query feature')
	}
}

fn test_media_rejects_bad_value() {
	if _ := parse_stylesheet('@media (orientation: sideways) { Button { background: red; } }') {
		assert false, 'bad orientation must fail'
	} else {
		assert err.msg().contains('orientation')
	}
}

fn test_media_rejects_min_prefix_on_plain_feature() {
	if _ := parse_stylesheet('@media (min-orientation: landscape) { Button { background: red; } }') {
		assert false, 'min-orientation must fail'
	} else {
		assert err.msg().contains('min-orientation')
	}
}

fn test_media_rejects_variables_inside() {
	if _ := parse_stylesheet('@media (platform: windows) { @accent: red; }') {
		assert false, 'variables inside @media must fail'
	} else {
		assert err.msg().contains('only rules and query blocks')
	}
}

fn test_media_rejects_unclosed_block() {
	if _ := parse_stylesheet('@media (platform: windows) { Button { background: red; }') {
		assert false, 'unclosed @media must fail'
	} else {
		assert err.msg().contains('unclosed')
	}
}

// ── @container parsing ──────────────────────────────────────────

fn test_container_parses_unnamed() {
	sheet := parse_stylesheet('@container (min-width: 400px) { Button { background: red; } }')!
	containers := sheet.rules[0].containers
	assert containers.len == 1
	assert containers[0].name == ''
	assert containers[0].conditions[0].op == 'min'
}

fn test_container_parses_named_and_combo() {
	sheet := parse_stylesheet('@container sidebar (min-width: 200px) and (max-height: 800px) { Button { background: red; } }')!
	containers := sheet.rules[0].containers
	assert containers[0].name == 'sidebar'
	assert containers[0].conditions.len == 2
}

fn test_container_parses_name_only() {
	sheet := parse_stylesheet('@container sidebar { Button { background: red; } }')!
	assert sheet.rules[0].containers[0].name == 'sidebar'
	assert sheet.rules[0].containers[0].conditions.len == 0
}

fn test_container_rejects_media_feature() {
	if _ := parse_stylesheet('@container (orientation: landscape) { Button { background: red; } }') {
		assert false, 'orientation in @container must fail'
	} else {
		assert err.msg().contains('containers test width/height only')
	}
}

fn test_container_rejects_empty() {
	if _ := parse_stylesheet('@container { Button { background: red; } }') {
		assert false, 'empty @container must fail'
	} else {
		assert err.msg().len > 0
	}
}

// ── media evaluation ────────────────────────────────────────────

fn test_media_eval_orientation() {
	env := query_test_env()
	assert media_list_matches([MediaQuery{
		conditions: [MediaCondition{
			feature: 'orientation'
			value:   'landscape'
		}]
	}], env)
	assert !media_list_matches([MediaQuery{
		conditions: [MediaCondition{
			feature: 'orientation'
			value:   'portrait'
		}]
	}], env)
	tall := StyleQueryEnv{
		...env
		width:  400
		height: 800
	}
	assert media_list_matches([MediaQuery{
		conditions: [MediaCondition{
			feature: 'orientation'
			value:   'portrait'
		}]
	}], tall)
}

fn test_media_eval_platform_pointer_scheme() {
	env := query_test_env()
	platform := MediaQuery{
		conditions: [MediaCondition{ feature: 'platform', value: 'windows' }]
	}
	assert media_list_matches([platform], env)
	assert !media_list_matches([MediaQuery{
		conditions: [MediaCondition{ feature: 'platform', value: 'ios' }]
	}], env)
	assert media_list_matches([MediaQuery{
		conditions: [MediaCondition{ feature: 'pointer', value: 'fine' }]
	}], env)
	assert media_list_matches([MediaQuery{
		conditions: [MediaCondition{ feature: 'prefers-color-scheme', value: 'light' }]
	}], env)
	dark := StyleQueryEnv{
		...env
		dark: true
	}
	assert media_list_matches([MediaQuery{
		conditions: [MediaCondition{ feature: 'prefers-color-scheme', value: 'dark' }]
	}], dark)
}

fn test_media_eval_width_and_resolution() {
	env := query_test_env()
	assert media_list_matches([MediaQuery{
		conditions: [MediaCondition{ feature: 'width', op: 'min', value: '700px' }]
	}], env)
	assert !media_list_matches([MediaQuery{
		conditions: [MediaCondition{ feature: 'width', op: 'min', value: '900px' }]
	}], env)
	assert media_list_matches([MediaQuery{
		conditions: [MediaCondition{ feature: 'resolution', op: 'min', value: '2dppx' }]
	}], env)
	unknown_dpi := StyleQueryEnv{
		...env
		dpi: 0
	}
	assert !media_list_matches([MediaQuery{
		conditions: [MediaCondition{ feature: 'resolution', op: 'min', value: '1dppx' }]
	}], unknown_dpi)
}

fn test_media_eval_negation_and_empty() {
	env := query_test_env()
	assert media_list_matches([]MediaQuery{}, env)
	assert !media_list_matches([MediaQuery{
		negate:     true
		conditions: [MediaCondition{ feature: 'platform', value: 'windows' }]
	}], env)
	assert media_list_matches([MediaQuery{
		negate:     true
		conditions: [MediaCondition{ feature: 'platform', value: 'ios' }]
	}], env)
}

// ── container evaluation ────────────────────────────────────────

fn query_test_ancestors() ([]StyleAncestor, []StyleAncestor) {
	root := view('root', rect(0, 0, 1000, 800), BoxStyle{}, [])
	wide := with_classes(view('wide', rect(0, 0, 500, 200), BoxStyle{}, []), 'panel')
	narrow := view('narrow', rect(0, 0, 200, 200), BoxStyle{}, [])
	wide_chain := [StyleAncestor{ el: root, index: 0, count: 1 },
		StyleAncestor{ el: wide, index: 0, count: 2 }]
	narrow_chain := [StyleAncestor{ el: root, index: 0, count: 1 },
		StyleAncestor{ el: narrow, index: 1, count: 2 }]
	return wide_chain, narrow_chain
}

fn test_container_eval_parent_width() {
	wide_chain, narrow_chain := query_test_ancestors()
	query := ContainerQuery{
		conditions: [MediaCondition{ feature: 'width', op: 'min', value: '400px' }]
	}
	assert container_list_matches([query], wide_chain)
	assert !container_list_matches([query], narrow_chain)
}

fn test_container_eval_named_id_and_class() {
	wide_chain, _ := query_test_ancestors()
	by_id := ContainerQuery{
		name:       'wide'
		conditions: [MediaCondition{ feature: 'width', op: 'min', value: '400px' }]
	}
	assert container_list_matches([by_id], wide_chain)
	by_class := ContainerQuery{
		name: 'panel'
	}
	assert container_list_matches([by_class], wide_chain)
	missing := ContainerQuery{
		name: 'sidebar'
	}
	assert !container_list_matches([missing], wide_chain)
	assert container_list_matches([]ContainerQuery{}, wide_chain)
}

// ── cascade integration ─────────────────────────────────────────

fn test_cascade_media_platform_applies() {
	here := stylesheet_platform_name()
	sheet := parse_stylesheet('@media (platform: ${here}) { Button { background: #123456; } } @media not (platform: ${here}) { Button { color: white; } }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [query_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x123456
	assert root.children[0].text_style.color == 0x111111
}

fn test_cascade_container_sizes_gate_rules() {
	sheet := parse_stylesheet('@container (min-width: 400px) { Button { background: #123456; } }')!
	wide := view('wide', rect(0, 0, 500, 100), BoxStyle{}, [query_test_button('a')])
	narrow := view('narrow', rect(0, 0, 200, 100), BoxStyle{}, [query_test_button('b')])
	mut root := view('root', rect(0, 0, 700, 100), BoxStyle{}, [wide, narrow])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].children[0].box.bg == 0x123456
	assert root.children[1].children[0].box.bg == 0xffffff
}

fn test_cascade_media_dark_scheme() {
	sheet := parse_stylesheet('@media (prefers-color-scheme: dark) { Button { background: #111111; } }')!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [query_test_button('a')])
	light := apply_stylesheet(root, sheet, StyleMatchEnv{ dark: false })
	dark := apply_stylesheet(root, sheet, StyleMatchEnv{ dark: true })
	assert light.children[0].box.bg == 0xffffff
	assert dark.children[0].box.bg == 0x111111
}

fn test_dsl_guarded_rule() {
	rule := style_rule_guarded('Button', {
		'background': '#123456'
	}, '(platform: ${stylesheet_platform_name()})', '')!
	sheet := stylesheet_from_rules([rule], map[string]string{})
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [query_test_button('a')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x123456
	if _ := style_rule_guarded('Button', {
		'background': '#123456'
	}, '(orientation: sideways)',
		'') {
		assert false, 'bad guarded orientation must fail'
	} else {
		assert err.msg().contains('orientation')
	}
}
