module ui2

import math

fn color_close(got u32, want u32, tolerance int) bool {
	for shift in [16, 8, 0] {
		got_channel := int((got >> u32(shift)) & 0xff)
		want_channel := int((want >> u32(shift)) & 0xff)
		if math.abs(got_channel - want_channel) > tolerance {
			return false
		}
	}
	return true
}

fn test_color_lab_black_white() {
	black := component_theme_token('lab(0% 0 0)')!
	assert black.color == 0x000000
	white := component_theme_token('lab(100% 0 0)')!
	assert white.color == 0xffffff
}

fn test_color_lch_white() {
	white := component_theme_token('lch(100% 0 0deg)')!
	assert white.color == 0xffffff
}

fn test_color_oklab_black_white() {
	black := component_theme_token('oklab(0 0 0)')!
	assert black.color == 0x000000
	white := component_theme_token('oklab(1 0 0)')!
	assert white.color == 0xffffff
}

fn test_color_oklch_red_approx() {
	red := component_theme_token('oklch(62.8% 0.258 29.2)')!
	assert color_close(red.color, 0xff0000, 3)
	wrapped := component_theme_token('oklch(62.8% 0.258 389.2)')!
	assert color_close(wrapped.color, 0xff0000, 3)
}

fn test_color_hwb_basics() {
	red := component_theme_token('hwb(0 0% 0%)')!
	assert red.color == 0xff0000
	white := component_theme_token('hwb(0 100% 0%)')!
	assert white.color == 0xffffff
	gray := component_theme_token('hwb(0 50% 50%)')!
	assert gray.color == 0x808080 || gray.color == 0x7f7f7f
}

fn test_color_gray() {
	mid := component_theme_token('gray(50%)')!
	assert mid.color == 0x808080
	black := component_theme_token('gray(0)')!
	assert black.color == 0x000000
}

fn test_color_function_srgb() {
	red := component_theme_token('color(srgb 1 0 0)')!
	assert red.color == 0xff0000
	also_red := component_theme_token('color(srgb 100% 0% 0%)')!
	assert also_red.color == 0xff0000
	white := component_theme_token('color(display-p3 1 1 1)')!
	assert white.color == 0xffffff
	black := component_theme_token('color(rec2020 0 0 0)')!
	assert black.color == 0x000000
}

fn test_color_function_rejects() {
	if _ := component_theme_token('color(foo 1 0 0)') {
		assert false, 'unknown space must fail'
	}
	if _ := component_theme_token('lab(50% 20)') {
		assert false, 'wrong arity must fail'
	}
	if _ := component_theme_token('gray(red)') {
		assert false, 'non-numeric gray must fail'
	}
}

fn test_relative_identity() {
	red := component_theme_token('rgb(from #ff0000 r g b)')!
	assert red.color == 0xff0000
	reordered := component_theme_token('rgb(from #0000ff b g r)')!
	assert reordered.color == 0xff0000
	omitted := component_theme_token('rgb(from #ff0000 r g)')!
	assert omitted.color == 0xff0000
	alpha_kept := component_theme_token('hsl(from #ff0000 h s l / 50%)')!
	assert alpha_kept.color == 0xff0000
	assert alpha_kept.opacity == 0.5
	white := component_theme_token('lab(from #ffffff l a b)')!
	assert white.color == 0xffffff
}

fn test_relative_transforms() {
	gray := component_theme_token('rgb(from white calc(r / 2) calc(g / 2) calc(b / 2))')!
	assert gray.color == 0x808080
	swapped := component_theme_token('rgb(from rgb(10, 20, 30) b g r)')!
	assert swapped.color == 0x1e140a
	nested := component_theme_token('rgb(from rgb(from #ff0000 r g b) r g b)')!
	assert nested.color == 0xff0000
	ok := component_theme_token('oklab(from red l a b)')!
	assert ok.color == 0xef4444
}

fn test_relative_rejects() {
	if _ := component_theme_token('rgb(from nowhere r g b)') {
		assert false, 'unknown origin must fail'
	}
	if _ := component_theme_token('rgb(from red q g b)') {
		assert false, 'unknown channel word must fail'
	}
	if _ := component_theme_token('rgb(from red r g b / 50% / 25%)') {
		assert false, 'double alpha must fail'
	}
}

fn test_color_mix_still_works() {
	mix := component_theme_token('color-mix(in srgb, red, blue)')!
	assert mix.color == 0x95639d || mix.color == 0x95639e
}

fn color_test_fails(value string) bool {
	if _ := component_theme_token(value) {
		return false
	}
	return true
}

fn test_color_malformed_values_error_instead_of_panicking() {
	for bad in ['rgb(from )', 'hsl( from )', 'lch(from  )', 'lab(', 'gray(50', 'oklch(0.5 0.1',
		'color-mix(in srgb, red, )', 'color-mix(in srgb, , blue)', 'gray(from white light)',
		'color(srgb 1 0 0 0.5)', 'color-mix(in srgb, red -10%, blue)',
		'color-mix(in srgb, red 150%, blue)'] {
		assert color_test_fails(bad), '${bad} must fail'
	}
}

fn test_color_hwb_bare_numbers_are_percent_scale() {
	green := component_theme_token('hwb(120 30 50)')!
	assert color_close(green.color, 0x4d804d, 1)
	white := component_theme_token('hwb(from white h w b)')!
	assert white.color == 0xffffff
}

fn test_color_relative_alpha_ident() {
	red := component_theme_token('rgb(from #ff0000 r g b / alpha)')!
	assert red.color == 0xff0000
	assert red.opacity == 1.0
	half := component_theme_token('rgb(from rgba(255, 0, 0, 0.5) r g b / calc(alpha / 2))')!
	assert half.opacity == 0.25
}

fn test_color_relative_gray_round_trips() {
	gray := component_theme_token('gray(from #808080 g)')!
	assert color_close(gray.color, 0x808080, 1)
}

fn test_color_wide_gamut_transfer_functions() {
	rec := component_theme_token('color(rec2020 0.2 0.2 0.2)')!
	assert color_close(rec.color, 0x434343, 1)
	p3 := component_theme_token('color(display-p3 0.5 0.5 0.5)')!
	assert color_close(p3.color, 0x808080, 1)
	a98 := component_theme_token('color(a98-rgb 0.5 0.5 0.5)')!
	assert color_close(a98.color, 0x808080, 2)
	pro := component_theme_token('color(prophoto-rgb 1 1 1)')!
	assert color_close(pro.color, 0xffffff, 1)
	p3_red := component_theme_token('color(from #ff0000 display-p3 r g b)')!
	assert color_close(p3_red.color, 0xff0000, 1)
}

fn test_color_lab_percent_reference_ranges() {
	percent := component_theme_token('lab(50% 100% 0)')!
	number := component_theme_token('lab(50 125 0)')!
	assert percent.color == number.color
	chroma_percent := component_theme_token('oklch(60% 50% 30)')!
	chroma_number := component_theme_token('oklch(0.6 0.2 30)')!
	assert chroma_percent.color == chroma_number.color
	negative := component_theme_token('lch(50% -10 90)')!
	gray := component_theme_token('lch(50% 0 90)')!
	assert negative.color == gray.color
}

fn test_color_mix_premultiplies_and_scales() {
	// A transparent side must not darken the mix.
	faded := component_theme_token('color-mix(in srgb, transparent, #ff0000)')!
	assert faded.color == 0xff0000
	assert faded.opacity == 0.5
	// Shares under 100% scale the alpha down.
	thin := component_theme_token('color-mix(in srgb, red 20%, blue 20%)')!
	assert thin.opacity > 0.39 && thin.opacity < 0.41
	// A leading percentage works like a trailing one.
	lead := component_theme_token('color-mix(in srgb, 25% red, blue)')!
	trail := component_theme_token('color-mix(in srgb, red 25%, blue)')!
	assert lead.color == trail.color
}
