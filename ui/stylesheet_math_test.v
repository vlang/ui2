module ui2

fn math_px(raw string, ctx StyleLengthCtx) f64 {
	return style_length_px(raw, ctx) or { panic('math failed for "${raw}"') }
}

fn math_ctx() StyleLengthCtx {
	return StyleLengthCtx{
		win_w:  800
		win_h:  600
		cont_w: 400
		cont_h: 300
	}
}

fn math_ctx_insets() StyleLengthCtx {
	mut ctx := math_ctx()
	ctx.insets = SafeInsets{
		top:    20
		right:  0
		bottom: 10
		left:   0
	}
	return ctx
}

fn test_math_plain_and_px() {
	ctx := math_ctx()
	assert math_px('12', ctx) == 12.0
	assert math_px('12px', ctx) == 12.0
	assert math_px('0', ctx) == 0.0
}

fn test_math_rejects_garbage_and_bare_percent() {
	ctx := math_ctx()
	if _ := style_length_px('banana', ctx) {
		assert false, 'garbage must fail'
	}
	if _ := style_length_px('50%', ctx) {
		assert false, 'bare % must fail'
	}
	if _ := style_length_px('12em', ctx) {
		assert false, 'em must fail'
	}
}

fn test_math_viewport_units() {
	ctx := math_ctx()
	assert math_px('50vw', ctx) == 400.0
	assert math_px('50vh', ctx) == 300.0
	assert math_px('50vmin', ctx) == 300.0
	assert math_px('50vmax', ctx) == 400.0
	assert math_px('10svw', ctx) == 80.0
	assert math_px('10lvh', ctx) == 60.0
	assert math_px('10dvw', ctx) == 80.0
}

fn test_math_container_units() {
	ctx := math_ctx()
	assert math_px('50cqw', ctx) == 200.0
	assert math_px('50cqh', ctx) == 150.0
	assert math_px('100cqmin', ctx) == 300.0
	assert math_px('100cqmax', ctx) == 400.0
}

fn test_math_env() {
	ctx := math_ctx_insets()
	assert math_px('env(safe-area-inset-top)', ctx) == 20.0
	assert math_px('env(safe-area-inset-bottom)', ctx) == 10.0
	assert math_px('env(safe-area-inset-left)', ctx) == 0.0
	// No insets: fallback wins, else zero.
	plain := math_ctx()
	assert math_px('env(safe-area-inset-top, 24px)', plain) == 24.0
	assert math_px('env(safe-area-inset-top)', plain) == 0.0
	if _ := style_length_px('env(safe-area-inset-middle)', plain) {
		assert false, 'unknown env() must fail'
	}
	if _ := style_length_px('env(safe-area-inset-top, red)', plain) {
		assert false, 'non-length fallback must fail'
	}
}

fn test_math_calc_arithmetic() {
	ctx := math_ctx()
	assert math_px('calc(1px + 2px)', ctx) == 3.0
	assert math_px('calc(10px - 4px)', ctx) == 6.0
	assert math_px('calc(3 * 4px)', ctx) == 12.0
	assert math_px('calc(12px / 4)', ctx) == 3.0
	assert math_px('calc((1px + 2px) * 3)', ctx) == 9.0
	assert math_px('calc(-4px + 10px)', ctx) == 6.0
	if _ := style_length_px('calc(1px + 1deg)', ctx) {
		assert false, 'mixed dimensions must fail'
	}
	if _ := style_length_px('calc(1px / 0)', ctx) {
		assert false, 'division by zero must fail'
	}
	if _ := style_length_px('calc(1px + )', ctx) {
		assert false, 'truncated calc must fail'
	}
}

fn test_math_min_max_clamp() {
	ctx := math_ctx()
	assert math_px('min(10px, 20px, 5px)', ctx) == 5.0
	assert math_px('max(10px, 20px, 5px)', ctx) == 20.0
	assert math_px('max(10px, 50vw)', ctx) == 400.0
	assert math_px('clamp(10px, 50vw, 300px)', ctx) == 300.0
	assert math_px('clamp(10px, 50vw, 500px)', ctx) == 400.0
	if _ := style_length_px('clamp(1px, 2px)', ctx) {
		assert false, 'clamp needs three args'
	}
	if _ := style_length_px('min(1px, 2deg)', ctx) {
		assert false, 'mixed dimensions must fail'
	}
}

fn test_math_round_mod() {
	ctx := math_ctx()
	assert math_px('round(7px, 4px)', ctx) == 8.0
	assert math_px('round(up, 7px, 4px)', ctx) == 8.0
	assert math_px('round(down, 7px, 4px)', ctx) == 4.0
	assert math_px('round(to-zero, 7px, 4px)', ctx) == 4.0
	assert math_px('mod(7px, 4px)', ctx) == 3.0
	assert math_px('rem(7px, 4px)', ctx) == 3.0
	assert math_px('rem(-7px, 4px)', ctx) == -3.0
}

fn test_math_scalar_fns() {
	ctx := math_ctx()
	assert math_px('calc(abs(-5px))', ctx) == 5.0
	assert math_px('calc(sign(-5px) * 10px)', ctx) == -10.0
	assert math_px('calc(sqrt(16) * 1px)', ctx) == 4.0
	assert math_px('calc(hypot(3, 4) * 1px)', ctx) == 5.0
	assert math_px('calc(pow(2, 3) * 1px)', ctx) == 8.0
	assert math_px('calc(sin(0) * 1px + 5px)', ctx) == 5.0
	assert math_px('calc(cos(0deg) * 10px)', ctx) == 10.0
	if _ := style_length_px('calc(sqrt(-1) * 1px)', ctx) {
		assert false, 'sqrt of negative must fail'
	}
	assert math_px('calc(1px + sin(0))', ctx) == 1.0
	if _ := style_length_px('calc(1px + 2deg)', ctx) {
		assert false, 'angle must not add to lengths'
	}
}

fn test_math_mixed_viewport_calc() {
	ctx := math_ctx()
	assert math_px('calc(50vw - 100px)', ctx) == 300.0
	assert math_px('min(90vw, 500px)', ctx) == 500.0
	assert math_px('clamp(10px, 5cqw, 100px)', ctx) == 20.0
}

fn test_color_mix_basics() {
	// Tailwind red-500 (239,68,68) and blue-500 (59,130,246) split evenly.
	even := component_theme_token('color-mix(in srgb, red, blue)')!
	assert even.color == 0x95639d
	assert even.opacity == 1.0
	weighted := component_theme_token('color-mix(in srgb, #ff0000 25%, #0000ff)')!
	assert weighted.color == 0x4000bf
	assert weighted.opacity == 1.0
	white := component_theme_token('color-mix(in srgb, black, white)')!
	assert white.color == 0x808080
}

fn test_color_mix_rejects() {
	if _ := component_theme_token('color-mix(in srgb, red)') {
		assert false, 'one color must fail'
	}
	if _ := component_theme_token('color-mix(in oklch, red, blue)') {
		assert false, 'non-srgb space must fail'
	}
	if _ := component_theme_token('color-mix(in srgb, red 0%, blue 0%)') {
		assert false, 'zero total must fail'
	}
}
