// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted in part from gpui-kit crates/component/src/theme/color.rs and
// schema.rs: the palette-name grammar of try_parse_color, the gradient
// grammar and `to <side>` angles of parse_linear_gradient, the Tailwind
// palette of default-colors.json, and the muted-foreground and tone-foreground
// fallbacks of ThemeColor::apply_config. The rest is new. See third_party/gpui-kit.
module ui2

import math
import x.json2

// Theme files in GPUI Kit's format: a set with a name, author, url and a
// `themes` array, each theme a name, a mode and a `colors` object of
// "key": "value" strings. This file parses the values (hex, rgb(), hsl(),
// Tailwind palette names and linear-gradient()), maps the keys onto
// ComponentTheme with fallbacks for the ones a file leaves out, and writes a
// set back out in the same format.

// ── Palette ─────────────────────────────────────────────────────────

// Theme files may name a color of the Tailwind CSS palette, as GPUI Kit's
// bundled themes do: `blue` (its 500 shade), `blue-600`, `blue-600/50` (at 50%
// opacity) or `neutral/20`.
const component_theme_palette_scales = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]

const component_theme_palette_names = ['slate', 'gray', 'zinc', 'neutral', 'stone', 'red', 'orange',
	'amber', 'yellow', 'lime', 'green', 'emerald', 'teal', 'cyan', 'sky', 'blue', 'indigo', 'violet',
	'purple', 'fuchsia', 'pink', 'rose']

// component_theme_palette_rows holds each family's shades, 50 to 950, in the
// order of component_theme_palette_names.
const component_theme_palette_rows = [
	'f8fafc f1f5f9 e2e8f0 cbd5e1 94a3b8 64748b 475569 334155 1e293b 0f172a 020617' // slate
	'f9fafb f3f4f6 e5e7eb d1d5db 9ca3af 6b7280 4b5563 374151 1f2937 111827 030712' // gray
	'fafafa f4f4f5 e4e4e7 d4d4d8 a1a1aa 71717a 52525b 3f3f46 27272a 18181b 09090b' // zinc
	'fafafa f5f5f5 e5e5e5 d4d4d4 a3a3a3 737373 525252 404040 262626 171717 0a0a0a' // neutral
	'fafaf9 f5f5f4 e7e5e4 d6d3d1 a8a29e 78716c 57534e 44403c 292524 1c1917 0c0a09' // stone
	'fef2f2 fee2e2 fecaca fca5a5 f87171 ef4444 dc2626 b91c1c 991b1b 7f1d1d 450a0a' // red
	'fff7ed ffedd5 fed7aa fdba74 fb923c f97316 ea580c c2410c 9a3412 7c2d12 431407' // orange
	'fffbeb fef3c7 fde68a fcd34d fbbf24 f59e0b d97706 b45309 92400e 78350f 451a03' // amber
	'fefce8 fef9c3 fef08a fde047 facc15 eab308 ca8a04 a16207 854d0e 713f12 422006' // yellow
	'f7fee7 ecfccb d9f99d bef264 a3e635 84cc16 65a30d 4d7c0f 3f6212 365314 1a2e05' // lime
	'f0fdf4 dcfce7 bbf7d0 86efac 4ade80 22c55e 16a34a 15803d 166534 14532d 052e16' // green
	'ecfdf5 d1fae5 a7f3d0 6ee7b7 34d399 10b981 059669 047857 065f46 064e3b 022c22' // emerald
	'f0fdfa ccfbf1 99f6e4 5eead4 2dd4bf 14b8a6 0d9488 0f766e 115e59 134e4a 042f2e' // teal
	'ecfeff cffafe a5f3fc 67e8f9 22d3ee 06b6d4 0891b2 0e7490 155e75 164e63 083344' // cyan
	'f0f9ff e0f2fe bae6fd 7dd3fc 38bdf8 0ea5e9 0284c7 0369a1 075985 0c4a6e 082f49' // sky
	'eff6ff dbeafe bfdbfe 93c5fd 60a5fa 3b82f6 2563eb 1d4ed8 1e40af 1e3a8a 172554' // blue
	'eef2ff e0e7ff c7d2fe a5b4fc 818cf8 6366f1 4f46e5 4338ca 3730a3 312e81 1e1b4b' // indigo
	'f5f3ff ede9fe ddd6fe c4b5fd a78bfa 8b5cf6 7c3aed 6d28d9 5b21b6 4c1d95 1e1b4b' // violet
	'faf5ff f3e8ff e9d5ff d8b4fe c084fc a855f7 9333ea 7e22ce 6b21a8 581c87 3b0764' // purple
	'fdf4ff fae8ff f5d0fe f0abfc e879f9 d946ef c026d3 a21caf 86198f 701a75 4a044e' // fuchsia
	'fdf2f8 fce7f3 fbcfe8 f9a8d4 f472b6 ec4899 db2777 be185d 9d174d 831843 500724' // pink
	'fff1f2 ffe4e6 fecdd3 fda4af fb7185 f43f5e e11d48 be123c 9f1239 881337 4c0519' // rose
]

// component_theme_palette_color returns a Tailwind palette color: `name` is a
// family such as `blue` or `neutral`, `scale` one of 50, 100, 200 … 900, 950.
pub fn component_theme_palette_color(name string, scale int) ?u32 {
	family := component_theme_palette_names.index(name.trim_space().to_lower())
	step := component_theme_palette_scales.index(scale)
	if family < 0 || step < 0 {
		return none
	}
	shade := component_theme_palette_rows[family].fields()[step]
	return (color_parse_hex(shade)?).rgb()
}

// ── Values ──────────────────────────────────────────────────────────

// component_theme_token parses one theme color value:
//   `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`
//   `rgb(37, 99, 235)`, `rgba(37, 99, 235, 0.5)`, `rgb(37 99 235 / 50%)`
//   `hsl(221, 83%, 53%)`, `hsla(221, 83%, 53%, 0.5)`, `hsl(221deg 83% 53% / 0.5)`
//   Tailwind names: `blue`, `blue-600`, `blue-600/50`, `black`, `white`, `transparent`
//   `linear-gradient(135deg, #4f46e5, #06b6d4)`,
//   `linear-gradient(to right, red-500 25%, blue-600 75%)`
// GPUI Kit reads hex, the palette names and two-stop gradients; the CSS color
// functions, angle units other than deg and gradients of more than two stops
// are ui2's additions.
pub fn component_theme_token(value string) !ComponentThemeToken {
	source := value.trim_space()
	if source.len == 0 {
		return error('empty color value')
	}
	if source.to_lower().starts_with('linear-gradient(') {
		return theme_parse_gradient(source)
	}
	color, alpha := theme_parse_color(source)!
	return ComponentThemeToken{
		color:   color
		opacity: alpha
	}
}

fn theme_parse_color(source string) !(u32, f64) {
	lower := source.trim_space().to_lower()
	if lower.starts_with('#') {
		rgba := color_parse_hex(lower) or { return error('"${source}" is not a hex color') }
		return rgba.rgb(), rgba.a
	}
	if lower.ends_with(')') {
		open := lower.index('(') or { return error('"${source}" is not a color') }
		args := theme_color_args(lower[open + 1..lower.len - 1]) or {
			return error('"${source}": ${err.msg()}')
		}
		match lower[..open].trim_space() {
			'rgb', 'rgba' { return theme_rgb(args, source) }
			'hsl', 'hsla' { return theme_hsl(args, source) }
			else { return error('"${source}" uses an unknown color function') }
		}
	}
	return theme_palette_parse(lower, source)
}

struct ThemeColorArgs {
	parts []string
	alpha string
}

// theme_color_args splits the inside of rgb() or hsl() into three components
// and an optional alpha, in the comma form (`1, 2, 3, 0.5`) or the space form
// (`1 2 3 / 50%`).
fn theme_color_args(inner string) !ThemeColorArgs {
	halves := inner.split('/')
	if halves.len > 2 {
		return error('too many slashes')
	}
	mut parts := halves[0].replace(',', ' ').fields()
	mut alpha := ''
	if halves.len == 2 {
		alpha = halves[1].trim_space()
		if alpha.len == 0 || alpha.contains(' ') || alpha.contains(',') {
			return error('the alpha after the slash is malformed')
		}
	} else if parts.len == 4 {
		alpha = parts[3]
		parts = parts[..3].clone()
	}
	if parts.len != 3 {
		return error('expected three components')
	}
	return ThemeColorArgs{
		parts: parts
		alpha: alpha
	}
}

// theme_number reads a plain decimal: an optional sign, digits and at most one
// point. Anything else, exponents included, is none.
fn theme_number(raw string) ?f64 {
	if raw.len == 0 {
		return none
	}
	mut digits := 0
	mut points := 0
	for index, ch in raw.bytes() {
		if ch >= `0` && ch <= `9` {
			digits++
		} else if ch == `.` {
			points++
		} else if !((ch == `-` || ch == `+`) && index == 0) {
			return none
		}
	}
	if digits == 0 || points > 1 {
		return none
	}
	value := raw.f64()
	return if component_finite(value) { value } else { none }
}

// theme_fraction reads `50%` as 0.5, or a plain number scaled by 1/scale.
fn theme_fraction(raw string, scale f64) ?f64 {
	if raw.ends_with('%') {
		return (theme_number(raw[..raw.len - 1])?) / 100
	}
	return (theme_number(raw)?) / scale
}

fn theme_alpha(raw string, source string) !f64 {
	if raw.len == 0 {
		return 1.0
	}
	alpha := theme_fraction(raw, 1) or { return error('"${source}" has a malformed alpha') }
	return unit_clamp(alpha)
}

fn theme_rgb(args ThemeColorArgs, source string) !(u32, f64) {
	mut rgb := u32(0)
	for part in args.parts {
		channel := theme_fraction(part, 255) or {
			return error('"${source}" has a malformed channel')
		}
		rgb = (rgb << 8) | u32(color_channel_byte(channel))
	}
	return rgb, theme_alpha(args.alpha, source)!
}

fn theme_hsl(args ThemeColorArgs, source string) !(u32, f64) {
	hue_text := args.parts[0].trim_string_right('deg')
	hue := theme_number(hue_text) or { return error('"${source}" has a malformed hue') }
	saturation := theme_fraction(args.parts[1], 100) or {
		return error('"${source}" has a malformed saturation')
	}
	lightness := theme_fraction(args.parts[2], 100) or {
		return error('"${source}" has a malformed lightness')
	}
	alpha := theme_alpha(args.alpha, source)!
	return color_from_hsla(hue, saturation, lightness, 1).rgb(), alpha
}

// theme_palette_parse reads `name`, `name-scale`, `name/opacity` and
// `name-scale/opacity`, the way GPUI Kit's try_parse_color does.
fn theme_palette_parse(lower string, source string) !(u32, f64) {
	mut body := lower
	mut alpha := 1.0
	if slash := body.index('/') {
		opacity := theme_number(body[slash + 1..]) or {
			return error('"${source}" has a malformed opacity')
		}
		if opacity < 0 || opacity > 100 {
			return error('"${source}" has an opacity outside 0..100')
		}
		alpha = opacity / 100
		body = body[..slash]
	}
	match body {
		'transparent' { return u32(0), 0.0 }
		'black' { return u32(0x000000), alpha }
		'white' { return u32(0xffffff), alpha }
		else {}
	}
	mut name := body
	mut scale := 500
	if dash := body.last_index('-') {
		name = body[..dash]
		digits := body[dash + 1..]
		scale = component_parse_index(digits, 950) or {
			return error('"${source}" has a malformed shade')
		}
	}
	color := component_theme_palette_color(name, scale) or {
		return error('"${source}" is not a color')
	}
	return color, alpha
}

// ── Gradients ───────────────────────────────────────────────────────

// theme_split_commas splits at the commas outside parentheses.
fn theme_split_commas(value string) []string {
	mut parts := []string{}
	mut depth := 0
	mut start := 0
	for index, ch in value.bytes() {
		match ch {
			`(` {
				depth++
			}
			`)` {
				depth = math.max(0, depth - 1)
			}
			`,` {
				if depth == 0 {
					parts << value[start..index].trim_space()
					start = index + 1
				}
			}
			else {}
		}
	}
	parts << value[start..].trim_space()
	return parts
}

// theme_css_angle reads a CSS gradient angle: `135deg`, `0.25turn`, `1.2rad`,
// `100grad`, or a direction such as `to right` or `to bottom left`. It is in
// CSS degrees, where 0 points up and 90 right.
fn theme_css_angle(raw string) ?f64 {
	value := raw.trim_space().to_lower()
	if value.starts_with('to ') {
		mut top := false
		mut right := false
		mut bottom := false
		mut left := false
		for word in value[3..].fields() {
			match word {
				'top' { top = true }
				'right' { right = true }
				'bottom' { bottom = true }
				'left' { left = true }
				else { return none }
			}
		}
		if (top && bottom) || (left && right) || !(top || right || bottom || left) {
			return none
		}
		return if top && right {
			45.0
		} else if bottom && right {
			135.0
		} else if bottom && left {
			225.0
		} else if top && left {
			315.0
		} else if right {
			90.0
		} else if bottom {
			180.0
		} else if left {
			270.0
		} else {
			0.0
		}
	}
	// `grad` before `rad`, which it ends with.
	units := ['deg', 'grad', 'rad', 'turn']
	degrees := [1.0, 0.9, 180 / math.pi, 360.0]
	for index, unit in units {
		if value.ends_with(unit) {
			return (theme_number(value[..value.len - unit.len])?) * degrees[index]
		}
	}
	return none
}

// theme_box_angle turns a CSS angle (0 up, clockwise) into ui2's Gradient
// angle (0 left to right, clockwise), within [0, 360).
fn theme_box_angle(css f64) f64 {
	angle := math.fmod(css - 90, 360)
	return if angle < 0 { angle + 360 } else { angle }
}

fn theme_css_angle_of(box_angle f64) f64 {
	angle := math.fmod(box_angle + 90, 360)
	return if angle < 0 { angle + 360 } else { angle }
}

// theme_parse_gradient reads `linear-gradient([angle,] color [pos%], color
// [pos%], ...)`. Without an angle it runs to the bottom, as in CSS. Stops
// without a position are spread evenly between their neighbours, and a
// position before an earlier one moves up to it, again as in CSS.
fn theme_parse_gradient(source string) !ComponentThemeToken {
	if !source.ends_with(')') {
		return error('"${source}" does not close its gradient')
	}
	parts := theme_split_commas(source['linear-gradient('.len..source.len - 1])
	mut css := 180.0
	mut stop_parts := parts.clone()
	if parts.len > 0 {
		if angle := theme_css_angle(parts[0]) {
			css = angle
			stop_parts = parts[1..].clone()
		}
	}
	if stop_parts.len < 2 {
		return error('"${source}" needs at least two colors')
	}
	mut colors := []u32{cap: stop_parts.len}
	mut alphas := []f64{cap: stop_parts.len}
	mut positions := []f64{cap: stop_parts.len}
	mut given := []bool{cap: stop_parts.len}
	for part in stop_parts {
		words := part.fields()
		mut color_text := part
		mut position := 0.0
		mut has_position := false
		if words.len > 1 && words.last().ends_with('%') {
			position = (theme_fraction(words.last(), 1) or {
				return error('"${source}" has a malformed stop position')
			})
			has_position = true
			color_text = words[..words.len - 1].join(' ')
		}
		color, alpha := theme_parse_color(color_text)!
		colors << color
		alphas << alpha
		positions << unit_clamp(position)
		given << has_position
	}
	theme_spread_positions(mut positions, given)
	mut stops := []GradientStop{cap: colors.len}
	for index, color in colors {
		stops << GradientStop{
			color:    color
			position: positions[index]
			opacity:  alphas[index]
		}
	}
	return ComponentThemeToken{
		color:    colors[0]
		opacity:  alphas[0]
		gradient: Gradient{
			angle: theme_box_angle(css)
			stops: stops
		}
	}
}

fn theme_spread_positions(mut positions []f64, given []bool) {
	last := positions.len - 1
	if !given[0] {
		positions[0] = 0
	}
	if !given[last] {
		positions[last] = 1
	}
	mut previous := 0
	for index in 1 .. positions.len {
		if index < last && !given[index] {
			continue
		}
		if positions[index] < positions[previous] {
			positions[index] = positions[previous]
		}
		gap := index - previous
		for between in previous + 1 .. index {
			t := f64(between - previous) / f64(gap)
			positions[between] = positions[previous] + (positions[index] - positions[previous]) * t
		}
		previous = index
	}
}

// ── Mapping onto ComponentTheme ─────────────────────────────────────

// A foreground that reads below this contrast on its fill is unreadable, as
// some files' tinted-surface pairs are (red-600 on red-400); it is replaced.
const component_theme_min_contrast = 2.0

fn theme_first(tokens map[string]ComponentThemeToken, keys []string) ?ComponentThemeToken {
	for key in keys {
		if token := tokens[key] {
			return token
		}
	}
	return none
}

// theme_best_text is the theme's background or foreground, whichever reads
// better on fill, or black or white when neither reads.
fn theme_best_text(fill u32, background u32, foreground u32) u32 {
	better := if choice_contrast(fill, background) >= choice_contrast(fill, foreground) {
		background
	} else {
		foreground
	}
	return if choice_contrast(fill, better) >= component_theme_min_contrast {
		better
	} else {
		color_contrast_foreground(fill)
	}
}

// theme_text_on keeps the file's text color for a fill when it reads, and
// otherwise picks theme_best_text.
fn theme_text_on(fill u32, ink u32, background u32, foreground u32) u32 {
	if choice_contrast(fill, ink) >= component_theme_min_contrast {
		return ink
	}
	return theme_best_text(fill, background, foreground)
}

// component_theme_from_tokens fills ComponentTheme from theme-file tokens. The
// key chains and fallbacks are listed in docs/gpui-kit/theme.md. Translucent
// colors are flattened over the background, gradients count as their first
// stop, and missing keys come from the default theme of the mode, or from the
// file's own background and foreground when it sets those.
fn component_theme_from_tokens(tokens map[string]ComponentThemeToken, dark bool) ComponentTheme {
	base := component_theme(dark)
	background := if token := tokens['background'] {
		token.over(base.background)
	} else {
		base.background
	}
	foreground := if token := tokens['foreground'] {
		token.over(background)
	} else {
		base.foreground
	}
	custom := background != base.background || foreground != base.foreground
	muted := if token := theme_first(tokens, ['muted.background', 'secondary.background',
		'accent.background'])
	{
		token.over(background)
	} else if custom {
		choice_mix(background, foreground, 0.08)
	} else {
		base.muted
	}
	muted_foreground := if token := tokens['muted.foreground'] {
		token.over(muted)
	} else if custom || muted != base.muted {
		choice_mix(muted, foreground, 0.7)
	} else {
		base.muted_foreground
	}
	border := if token := theme_first(tokens, ['border', 'input.border']) {
		token.over(background)
	} else if custom {
		choice_mix(background, foreground, 0.18)
	} else {
		base.border
	}
	primary := if token := theme_first(tokens, ['primary.background', 'button.primary.background',
		'base.blue'])
	{
		token.over(background)
	} else {
		base.primary
	}
	primary_text := if token := theme_first(tokens, ['primary.foreground', 'button.primary.foreground'])
	{
		token.over(primary)
	} else if primary == base.primary {
		base.primary_foreground
	} else {
		theme_best_text(primary, background, foreground)
	}
	primary_foreground := theme_text_on(primary, primary_text, background, foreground)
	success := theme_tone(tokens, 'success', 'base.green', background, base.success)
	warning := theme_tone(tokens, 'warning', 'base.yellow', background, base.warning)
	danger := theme_tone(tokens, 'danger', 'base.red', background, base.danger)
	return ComponentTheme{
		background:         background
		foreground:         foreground
		muted:              muted
		muted_foreground:   muted_foreground
		border:             border
		primary:            primary
		primary_foreground: primary_foreground
		success:            success
		success_foreground: theme_tone_text(tokens, 'success', success, base.success,
			base.success_foreground, primary_foreground, background, foreground)
		warning:            warning
		warning_foreground: theme_tone_text(tokens, 'warning', warning, base.warning,
			base.warning_foreground, primary_foreground, background, foreground)
		danger:             danger
		danger_foreground:  theme_tone_text(tokens, 'danger', danger, base.danger,
			base.danger_foreground, primary_foreground, background, foreground)
	}
}

// theme_tone is a tone's fill: `<tone>.background`, else the file's base
// color for it (`base.green` ...), else the default theme's.
fn theme_tone(tokens map[string]ComponentThemeToken, tone string, base_key string, background u32, fallback u32) u32 {
	token := theme_first(tokens, ['${tone}.background', base_key]) or { return fallback }
	return token.over(background)
}

// theme_tone_text is a tone's text: `<tone>.foreground`, else the default
// theme's when the fill is the default's, else the primary foreground as
// upstream falls back; whichever it is must read on the fill.
fn theme_tone_text(tokens map[string]ComponentThemeToken, tone string, fill u32, base_fill u32, base_text u32, primary_text u32, background u32, foreground u32) u32 {
	ink := if token := tokens['${tone}.foreground'] {
		token.over(fill)
	} else if fill == base_fill {
		base_text
	} else {
		primary_text
	}
	return theme_text_on(fill, ink, background, foreground)
}

// theme_fill_tokens adds the keys behind the ComponentTheme fields that the
// file left out, so every variant answers for them.
fn theme_fill_tokens(mut tokens map[string]ComponentThemeToken, theme ComponentTheme) {
	for key, color in {
		'background':         theme.background
		'foreground':         theme.foreground
		'muted.background':   theme.muted
		'muted.foreground':   theme.muted_foreground
		'border':             theme.border
		'primary.background': theme.primary
		'primary.foreground': theme.primary_foreground
		'success.background': theme.success
		'success.foreground': theme.success_foreground
		'warning.background': theme.warning
		'warning.foreground': theme.warning_foreground
		'danger.background':  theme.danger
		'danger.foreground':  theme.danger_foreground
	} {
		if key !in tokens {
			tokens[key] = ComponentThemeToken{
				color: color
			}
		}
	}
}

// component_theme_variant builds a variant from a theme file's `colors`
// object: keys and values as GPUI Kit writes them. Values that do not parse
// are listed in the variant's `ignored` and their keys fall back.
pub fn component_theme_variant(name string, dark bool, colors map[string]string) ComponentThemeVariant {
	mut tokens := map[string]ComponentThemeToken{}
	mut ignored := []string{}
	for key, value in colors {
		token := component_theme_token(value) or {
			ignored << key
			continue
		}
		tokens[key] = token
	}
	theme := component_theme_from_tokens(tokens, dark)
	theme_fill_tokens(mut tokens, theme)
	return ComponentThemeVariant{
		name:    name
		dark:    dark
		theme:   theme
		tokens:  tokens
		ignored: ignored
	}
}

// ── Theme files ─────────────────────────────────────────────────────

fn theme_json_string(object map[string]json2.Any, key string) ?string {
	value := object[key] or { return none }
	return match value {
		string { value }
		else { none }
	}
}

fn theme_json_number(object map[string]json2.Any, key string) ?f64 {
	value := object[key] or { return none }
	number := match value {
		f64 { value }
		f32 { f64(value) }
		i64 { f64(value) }
		int { f64(value) }
		u64 { f64(value) }
		else { return none }
	}
	return if component_finite(number) && number >= 0 { number } else { none }
}

fn theme_json_bool(object map[string]json2.Any, key string) ?bool {
	value := object[key] or { return none }
	return match value {
		bool { value }
		else { none }
	}
}

// theme_json_error keeps the first line of a parse error, without the
// terminal colors x.json2 adds.
fn theme_json_error(message string) string {
	mut line := message.all_before('\n')
	for code in ['\x1b[31m', '\x1b[0m'] {
		line = line.replace(code, '')
	}
	return line.trim_space()
}

fn theme_variant_from_json(value json2.Any, index int) !ComponentThemeVariant {
	object := match value {
		map[string]json2.Any { value }
		else { return error('theme ${index + 1} is not an object') }
	}
	name := (theme_json_string(object, 'name') or { '' }).trim_space()
	if name.len == 0 {
		return error('theme ${index + 1} has no name')
	}
	mode := (theme_json_string(object, 'mode') or { 'light' }).trim_space().to_lower()
	if mode !in ['light', 'dark'] {
		return error('theme "${name}" has mode "${mode}"; use light or dark')
	}
	mut colors := map[string]string{}
	mut ignored := []string{}
	if colors_value := object['colors'] {
		match colors_value {
			map[string]json2.Any {
				for key, color in colors_value {
					if color is string {
						colors[key] = color
					} else {
						ignored << key
					}
				}
			}
			json2.Null {}
			else {
				return error('theme "${name}" has colors that are not an object')
			}
		}
	}
	variant := component_theme_variant(name, mode == 'dark', colors)
	ignored << variant.ignored
	return ComponentThemeVariant{
		...variant
		radius:     theme_json_number(object, 'radius') or { 6.0 }
		radius_lg:  theme_json_number(object, 'radius.lg') or { 8.0 }
		shadow:     theme_json_bool(object, 'shadow') or { true }
		is_default: theme_json_bool(object, 'is_default') or { false }
		ignored:    ignored
	}
}

// component_theme_set_from_json reads a theme file in GPUI Kit's format: an
// object with `name`, `author`, `url` and a `themes` array, each theme with a
// `name`, a `mode` (light, the default, or dark), optional `radius`,
// `radius.lg`, `shadow` and `is_default`, and a `colors` object. A file with a
// single theme object (name, mode, colors) and no `themes` array is read as a
// set of one. Syntax highlighting (`highlight`) and fonts are not read.
//
// The file is an error when it is not JSON, has no themes, or a theme has no
// name or an unknown mode; colors that do not parse only fall back, and are
// listed in their variant's `ignored`. A second theme with an earlier one's
// name is skipped, as upstream does.
pub fn component_theme_set_from_json(source string) !ComponentThemeSet {
	root := json2.decode[json2.Any](source) or {
		return error('theme JSON does not parse: ${theme_json_error(err.msg())}')
	}
	object := match root {
		map[string]json2.Any { root }
		else { return error('theme JSON is not an object') }
	}
	mut entries := []json2.Any{}
	if themes := object['themes'] {
		entries = match themes {
			[]json2.Any { themes }
			else { return error('theme JSON "themes" is not an array') }
		}
	} else if 'colors' in object {
		entries << root
	}
	mut variants := []ComponentThemeVariant{cap: entries.len}
	for index, entry in entries {
		variant := theme_variant_from_json(entry, index)!
		if variants.any(it.name.to_lower() == variant.name.to_lower()) {
			continue
		}
		variants << variant
	}
	if variants.len == 0 {
		return error('theme JSON has no themes')
	}
	mut name := (theme_json_string(object, 'name') or { '' }).trim_space()
	if name.len == 0 || 'themes' !in object {
		name = variants[0].name
	}
	return ComponentThemeSet{
		name:     name
		author:   theme_json_string(object, 'author') or { '' }
		url:      theme_json_string(object, 'url') or { '' }
		variants: variants
	}
}

// ── Writing ─────────────────────────────────────────────────────────

// theme_number_text writes a number with at most two decimals and no
// trailing zeros.
fn theme_number_text(value f64) string {
	scaled := i64(math.round(value * 100))
	whole := scaled / 100
	fraction := math.abs(scaled % 100)
	sign := if scaled < 0 && whole == 0 { '-' } else { '' }
	if fraction == 0 {
		return '${sign}${whole}'
	}
	digits := if fraction % 10 == 0 { '${fraction / 10}' } else { '${fraction:02d}' }
	return '${sign}${whole}.${digits}'
}

// css writes the token back as a theme-file value: `#rrggbb`, `#rrggbbaa`
// when translucent, or a linear-gradient() with every stop's position.
pub fn (token ComponentThemeToken) css() string {
	if !token.has_gradient() {
		return color_hex(token.color & 0xffffff, color_alpha(token.opacity)).to_lower()
	}
	stops := token.gradient.stops.map('${color_hex(it.color & 0xffffff, color_alpha(it.opacity)).to_lower()} ${theme_number_text(unit_clamp(it.position) * 100)}%')
	angle := theme_number_text(theme_css_angle_of(token.gradient.angle))
	return 'linear-gradient(${angle}deg, ${stops.join(', ')})'
}

// component_theme_set_json writes a set in GPUI Kit's theme-file format, so a
// theme built or adjusted in code can be saved and loaded again. Every token
// is written, including the ones filled in for the ComponentTheme fields.
pub fn component_theme_set_json(set ComponentThemeSet) string {
	mut themes := []json2.Any{cap: set.variants.len}
	for variant in set.variants {
		mut colors := map[string]json2.Any{}
		mut keys := variant.tokens.keys()
		keys.sort()
		for key in keys {
			colors[key] = json2.Any(variant.tokens[key].css())
		}
		mut theme := map[string]json2.Any{}
		theme['name'] = json2.Any(variant.name)
		theme['mode'] = json2.Any(if variant.dark { 'dark' } else { 'light' })
		if variant.is_default {
			theme['is_default'] = json2.Any(true)
		}
		theme['radius'] = json2.Any(variant.radius)
		theme['radius.lg'] = json2.Any(variant.radius_lg)
		theme['shadow'] = json2.Any(variant.shadow)
		theme['colors'] = json2.Any(colors)
		themes << json2.Any(theme)
	}
	mut root := map[string]json2.Any{}
	root['name'] = json2.Any(set.name)
	if set.author.len > 0 {
		root['author'] = json2.Any(set.author)
	}
	if set.url.len > 0 {
		root['url'] = json2.Any(set.url)
	}
	root['themes'] = json2.Any(themes)
	return json2.encode(json2.Any(root), prettify: true, indent_string: '  ')
}
