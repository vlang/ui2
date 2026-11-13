module ui2

import math

// color_channel extracts one sRGB channel of a 0xRRGGBB color: shift 16, 8
// or 0 for red, green and blue.
fn color_channel(color u32, shift u32) f64 {
	return f64((color >> shift) & 0xff)
}

// color_mix blends two 0xRRGGBB colors; t = 0 is a, t = 1 is b. Channels are
// rounded and clamped, so an overshooting t from an elastic transition stays
// in range instead of wrapping the color. It replaces the per-component
// mixers, which all computed this same blend.
fn color_mix(a u32, b u32, t f64) u32 {
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		from := color_channel(a, shift)
		to := color_channel(b, shift)
		out |= u32(math.round(math.max(0.0, math.min(255.0, from + (to - from) * t)))) << shift
	}
	return out
}

// color_tint moves a color amount of the way to white.
fn color_tint(color u32, amount f64) u32 {
	return color_mix(color, 0xffffff, math.max(0.0, math.min(1.0, amount)))
}
