// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// The hex forms color_parse_hex accepts and color_hex writes (#rgb, #rgba,
// #rrggbb and #rrggbbaa, with or without the #, a single digit standing for
// itself repeated, and the alpha written only while translucent) follow
// parse_hex and hex_string in gpui-kit crates/base/src/color_picker.rs. Alpha
// is rounded rather than truncated here. The HSV/HSL model, the conversions
// and the palettes are new UI2 implementations. See third_party/gpui-kit.
module ui2

import math

// The color model behind the color picker: HSV with alpha as the picker's own
// state, and conversions to and from RGB, HSL, hex and CSS notation. Every
// function here is pure. Colors elsewhere in ui2 are 0xRRGGBB u32 values;
// `rgb()` and `color_from_rgb` move between the two.

// ColorHsva is a color as the picker holds it: hue in degrees, saturation,
// value (brightness) and alpha from 0 to 1. Hue 0 and hue 360 are the same
// red; both are kept, so a hue slider dragged to its far end stays there.
//
// Keep a ColorHsva, not an RGB value, as the application's state: a gray has
// no hue and black no saturation, so converting through RGB would forget
// where the hue slider and the area's thumb were.
pub struct ColorHsva {
pub:
	h f64
	s f64
	v f64
	a f64 = 1.0
}

// ColorHsla is the same color as hue, saturation, lightness and alpha, the
// model CSS's hsl() and the picker's HSLA sliders use.
pub struct ColorHsla {
pub:
	h f64
	s f64
	l f64
	a f64 = 1.0
}

// ColorRgba is a color as 8-bit channels plus an alpha from 0 to 1.
pub struct ColorRgba {
pub:
	r u8
	g u8
	b u8
	a f64 = 1.0
}

// color_wrap_hue brings any finite hue into [0, 360]: 360 stays 360, 370
// becomes 10 and -30 becomes 330. A hue that is not finite becomes 0.
pub fn color_wrap_hue(hue f64) f64 {
	if !component_finite(hue) {
		return 0
	}
	if hue >= 0 && hue <= 360 {
		return hue
	}
	mut wrapped := math.fmod(hue, 360)
	if wrapped < 0 {
		wrapped += 360
	}
	return if wrapped == 0 { 0.0 } else { wrapped }
}

// color_alpha clamps an alpha to [0, 1]; NaN means opaque.
fn color_alpha(alpha f64) f64 {
	return if math.is_nan(alpha) { 1.0 } else { unit_clamp(alpha) }
}

// color_hsva builds a normalized color: the hue wrapped into [0, 360],
// saturation and value clamped to [0, 1] (NaN becomes 0) and the alpha
// clamped to [0, 1] (NaN becomes 1).
pub fn color_hsva(h f64, s f64, v f64, a f64) ColorHsva {
	return ColorHsva{
		h: color_wrap_hue(h)
		s: unit_clamp(s)
		v: unit_clamp(v)
		a: color_alpha(a)
	}
}

// normalized returns the color with every component in range.
pub fn (c ColorHsva) normalized() ColorHsva {
	return color_hsva(c.h, c.s, c.v, c.a)
}

// with_alpha returns the color with another alpha, clamped to [0, 1].
pub fn (c ColorHsva) with_alpha(alpha f64) ColorHsva {
	return ColorHsva{
		...c.normalized()
		a: color_alpha(alpha)
	}
}

// color_channel_byte turns a channel from 0 to 1 into 0..255, rounding.
fn color_channel_byte(channel f64) u8 {
	return u8(math.round(unit_clamp(channel) * 255))
}

// color_hsv_channels converts HSV to red, green and blue from 0 to 1. Each
// channel is piecewise linear in the hue, with a corner every 60 degrees,
// and linear in saturation and in value, which is why a few gradient stops
// draw the picker's tracks exactly.
fn color_hsv_channels(h f64, s f64, v f64) (f64, f64, f64) {
	sector := color_wrap_hue(h) / 60.0
	chroma := v * s
	x := chroma * (1 - math.abs(math.fmod(sector, 2) - 1))
	m := v - chroma
	mut r := 0.0
	mut g := 0.0
	mut b := 0.0
	match int(math.floor(sector)) % 6 {
		0 {
			r, g = chroma, x
		}
		1 {
			r, g = x, chroma
		}
		2 {
			g, b = chroma, x
		}
		3 {
			g, b = x, chroma
		}
		4 {
			r, b = x, chroma
		}
		else {
			r, b = chroma, x
		}
	}
	return r + m, g + m, b + m
}

// rgba returns the color as rounded 8-bit channels and its alpha.
pub fn (c ColorHsva) rgba() ColorRgba {
	n := c.normalized()
	r, g, b := color_hsv_channels(n.h, n.s, n.v)
	return ColorRgba{
		r: color_channel_byte(r)
		g: color_channel_byte(g)
		b: color_channel_byte(b)
		a: n.a
	}
}

// rgb returns the color as 0xRRGGBB, without its alpha.
pub fn (c ColorHsva) rgb() u32 {
	return c.rgba().rgb()
}

// rgb returns the channels as 0xRRGGBB.
pub fn (c ColorRgba) rgb() u32 {
	return (u32(c.r) << 16) | (u32(c.g) << 8) | u32(c.b)
}

// color_from_rgb converts an opaque 0xRRGGBB color.
pub fn color_from_rgb(rgb u32) ColorHsva {
	return color_from_rgba(rgb, 1)
}

// color_from_rgba converts 0xRRGGBB with an alpha from 0 to 1. A gray gets
// hue 0 and black saturation 0; use with_rgba to keep a previous hue and
// saturation instead.
pub fn color_from_rgba(rgb u32, alpha f64) ColorHsva {
	r := f64((rgb >> 16) & 0xff) / 255
	g := f64((rgb >> 8) & 0xff) / 255
	b := f64(rgb & 0xff) / 255
	high := math.max(r, math.max(g, b))
	low := math.min(r, math.min(g, b))
	delta := high - low
	mut hue := 0.0
	if delta > 0 {
		hue = if high == r {
			60 * ((g - b) / delta)
		} else if high == g {
			60 * ((b - r) / delta + 2)
		} else {
			60 * ((r - g) / delta + 4)
		}
		if hue < 0 {
			hue += 360
		}
	}
	return color_hsva(hue, if high > 0 { delta / high } else { 0.0 }, high, alpha)
}

// with_rgba is the color the channels name, keeping what they leave open: a
// gray keeps this color's hue, and black keeps its saturation as well. When
// the channels round to this color's own, it is returned unchanged except for
// the alpha, so re-entering the hex a picker shows does not move its thumbs.
pub fn (c ColorHsva) with_rgba(rgba ColorRgba) ColorHsva {
	current := c.normalized()
	alpha := color_alpha(rgba.a)
	if current.rgb() == rgba.rgb() {
		return ColorHsva{
			...current
			a: alpha
		}
	}
	next := color_from_rgba(rgba.rgb(), alpha)
	if next.v == 0 {
		return ColorHsva{
			h: current.h
			s: current.s
			v: 0
			a: alpha
		}
	}
	if next.s == 0 {
		return ColorHsva{
			...next
			h: current.h
		}
	}
	return next
}

// hsla converts to hue, saturation, lightness and alpha. Black and white
// have no HSL saturation; black reports the HSV saturation so a lightness
// slider dragged to zero and back keeps it, and white reports zero.
pub fn (c ColorHsva) hsla() ColorHsla {
	n := c.normalized()
	l := n.v * (1 - n.s / 2)
	s := if l <= 0 {
		n.s
	} else if l >= 1 {
		0.0
	} else {
		(n.v - l) / math.min(l, 1 - l)
	}
	return ColorHsla{
		h: n.h
		s: unit_clamp(s)
		l: unit_clamp(l)
		a: n.a
	}
}

// hsva converts back to the picker's model. Black keeps the HSL saturation
// as its HSV saturation, the inverse of what hsla does.
pub fn (c ColorHsla) hsva() ColorHsva {
	s := unit_clamp(c.s)
	l := unit_clamp(c.l)
	v := l + s * math.min(l, 1 - l)
	return color_hsva(c.h, if v <= 0 { s } else { 2 * (1 - l / v) }, v, c.a)
}

// color_from_hsla converts hue (degrees), saturation, lightness and alpha.
pub fn color_from_hsla(h f64, s f64, l f64, a f64) ColorHsva {
	return ColorHsla{
		h: h
		s: s
		l: l
		a: a
	}.hsva()
}

// color_alpha_byte is an alpha as 0..255, rounded.
fn color_alpha_byte(alpha f64) u8 {
	return color_channel_byte(color_alpha(alpha))
}

// color_hex formats 0xRRGGBB as `#RRGGBB`, or `#RRGGBBAA` when the alpha
// rounds below 255. Alpha is rounded, not truncated, so 0.5 is `80` and the
// text parses back to the same byte.
pub fn color_hex(rgb u32, alpha f64) string {
	r := (rgb >> 16) & 0xff
	g := (rgb >> 8) & 0xff
	b := rgb & 0xff
	base := '#${r:02X}${g:02X}${b:02X}'
	a := color_alpha_byte(alpha)
	return if a < 255 { base + '${a:02X}' } else { base }
}

// hex formats the color as color_hex does.
pub fn (c ColorHsva) hex() string {
	n := c.normalized()
	return color_hex(n.rgb(), n.a)
}

fn color_hex_digit(ch u8) int {
	return match ch {
		`0`...`9` { int(ch - `0`) }
		`a`...`f` { int(ch - `a`) + 10 }
		`A`...`F` { int(ch - `A`) + 10 }
		else { -1 }
	}
}

// color_parse_hex reads `#rgb`, `#rgba`, `#rrggbb` and `#rrggbbaa`, with or
// without the `#` and with surrounding spaces. A single digit repeats, so
// `#fff` is white. Anything else, including a sign, gives none.
pub fn color_parse_hex(source string) ?ColorRgba {
	mut digits := source.trim_space()
	if digits.starts_with('#') {
		digits = digits[1..]
	}
	if digits.len !in [3, 4, 6, 8] {
		return none
	}
	width := if digits.len <= 4 { 1 } else { 2 }
	mut channels := []int{cap: 4}
	for start := 0; start < digits.len; start += width {
		mut channel := 0
		for ch in digits[start..start + width].bytes() {
			digit := color_hex_digit(ch)
			if digit < 0 {
				return none
			}
			channel = channel * 16 + digit
		}
		channels << if width == 1 { channel * 17 } else { channel }
	}
	return ColorRgba{
		r: u8(channels[0])
		g: u8(channels[1])
		b: u8(channels[2])
		a: if channels.len == 4 { f64(channels[3]) / 255 } else { 1.0 }
	}
}

// color_from_hex parses a hex color into the picker's model.
pub fn color_from_hex(source string) ?ColorHsva {
	rgba := color_parse_hex(source)?
	return color_from_rgba(rgba.rgb(), rgba.a)
}

// color_alpha_text writes an alpha for CSS: up to three decimals, without
// trailing zeros.
fn color_alpha_text(alpha f64) string {
	scaled := int(math.round(color_alpha(alpha) * 1000))
	if scaled % 1000 == 0 {
		return (scaled / 1000).str()
	}
	remainder := scaled % 1000
	mut fraction := '${remainder:03d}'
	for fraction.ends_with('0') {
		fraction = fraction[..fraction.len - 1]
	}
	return '${scaled / 1000}.${fraction}'
}

// css_rgb writes the color as CSS `rgb(51, 102, 255)`, or
// `rgba(51, 102, 255, 0.5)` when it is translucent.
pub fn (c ColorHsva) css_rgb() string {
	rgba := c.rgba()
	if color_alpha_byte(rgba.a) < 255 {
		return 'rgba(${rgba.r}, ${rgba.g}, ${rgba.b}, ${color_alpha_text(rgba.a)})'
	}
	return 'rgb(${rgba.r}, ${rgba.g}, ${rgba.b})'
}

// css_hsl writes the color as CSS `hsl(225, 100%, 60%)`, or `hsla(...)` with
// the alpha when it is translucent. Components are rounded to whole degrees
// and percent, and hue 360 is written as 0.
pub fn (c ColorHsva) css_hsl() string {
	hsl := c.hsla()
	hue := int(math.round(hsl.h)) % 360
	body := '${hue}, ${int(math.round(hsl.s * 100))}%, ${int(math.round(hsl.l * 100))}%'
	if color_alpha_byte(hsl.a) < 255 {
		return 'hsla(${body}, ${color_alpha_text(hsl.a)})'
	}
	return 'hsl(${body})'
}

// same_rgb reports whether two colors draw the same 0xRRGGBB, whatever
// their alpha or the hue a gray remembers.
pub fn (c ColorHsva) same_rgb(other ColorHsva) bool {
	return c.rgb() == other.rgb()
}

// color_contrast_foreground is black or white, whichever reads better on rgb:
// the color of a check mark drawn on a swatch.
pub fn color_contrast_foreground(rgb u32) u32 {
	return if choice_contrast(rgb, 0x000000) >= choice_contrast(rgb, 0xffffff) {
		0x000000
	} else {
		0xffffff
	}
}

// color_over composites rgb at alpha over an opaque background, as a
// renderer blends a translucent fill.
fn color_over(rgb u32, alpha f64, background u32) u32 {
	return choice_mix(background, rgb, color_alpha(alpha))
}

// ── Palettes ────────────────────────────────────────────────────────

// ColorPalette is one family of swatches, shown as a row.
pub struct ColorPalette {
pub:
	name   string
	colors []u32
}

// color_palette_lightness holds the eleven shades of a family, light to dark,
// as HSL lightness.
const color_palette_lightness = [0.97, 0.93, 0.86, 0.77, 0.66, 0.55, 0.46, 0.38, 0.30, 0.23, 0.15]

struct ColorPaletteFamily {
	name       string
	hue        f64
	saturation f64
}

const color_palette_families = [
	ColorPaletteFamily{'Stone', 30, 0.08},
	ColorPaletteFamily{'Red', 0, 0.80},
	ColorPaletteFamily{'Orange', 25, 0.92},
	ColorPaletteFamily{'Yellow', 45, 0.95},
	ColorPaletteFamily{'Green', 142, 0.62},
	ColorPaletteFamily{'Cyan', 188, 0.80},
	ColorPaletteFamily{'Blue', 217, 0.88},
	ColorPaletteFamily{'Purple', 270, 0.72},
	ColorPaletteFamily{'Pink', 330, 0.78},
]

// color_default_palettes is the picker's built-in palette: nine families
// (stone, red, orange, yellow, green, cyan, blue, purple and pink) of eleven
// shades each, from light to dark, the layout of GPUI Kit's palette.
pub fn color_default_palettes() []ColorPalette {
	mut palettes := []ColorPalette{cap: color_palette_families.len}
	for family in color_palette_families {
		palettes << ColorPalette{
			name:   family.name
			colors: color_palette_lightness.map(color_from_hsla(family.hue, family.saturation,
				it, 1).rgb())
		}
	}
	return palettes
}

// color_default_featured is the row of featured colors shown when the
// application supplies none: the middle shade of each palette family from
// red to pink, then gray, black and white.
pub fn color_default_featured() []u32 {
	palettes := color_default_palettes()
	mut colors := []u32{cap: 11}
	for palette in palettes[1..] {
		colors << palette.colors[5]
	}
	colors << palettes[0].colors[5]
	colors << 0x000000
	colors << 0xffffff
	return colors
}
