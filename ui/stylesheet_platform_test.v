module ui2

fn platform_test_card(id string) Element {
	return Element{
		kind:    .view
		id:      id
		enabled: true
	}
}

fn platform_test_button(id string) Element {
	return Element{
		kind:    .button
		id:      id
		enabled: true
	}
}

fn platform_test_env(platform string, dark bool) StyleQueryEnv {
	return StyleQueryEnv{
		width:    800
		height:   600
		dpi:      2.0
		platform: platform
		dark:     dark
	}
}

fn test_platform_auto_gates_glass_to_apple() {
	sheet := platform_design_stylesheet(.auto)!
	assert sheet.rules.len == 10
	mut glass := sheet.rules.filter(it.selectors.any(it.parts.any(it.kind.to_lower() == 'view'))
		&& it.media.any(it.conditions.any(it.feature == 'platform'
			&& it.value in ['macos', 'ios'])))
	assert glass.len > 0
	for rule in sheet.rules {
		if rule.media.any(it.conditions.any(it.feature == 'platform' && it.value == 'android')) {
			continue
		}
		if rule.media.len == 0 {
			assert false, 'auto gates every rule behind a platform'
		}
	}
	// An iOS frame matches a glass gate; an Android one does not.
	assert media_list_matches(glass[0].media, platform_test_env('ios', false))
	assert !media_list_matches(glass[0].media, platform_test_env('android', false))
}

fn test_platform_auto_gates_material_to_android() {
	sheet := platform_design_stylesheet(.auto)!
	mut material := sheet.rules.filter(it.media.any(it.conditions.any(it.feature == 'platform'
		&& it.value == 'android')))
	assert material.len == 5
	assert media_list_matches(material[0].media, platform_test_env('android', false))
	assert !media_list_matches(material[0].media, platform_test_env('macos', false))
	assert !media_list_matches(material[0].media, platform_test_env('windows', false))
}

fn test_platform_auto_dark_variants_follow_scheme() {
	sheet := platform_design_stylesheet(.auto)!
	mut dark_glass := sheet.rules.filter(it.media.any(it.conditions.any(it.feature == 'prefers-color-scheme'
		&& it.value == 'dark'))
		&& it.media.any(it.conditions.any(it.feature == 'platform')))
	assert dark_glass.len == 6
	assert media_list_matches(dark_glass[0].media, platform_test_env('macos', true))
	assert !media_list_matches(dark_glass[0].media, platform_test_env('macos', false))
}

fn test_platform_forced_glass_applies_everywhere() {
	sheet := platform_design_stylesheet(.glass)!
	assert sheet.rules.len == 5
	assert sheet.rules.all(it.media.len == 0
		|| it.media.all(it.conditions.all(it.feature == 'prefers-color-scheme')))
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [platform_test_card('c')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	card := root.children[0]
	assert card.box.radius == 12.0
	assert card.box.opacity > 0.59 && card.box.opacity < 0.61
	assert card.box.border_left == 1.0
	assert card.box.shadow.blur == 16.0
}

fn test_platform_forced_glass_dark() {
	sheet := platform_design_stylesheet(.glass)!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [platform_test_card('c')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{ dark: true })
	card := root.children[0]
	// rgba(30, 30, 32, 0.6): the raw color, its alpha as fill opacity, so
	// renderers composite it once over whatever lies beneath.
	assert card.box.bg == 0x1e1e20
	assert card.box.opacity > 0.59 && card.box.opacity < 0.61
}

fn test_platform_forced_material_styles_button() {
	sheet := platform_design_stylesheet(.material)!
	assert sheet.rules.len == 5
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [platform_test_button('b')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	btn := root.children[0]
	assert btn.box.bg == 0x6750a4
	assert btn.text_style.color == 0xffffff
	assert btn.box.radius == 20.0
	assert btn.box.shadow.blur == 6.0
}

fn test_platform_auto_neutral_on_unclaimed_platform() {
	sheet := platform_design_stylesheet(.auto)!
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [platform_test_button('b')])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	// This test binary runs on desktop: no auto gate matches here, so the
	// button keeps its defaults.
	assert root.children[0].box.bg == 0xffffff
	assert root.children[0].box.radius == 0.0
}

fn test_platform_with_design_appends_and_wins_ties() {
	base := parse_stylesheet('Button { background: #123456; border-radius: 2px; }')!
	merged := with_platform_design(base, .material)!
	assert merged.rules.len == base.rules.len + 5
	assert merged.variables.keys() == base.variables.keys()
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [platform_test_button('b')])
	root = apply_stylesheet(root, merged, StyleMatchEnv{})
	// Equal specificity: the later preset rule wins.
	assert root.children[0].box.bg == 0x6750a4
	assert root.children[0].box.radius == 20.0
}

fn test_platform_with_design_keeps_base_vars() {
	base := parse_stylesheet('@ink: #111111;\nButton { color: @ink; }')!
	merged := with_platform_design(base, .glass)!
	assert merged.variables['@ink'] == '#111111'
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [platform_test_button('b')])
	root = apply_stylesheet(root, merged, StyleMatchEnv{})
	assert root.children[0].text_style.color == 0x111111
}
