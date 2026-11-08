// SPDX-License-Identifier: Apache-2.0
// Includes gradient and Aurora parsing cases adapted from GPUI Kit's theme
// tests (crates/component/src/theme/color.rs and schema.rs; Longbridge,
// copyright 2024 - 2026); the other tests are new. See third_party/gpui-kit.
module ui2

import math

fn theme_test_token(value string) ComponentThemeToken {
	return component_theme_token(value) or { panic('${value}: ${err}') }
}

fn theme_test_rejects(value string) {
	if token := component_theme_token(value) {
		assert false, '"${value}" parsed as ${token}'
	}
}

fn theme_test_set(source string) ComponentThemeSet {
	return component_theme_set_from_json(source) or { panic(err) }
}

fn theme_test_close(a f64, b f64) bool {
	return math.abs(a - b) < 1e-9
}

// ── Modes ───────────────────────────────────────────────────────────

fn test_theme_modes_resolve_against_the_system_appearance() {
	assert component_theme_mode_from_name(' Dark ')? == .dark
	assert component_theme_mode_from_name('light')? == .light
	assert component_theme_mode_from_name('system')? == .system
	assert component_theme_mode_from_name('auto')? == .system
	if _ := component_theme_mode_from_name('dim') {
		assert false, 'unknown mode accepted'
	}
	assert !component_theme_mode_is_dark(.light, .dark)
	assert component_theme_mode_is_dark(.dark, .light)
	assert component_theme_mode_is_dark(.system, .dark)
	assert !component_theme_mode_is_dark(.system, .light)
	assert !component_theme_mode_is_dark(.system, .unknown)
	for mode in [ComponentThemeMode.light, .dark, .system] {
		assert component_theme_mode_from_name(mode.str())? == mode
	}
}

fn test_system_appearance_is_known_on_apple_platforms() {
	appearance := system_appearance()
	$if macos {
		assert appearance != .unknown
	}
	assert appearance in [SystemAppearance.unknown, .light, .dark]
}

// ── Color values ────────────────────────────────────────────────────

fn test_theme_colors_parse_hex_and_css_functions() {
	assert theme_test_token('#2563eb') == ComponentThemeToken{
		color: 0x2563eb
	}
	assert theme_test_token(' #FFF ').color == 0xffffff
	short := theme_test_token('#f008')
	assert short.color == 0xff0000 && theme_test_close(short.opacity, 0x88 / 255.0)
	long := theme_test_token('#EEE8D599')
	assert long.color == 0xeee8d5 && theme_test_close(long.opacity, 0.6)
	assert theme_test_token('rgb(37, 99, 235)').color == 0x2563eb
	assert theme_test_token('rgb(37 99 235)').color == 0x2563eb
	assert theme_test_token('RGB(100%, 0%, 50%)').color == 0xff0080
	half := theme_test_token('rgba(37, 99, 235, 0.5)')
	assert half.color == 0x2563eb && theme_test_close(half.opacity, 0.5)
	slash := theme_test_token('rgb(37 99 235 / 25%)')
	assert slash.color == 0x2563eb && theme_test_close(slash.opacity, 0.25)
	assert theme_test_token('hsl(0, 100%, 50%)').color == 0xff0000
	assert theme_test_token('hsl(120deg 100% 25%)').color == 0x008000
	translucent := theme_test_token('hsla(240, 100%, 50%, 0.4)')
	assert translucent.color == 0x0000ff && theme_test_close(translucent.opacity, 0.4)
	clamped := theme_test_token('rgba(300, -5, 0, 2)')
	assert clamped.color == 0xff0000 && clamped.opacity == 1.0
}

fn test_theme_colors_parse_the_tailwind_palette() {
	assert component_theme_palette_color('blue', 500)? == 0x3b82f6
	assert component_theme_palette_color('Neutral', 950)? == 0x0a0a0a
	assert component_theme_palette_color('rose', 50)? == 0xfff1f2
	if _ := component_theme_palette_color('blue', 550) {
		assert false, 'unknown shade accepted'
	}
	if _ := component_theme_palette_color('beige', 500) {
		assert false, 'unknown family accepted'
	}
	assert theme_test_token('blue').color == 0x3b82f6
	assert theme_test_token('red-600').color == 0xdc2626
	grid := theme_test_token('neutral-200/60')
	assert grid.color == 0xe5e5e5 && theme_test_close(grid.opacity, 0.6)
	faint := theme_test_token('black/5')
	assert faint.color == 0 && theme_test_close(faint.opacity, 0.05)
	assert theme_test_token('white') == ComponentThemeToken{
		color: 0xffffff
	}
	clear := theme_test_token('transparent')
	assert clear.opacity == 0
}

fn test_theme_colors_reject_malformed_values() {
	for value in ['', '   ', '#12', '#12345', '#gggggg', 'blu-500', 'blue-55', 'blue-0500', 'blue-',
		'blue/101', 'blue/x', 'rgb(1, 2)', 'rgb(1, 2, 3, 4, 5)', 'rgb(1 2 3 / )', 'rgb(a, b, c)',
		'hsl(x, 10%, 10%)', 'hsl(1, 2%, 3%) / 4', 'cmyk(1, 2, 3)', 'rgb(1e3, 0, 0)', 'red 50%'] {
		theme_test_rejects(value)
	}
}

// ── Gradients ───────────────────────────────────────────────────────

fn test_theme_gradients_follow_css_angles_and_stops() {
	// From GPUI Kit's test_try_parse_background_linear_gradient.
	diagonal := theme_test_token('linear-gradient(135deg, #4F46E5, #06B6D4)')
	assert diagonal.has_gradient()
	assert diagonal.color == 0x4f46e5
	assert diagonal.gradient.angle == 45 // CSS 135deg: towards the bottom right.
	assert diagonal.gradient.stops == [gradient_stop(0x4f46e5, 0), gradient_stop(0x06b6d4, 1)]
	// From test_try_parse_background_linear_gradient_direction_and_stops.
	across := theme_test_token('linear-gradient(to right, red-500 25%, blue-600 75%)')
	assert across.gradient.angle == 0
	assert across.gradient.stops == [gradient_stop(0xef4444, 0.25), gradient_stop(0x2563eb, 0.75)]
	down := theme_test_token('linear-gradient(#ffffff, #f8fafc)')
	assert down.gradient.angle == 90 // CSS's default runs to the bottom.
	up := theme_test_token('LINEAR-GRADIENT(to top, white, black)')
	assert up.gradient.angle == 270
	corner := theme_test_token('linear-gradient(to left top, white, black)')
	assert corner.gradient.angle == 225
	turn := theme_test_token('linear-gradient(0.5turn, white, black)')
	assert turn.gradient.angle == 90
	three := theme_test_token('linear-gradient(90deg, red, rgb(0 128 0 / 50%), blue 80%)')
	assert three.gradient.stops.map(it.position) == [0.0, 0.4, 0.8]
	assert theme_test_close(three.gradient.stops[1].opacity, 0.5)
	backwards := theme_test_token('linear-gradient(red 60%, blue 20%)')
	assert backwards.gradient.stops.map(it.position) == [0.6, 0.6]
	translucent := theme_test_token('linear-gradient(#3b82f600, #3b82f6)')
	assert translucent.opacity == 0 && translucent.gradient.stops[1].opacity == 1
	for value in ['linear-gradient(red)', 'linear-gradient(90deg, red)', 'linear-gradient(red, blue',
		'linear-gradient(red, nope)', 'linear-gradient(to middle, red, blue)',
		'linear-gradient(to left right, red, blue)', 'linear-gradient(red x%, blue)'] {
		theme_test_rejects(value)
	}
}

fn test_theme_tokens_make_box_styles() {
	solid := theme_test_token('#2563eb80').box(6)
	assert solid.bg == 0x2563eb && solid.radius == 6 && !solid.transparent
	assert theme_test_close(solid.opacity, 0x80 / 255.0)
	assert !box_has_gradient(solid)
	clear := theme_test_token('transparent').box(0)
	assert clear.transparent
	gradient := theme_test_token('linear-gradient(180deg, #1E293B, #0F172A)').box(8)
	assert box_has_gradient(gradient)
	assert gradient.gradient.angle == 90 && gradient.opacity == 1 && gradient.radius == 8
	assert theme_test_token('#00000080').over(0xffffff) == 0x7f7f7f
}

// ── Mapping onto ComponentTheme ─────────────────────────────────────

fn test_theme_variant_without_colors_is_the_default_theme() {
	for dark in [false, true] {
		variant := component_theme_variant('Empty', dark, map[string]string{})
		assert variant.theme == component_theme(dark)
		assert variant.dark == dark
		assert variant.ignored.len == 0
		assert variant.tokens['primary.background'] or { panic('missing') } == ComponentThemeToken{
			color: component_theme(dark).primary
		}
		assert variant.tokens.len == 13
	}
	only_primary := component_theme_variant('Violet', false, {
		'primary.background': 'violet-600'
	})
	assert only_primary.theme == ComponentTheme{
		...component_theme(false)
		primary:            0x7c3aed
		primary_foreground: 0xffffff
	}
}

fn test_theme_variant_maps_keys_with_fallbacks() {
	variant := component_theme_variant('Brown', true, {
		'background':         '#2b211b'
		'foreground':         '#f2e6d8'
		'primary.background': 'linear-gradient(135deg, #e0a458, #c96f3b)'
		'base.green':         '#8fb573'
		'base.yellow':        '#e6c06b'
		'base.red':           '#e07a5f'
		'danger.foreground':  '#e07a5f'
		'muted.background':   '#ffffff1a'
		'chart.1':            'nope'
	})
	theme := variant.theme
	assert theme.background == 0x2b211b && theme.foreground == 0xf2e6d8
	// Translucent colors are flattened over the background.
	assert theme.muted == color_over(0xffffff, 0x1a / 255.0, 0x2b211b)
	assert theme.muted_foreground == choice_mix(theme.muted, theme.foreground, 0.7)
	assert theme.border == choice_mix(theme.background, theme.foreground, 0.18)
	// A gradient stands in as its first stop.
	assert theme.primary == 0xe0a458
	assert variant.gradient('primary.background')?.stops.len == 2
	// No primary.foreground: the better of the background and foreground.
	assert theme.primary_foreground == 0x2b211b
	assert theme.success == 0x8fb573 && theme.warning == 0xe6c06b && theme.danger == 0xe07a5f
	assert theme.success_foreground == theme.primary_foreground
	// danger.foreground equal to its fill cannot be read; it is replaced.
	assert theme.danger_foreground == 0x2b211b
	assert variant.ignored == ['chart.1']
	assert 'chart.1' !in variant.tokens
}

fn test_theme_variant_keeps_readable_foregrounds_and_fixes_unreadable_ones() {
	// GPUI Kit's Default Dark gives red-600 text for a red-400 fill (1.7:1).
	variant := component_theme_variant('Pairs', true, {
		'background':         'neutral-950'
		'foreground':         'neutral-50'
		'primary.background': '#55b4d3'
		'primary.foreground': '#fafafa'
		'danger.background':  'red-400'
		'danger.foreground':  'red-600'
		'success.background': 'green-400'
	})
	// White on #55b4d3 is 2.3:1, a choice upstream themes make; it is kept.
	assert variant.theme.primary_foreground == 0xfafafa
	assert variant.theme.danger_foreground == 0x0a0a0a
	assert choice_contrast(variant.theme.success, variant.theme.success_foreground) >= 2
}

fn test_theme_variant_of_wraps_a_component_theme() {
	custom := ComponentTheme{
		...component_theme(true)
		primary: 0xf472b6
	}
	variant := component_theme_variant_of('Pink Dark', custom)
	assert variant.dark && variant.theme == custom
	assert variant.color('primary.background', 0) == 0xf472b6
	assert variant.color('sidebar.background', 0x123456) == 0x123456
	assert !component_theme_variant_of('Light', component_theme(false)).dark
}

// ── Theme files ─────────────────────────────────────────────────────

const theme_test_file = '{
  "name": "Harbor",
  "author": "Docks",
  "url": "https://example.com/harbor",
  "themes": [
    {
      "name": "Harbor Light",
      "mode": "light",
      "radius": 4,
      "radius.lg": 10,
      "colors": {
        "background": "#f7fafc",
        "primary.background": "#0f766e",
        "card.background": "linear-gradient(135deg, teal-50, white)",
        "chart.2": 12
      }
    },
    {
      "name": "Harbor Dark",
      "mode": "dark",
      "shadow": false,
      "colors": { "background": "#0b1416", "primary.background": "teal-400" },
      "highlight": { "syntax": { "keyword": { "color": "#ff0000" } } }
    },
    { "name": "Harbor Dusk", "mode": "dark", "is_default": true, "colors": { "background": "#132026" } },
    { "name": "harbor light", "mode": "dark", "colors": {} }
  ]
}'

fn test_theme_files_load_in_upstream_format() {
	set := theme_test_set(theme_test_file)
	assert set.name == 'Harbor' && set.author == 'Docks' && set.url == 'https://example.com/harbor'
	// The duplicate name is skipped, as upstream skips it.
	assert set.variants.map(it.name) == ['Harbor Light', 'Harbor Dark', 'Harbor Dusk']
	light := set.variant(false)
	assert light.name == 'Harbor Light' && !light.dark
	assert light.radius == 4 && light.radius_lg == 10 && light.shadow
	assert light.theme.primary == 0x0f766e
	assert light.ignored == ['chart.2']
	assert light.gradient('card.background')?.stops[0].color == 0xf0fdfa
	// is_default picks the dark variant over the first one.
	assert set.variant(true).name == 'Harbor Dusk'
	dark := set.variant_named('HARBOR DARK')?
	assert dark.dark && !dark.shadow && dark.radius == 6
	assert dark.theme.primary == 0x2dd4bf
	assert set.has_mode(false) && set.has_mode(true)
	assert set.theme(true).background == 0x132026
}

fn test_a_single_theme_object_loads_as_a_set_of_one() {
	set := theme_test_set('{"name": "Mono", "mode": "dark", "colors": {"primary.background": "#ffffff"}}')
	assert set.name == 'Mono'
	assert set.variants.len == 1 && set.variant(true).dark
	// A dark-only set stays dark when asked for light.
	assert set.variant(false).name == 'Mono'
	assert !set.has_mode(false)
	assert set.theme(false).primary == 0xffffff
}

fn test_theme_files_report_structural_errors() {
	for source, message in {
		'{"name": "x", "themes": [':                       'does not parse'
		'[1, 2]':                                          'not an object'
		'{"name": "x"}':                                   'no themes'
		'{"name": "x", "themes": []}':                     'no themes'
		'{"name": "x", "themes": {}}':                     'not an array'
		'{"themes": [42]}':                                'not an object'
		'{"themes": [{"mode": "dark"}]}':                  'has no name'
		'{"themes": [{"name": "A", "mode": "dim"}]}':      'mode "dim"'
		'{"themes": [{"name": "A", "colors": ["#fff"]}]}': 'not an object'
	} {
		component_theme_set_from_json(source) or {
			assert err.msg().contains(message), '${source}: ${err.msg()}'
			continue
		}
		assert false, '${source} loaded'
	}
}

fn test_theme_set_variant_choice() {
	set := theme_test_set(theme_test_file)
	frappe := set.with_variants('', 'Harbor Dark') or { panic(err) }
	assert frappe.variant(true).name == 'Harbor Dark'
	assert frappe.variant(false).name == 'Harbor Light'
	if _ := set.with_variants('Harbor Dark', '') {
		assert false, 'a dark variant accepted for light'
	}
	if _ := set.with_variants('', 'Harbor Night') {
		assert false, 'a missing variant accepted'
	}
	empty := ComponentThemeSet{
		name: 'Empty'
	}
	assert empty.theme(true) == component_theme(true)
}

fn test_theme_sets_round_trip_through_json() {
	set := theme_test_set(theme_test_file)
	written := component_theme_set_json(set)
	again := theme_test_set(written)
	assert again.name == set.name && again.author == set.author && again.url == set.url
	assert again.variants.map(it.name) == set.variants.map(it.name)
	for index, variant in again.variants {
		original := set.variants[index]
		assert variant.theme == original.theme
		assert variant.dark == original.dark && variant.radius == original.radius
		assert variant.shadow == original.shadow && variant.is_default == original.is_default
		assert variant.tokens.len == original.tokens.len
		assert variant.ignored.len == 0
	}
	assert component_theme_set_json(again) == written
	assert theme_test_token('linear-gradient(to right, red-500 25%, blue-600 75%)').css() == 'linear-gradient(90deg, #ef4444 25%, #2563eb 75%)'
	assert theme_test_token('rgba(255, 0, 0, 0.5)').css() == '#ff000080'
	assert theme_number_text(12.5) == '12.5' && theme_number_text(-0.25) == '-0.25'
	assert theme_number_text(33.333) == '33.33' && theme_number_text(40) == '40'
}

// ── Sets and the registry ───────────────────────────────────────────

fn test_the_default_set_is_component_theme() {
	set := component_theme_default_set()
	assert set.name == 'Default'
	assert set.theme(false) == component_theme(false)
	assert set.theme(true) == component_theme(true)
	assert set.variant(false).name == 'Default Light'
	assert set.variant(true).name == 'Default Dark'
	assert set.variant(true).tokens['border'] or { panic('missing') }.color == component_theme(true).border
}

fn test_an_empty_registry_holds_the_default_set() {
	registry := ComponentThemeRegistry{}
	assert registry.names() == ['Default']
	assert registry.theme('Default', false) == component_theme(false)
	assert registry.theme('No such theme', true) == component_theme(true)
	assert registry.resolve('Default', .dark).theme == component_theme(true)
	assert registry.resolve('Default', .light).theme == component_theme(false)
	assert registry.cycle('Default', 1) == 'Default'
}

fn test_registry_registers_finds_replaces_and_removes() {
	mut registry := ComponentThemeRegistry{}
	harbor := registry.load_json(theme_test_file) or { panic(err) }
	assert harbor.name == 'Harbor'
	assert registry.names() == ['Default', 'Harbor']
	assert registry.find('harbor')?.name == 'Harbor'
	// Upstream looks themes up by a variant's name.
	assert registry.find('Harbor Dark')?.name == 'Harbor'
	assert registry.variant('Harbor Dark', true).name == 'Harbor Dark'
	assert registry.variant('Harbor Dark', false).name == 'Harbor Light'
	assert registry.variant('Harbor', true).name == 'Harbor Dusk'
	if _ := registry.find('Nowhere') {
		assert false, 'unknown set found'
	}
	registry.register(ComponentThemeSet{
		name:     'HARBOR'
		variants: [component_theme_variant('Only', false, {
			'background': '#fff7ed'
		})]
	}) or { panic(err) }
	assert registry.names() == ['Default', 'HARBOR']
	assert registry.theme('harbor', true).background == 0xfff7ed
	if _ := registry.register(ComponentThemeSet{ name: ' ' }) {
		assert false, 'unnamed set registered'
	}
	if _ := registry.register(ComponentThemeSet{ name: 'Hollow' }) {
		assert false, 'empty set registered'
	}
	// A set named Default replaces the built-in one until it is removed.
	registry.register(ComponentThemeSet{
		name:     'default'
		variants: [component_theme_variant('Mine', false, {
			'primary.background': '#ff0000'
		})]
	}) or { panic(err) }
	assert registry.names() == ['HARBOR', 'default']
	assert registry.theme('Default', false).primary == 0xff0000
	assert registry.theme('Nowhere', false).primary == 0xff0000
	assert registry.remove('Default')
	assert registry.names() == ['Default', 'HARBOR']
	assert !registry.remove('Default')
	assert registry.theme('Default', false) == component_theme(false)
	if _ := registry.load_json('{}') {
		assert false, 'empty file loaded'
	}
}

fn test_registry_cycles_through_its_sets() {
	registry := component_theme_registry()
	names := registry.names()
	assert registry.cycle(names[0], 1) == names[1]
	assert registry.cycle(names[0], -1) == names.last()
	assert registry.cycle(names.last(), 1) == names[0]
	assert registry.cycle('Solarized Light', 1) == names[names.index('Solarized') + 1]
	assert registry.cycle('Nowhere', 2) == names[2]
}

// ── Bundled sets ────────────────────────────────────────────────────

fn test_bundled_sets_parse_cleanly() {
	registry := component_theme_registry()
	assert registry.names() == ['Default', 'Neutral', 'Aurora', 'Ayu', 'Catppuccin', 'Gruvbox',
		'Solarized', 'Tokyo Night']
	assert component_theme_builtin_sets().len == component_theme_builtin_json().len
	for set in registry.sets() {
		assert set.author.len > 0, set.name
		for variant in set.variants {
			assert variant.ignored.len == 0, '${variant.name}: ${variant.ignored}'
			theme := variant.theme
			assert feedback_is_dark(theme) == variant.dark, variant.name
			for tone in [ComponentTone.primary, .success, .warning, .danger] {
				fill, ink := theme.colors(tone)
				assert choice_contrast(fill, ink) >= component_theme_min_contrast, '${variant.name} ${tone}'
			}
			assert choice_contrast(theme.background, theme.foreground) >= 4.5, variant.name
		}
	}
	assert registry.find('Tokyo Night')?.has_mode(false) == false
	assert registry.variant('Tokyo Night', false).dark
	assert registry.variant('Catppuccin', false).name == 'Catppuccin Latte'
	assert registry.variant('Catppuccin', true).name == 'Catppuccin Mocha'
	neutral := registry.variant('Neutral', false)
	assert neutral.theme.background == 0xffffff && neutral.theme.primary == 0x171717
	assert neutral.theme.border == 0xe5e5e5
}

fn test_aurora_parses_its_gradient_backgrounds() {
	// After GPUI Kit's test_aurora_theme_parses_gradient_backgrounds.
	aurora := component_theme_registry().find('Aurora')?
	assert aurora.variants.len == 1 && !aurora.has_mode(true)
	light := aurora.variant(false)
	assert light.theme.primary == 0x1e293b
	assert light.theme.background == 0xffffff
	assert !light.token('background')?.has_gradient()
	for key in ['button.primary.background', 'progress.bar.background', 'scrollbar.thumb.background',
		'switch.background', 'switch.thumb.background', 'title_bar.background', 'status_bar.background'] {
		assert light.token(key)?.has_gradient(), key
	}
	assert light.gradient('title_bar.background')?.angle == 90
}

fn test_theme_variants_make_surface_boxes() {
	registry := component_theme_registry()
	aurora := registry.variant('Aurora', false)
	card := aurora.card_box(12)
	assert card.bg == 0xf8fafc // group_box.background
	assert card.border_left == 1 && card.border_color == aurora.theme.border
	assert card.radius == 12 && box_has_shadow(card)
	assert !aurora.background_box().transparent
	// Solarized has no group box color, so its card is the popover's.
	solarized := registry.variant('Solarized', false)
	assert solarized.card_box(8).bg == 0xfdf6e3
	flat := component_theme_set_from_json('{"name": "Flat", "shadow": false, "colors": {}}') or {
		panic(err)
	}
	assert !box_has_shadow(flat.variant(false).card_box(8))
	assert flat.variant(false).card_box(8).bg == component_theme(false).background
	gradient := theme_test_set('{"name": "G", "colors": {"background": "linear-gradient(red, blue)"}}')
	assert box_has_gradient(gradient.variant(false).background_box())
	accent := component_theme_accent_gradient(component_theme(false))
	assert accent.stops.len == 2 && accent.stops[0].color == component_theme(false).primary
	assert accent.stops[1].color != accent.stops[0].color
}
