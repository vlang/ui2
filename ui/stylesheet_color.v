module ui2

import math

// Modern CSS color functions: lab(), lch(), oklab(), oklch(), hwb(),
// gray(), color() and relative colors (`rgb(from ...)`) plus the
// `color-contrast()`/`palette-mix()` notes below.
//
// Conversions run through linear sRGB and XYZ-D65 hubs. Out-of-gamut
// results clamp to sRGB on output, the CSS-compliant fallback for a
// renderer without wide-gamut surfaces.
//
// NOT implemented (documented): color-contrast() and contrast-color()
// (spec still churning), palette-mix() (needs palette infra), image and
// filter functions (no image pipeline in stylesheets), anchor/position
// functions (no positioning in stylesheets), nesting-unrelated `if()`
// (use @media), container units inside conditions (px only, by design).

pub struct StyleSrgb {
pub:
	r f64 // 0..1 gamma-encoded
	g f64
	b f64
	a f64 = 1.0
}

fn style_split_slash(parts []string) ([]string, string) {
	for index, part in parts {
		if part.trim_space() == '/' {
			return parts[..index].map(it.trim_space()), parts[index + 1..].join(' ').trim_space()
		}
		if part.contains('/') && !part.contains('(') {
			halves := part.split('/')
			if halves.len == 2 {
				mut rest := parts[..index].map(it.trim_space())
				rest << halves[0].trim_space()
				return rest, halves[1].trim_space()
			}
		}
	}
	return parts.map(it.trim_space()), ''
}

// style_color_args splits a color function's inside into channel strings
// plus an optional alpha string, accepting comma form (`a, b, c`) and space
// form (`a b c / alpha`), but not a mixture.
fn style_color_args(inner string) !([]string, string) {
	top := theme_split_commas(inner)
	if top.len > 1 {
		mut channels := []string{cap: top.len}
		mut alpha := ''
		for index, part in top {
			trimmed := part.trim_space()
			if trimmed == '' {
				return error('empty color channel')
			}
			if index == top.len - 1 && trimmed.contains('/') && !trimmed.contains('(') {
				halves := trimmed.split('/')
				if halves.len != 2 || halves[0].trim_space() == '' {
					return error('"${trimmed}" is not a channel with alpha')
				}
				channels << halves[0].trim_space()
				alpha = halves[1].trim_space()
				continue
			}
			if trimmed.contains(' ') || trimmed.contains('\t') {
				return error('comma and space forms do not mix in one color')
			}
			channels << trimmed
		}
		return channels, alpha
	}
	fields := inner.replace(',', ' ').fields()
	channels, alpha := style_split_slash(fields)
	return channels, alpha
}

fn style_srgb_token(rgb StyleSrgb) ComponentThemeToken {
	clamped := StyleSrgb{
		r: unit_clamp(rgb.r)
		g: unit_clamp(rgb.g)
		b: unit_clamp(rgb.b)
		a: unit_clamp(rgb.a)
	}
	color := (u32(color_channel_byte(clamped.r)) << 16) | (u32(color_channel_byte(clamped.g)) << 8) |
		u32(color_channel_byte(clamped.b))
	return ComponentThemeToken{
		color:   color
		opacity: clamped.a
	}
}

// ── Transfer functions and matrices ─────────────────────────────

fn style_linear_channel(c f64) f64 {
	if c <= 0.04045 {
		return c / 12.92
	}
	return math.pow((c + 0.055) / 1.055, 2.4)
}

fn style_gamma_channel(c f64) f64 {
	if c <= 0.0031308 {
		return c * 12.92
	}
	return 1.055 * math.pow(c, 1.0 / 2.4) - 0.055
}

fn style_mat3(m [9]f64, x f64, y f64, z f64) (f64, f64, f64) {
	return m[0] * x + m[1] * y + m[2] * z, m[3] * x + m[4] * y + m[5] * z, m[6] * x + m[7] * y + m[8] * z
}

const style_xyz_d65_from_srgb = [0.4124564, 0.3575761, 0.1804375, 0.2126729, 0.7151522, 0.0721750,
	0.0193339, 0.1191920, 0.9503041]!

const style_srgb_from_xyz_d65 = [3.2404542, -1.5371385, -0.4985314, -0.9692660, 1.8760108, 0.0415560,
	0.0556434, -0.2040259, 1.0572252]!

const style_xyz_d65_from_p3 = [0.4865709, 0.2656677, 0.1982173, 0.2289746, 0.6917385, 0.0792869,
	0.0, 0.0451134, 1.0439444]!

const style_p3_from_xyz_d65 = [2.4934969, -0.9313833, -0.4027108, -0.8294890, 1.7626641, 0.0236247,
	0.0358458, -0.0761724, 0.9568845]!

const style_xyz_d65_from_a98 = [0.5766690, 0.1855587, 0.1882282, 0.2973450, 0.6273636, 0.0752913,
	0.0270314, 0.0706889, 0.9913375]!

const style_a98_from_xyz_d65 = [2.0415879, -0.5650069, -0.3447313, -0.9692436, 1.8759675, 0.0415559,
	0.0134474, -0.1183626, 1.0151746]!

const style_xyz_d65_from_prophoto = [0.7976749, 0.1351917, 0.0313534, 0.2880402, 0.7118741, 0.0000857,
	0.0, 0.0, 0.8252100]!

const style_prophoto_from_xyz_d65 = [1.3459433, -0.2556075, -0.0511118, -0.5445989, 1.5081673,
	0.0205351, 0.0, 0.0, 1.2118128]!

const style_xyz_d65_from_rec2020 = [0.6369580, 0.1446169, 0.1688810, 0.2627002, 0.6779981, 0.0593017,
	0.0, 0.0280727, 1.0609851]!

const style_rec2020_from_xyz_d65 = [1.7166512, -0.3556708, -0.2533663, -0.6666844, 1.6164812,
	0.0157686, 0.0176399, -0.0427706, 0.9421031]!

// Full Bradford chromatic adaptation between D65 and D50 (Lindbloom).
// These include the white-point scaling, unlike the raw cone-response
// matrices, so D65 white maps to D50 white and back.
const style_xyz_d50_from_d65 = [1.0478112, 0.0228866, -0.0501270, 0.0295424, 0.9904844, -0.0170491,
	-0.0092345, 0.0150436, 0.7521316]!

const style_xyz_d65_from_d50 = [0.9555766, -0.0230393, 0.0631636, -0.0282895, 1.0099416, 0.0210077,
	0.0122982, -0.0204830, 1.3299098]!

fn style_signed_cbrt(value f64) f64 {
	if value < 0 {
		return -math.pow(-value, 1.0 / 3.0)
	}
	return math.pow(value, 1.0 / 3.0)
}

// ── Hub conversions ─────────────────────────────────────────────

fn style_linear_from_srgb(rgb StyleSrgb) (f64, f64, f64) {
	return style_linear_channel(rgb.r), style_linear_channel(rgb.g), style_linear_channel(rgb.b)
}

fn style_srgb_from_linear(r f64, g f64, b f64, a f64) StyleSrgb {
	return StyleSrgb{
		r: style_gamma_channel(r)
		g: style_gamma_channel(g)
		b: style_gamma_channel(b)
		a: a
	}
}

fn style_xyz_d65_from_linear(r f64, g f64, b f64) (f64, f64, f64) {
	return style_mat3(style_xyz_d65_from_srgb, r, g, b)
}

fn style_linear_from_xyz_d65(x f64, y f64, z f64) (f64, f64, f64) {
	return style_mat3(style_srgb_from_xyz_d65, x, y, z)
}

fn style_xyz_d50_from_d65(x f64, y f64, z f64) (f64, f64, f64) {
	return style_mat3(style_xyz_d50_from_d65, x, y, z)
}

fn style_xyz_d65_from_d50(x f64, y f64, z f64) (f64, f64, f64) {
	return style_mat3(style_xyz_d65_from_d50, x, y, z)
}

const style_lab_epsilon = 216.0 / 24389.0
const style_lab_kappa = 24389.0 / 27.0

fn style_lab_f(value f64) f64 {
	if value > style_lab_epsilon {
		return style_signed_cbrt(value)
	}
	return (style_lab_kappa * value + 16) / 116
}

fn style_lab_f_inv(value f64) f64 {
	cubed := value * value * value
	if cubed > style_lab_epsilon {
		return cubed
	}
	return (116 * value - 16) / style_lab_kappa
}

fn style_lab_from_xyz(x f64, y f64, z f64) (f64, f64, f64) {
	fx := style_lab_f(x / 0.96422)
	fy := style_lab_f(y)
	fz := style_lab_f(z / 0.82521)
	return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)
}

fn style_xyz_from_lab(l f64, a f64, b f64) (f64, f64, f64) {
	fy := (l + 16) / 116
	fx := fy + a / 500
	fz := fy - b / 200
	return 0.96422 * style_lab_f_inv(fx), style_lab_f_inv(fy), 0.82521 * style_lab_f_inv(fz)
}

fn style_oklab_from_linear(r f64, g f64, b f64) (f64, f64, f64) {
	l, m, s := style_mat3([0.4122214708, 0.5363325363, 0.0514459929, 0.2119034982, 0.6806995451,
		0.1073969566, 0.0883024619, 0.2817188376, 0.6299787005]!, r, g, b)
	ll := style_signed_cbrt(l)
	mm := style_signed_cbrt(m)
	ss := style_signed_cbrt(s)
	return style_mat3([0.2104542553, 0.7936177850, -0.0040720468, 1.9779984951, -2.4285922050,
		0.4505937099, 0.0259040371, 0.7827717662, -0.8086757660]!, ll,
		mm, ss)
}

fn style_linear_from_oklab(l f64, a f64, b f64) (f64, f64, f64) {
	ll, mm, ss := style_mat3([1.0, 0.3963377774, 0.2158037573, 1.0, -0.1055613458, -0.0638541728,
		1.0, -0.0894841775, -1.2914855480]!, l, a, b)
	l3 := ll * ll * ll
	m3 := mm * mm * mm
	s3 := ss * ss * ss
	return style_mat3([4.0767416621, -3.3077115913, 0.2309699292, -1.2684380046, 2.6097574011,
		-0.3413193965, -0.0041960863, -0.7034186147, 1.7076147010]!, l3,
		m3, s3)
}

// ── Space plumbing ──────────────────────────────────────────────

// StyleChannels carries three decomposed color channels plus their space.
struct StyleChannels {
pub:
	x f64
	y f64
	z f64
}

// style_space_channels decomposes an sRGB color into a named space. Channels
// follow CSS ranges: lab L/a/b, lch L/C/hue-degrees, oklab/oklch ditto,
// hwb h-degrees/w/b fractions, xyz triples, rgb 0..1.
fn style_space_channels(space string, rgb StyleSrgb) !StyleChannels {
	lr, lg, lb := style_linear_from_srgb(rgb)
	channels := match space {
		'srgb', 'srgb-linear' {
			if space == 'srgb' {
				StyleChannels{ x: rgb.r, y: rgb.g, z: rgb.b }
			} else {
				StyleChannels{ x: lr, y: lg, z: lb }
			}
		}
		'hsl' {
			h, s, l := style_hsl_from_srgb(rgb)
			StyleChannels{ x: h, y: s, z: l }
		}
		'hwb' {
			h, w, b := style_hwb_from_srgb(rgb)
			StyleChannels{ x: h, y: w, z: b }
		}
		'lab' {
			x, y, z := style_xyz_d65_from_linear(lr, lg, lb)
			x50, y50, z50 := style_xyz_d50_from_d65(x, y, z)
			l, a, b := style_lab_from_xyz(x50, y50, z50)
			StyleChannels{ x: l, y: a, z: b }
		}
		'lch' {
			x, y, z := style_xyz_d65_from_linear(lr, lg, lb)
			x50, y50, z50 := style_xyz_d50_from_d65(x, y, z)
			l, a, bb := style_lab_from_xyz(x50, y50, z50)
			StyleChannels{
				x: l
				y: math.sqrt(a * a + bb * bb)
				z: math.atan2(bb, a) * 180 / math.pi
			}
		}
		'oklab' {
			l, a, b := style_oklab_from_linear(lr, lg, lb)
			StyleChannels{ x: l, y: a, z: b }
		}
		'oklch' {
			l, a, b := style_oklab_from_linear(lr, lg, lb)
			StyleChannels{
				x: l
				y: math.sqrt(a * a + b * b)
				z: math.atan2(b, a) * 180 / math.pi
			}
		}
		'display-p3' {
			x, y, z := style_xyz_d65_from_linear(lr, lg, lb)
			r, g, b := style_mat3(style_p3_from_xyz_d65, x, y, z)
			StyleChannels{ x: r, y: g, z: b }
		}
		'a98-rgb' {
			x, y, z := style_xyz_d65_from_linear(lr, lg, lb)
			r, g, b := style_mat3(style_a98_from_xyz_d65, x, y, z)
			StyleChannels{
				x: math.pow(r, 1.0 / 2.2)
				y: math.pow(g, 1.0 / 2.2)
				z: math.pow(b, 1.0 / 2.2)
			}
		}
		'prophoto-rgb' {
			x, y, z := style_xyz_d65_from_linear(lr, lg, lb)
			r, g, b := style_mat3(style_prophoto_from_xyz_d65, x, y, z)
			StyleChannels{
				x: math.pow(r, 1.0 / 1.8)
				y: math.pow(g, 1.0 / 1.8)
				z: math.pow(b, 1.0 / 1.8)
			}
		}
		'rec2020' {
			x, y, z := style_xyz_d65_from_linear(lr, lg, lb)
			r, g, b := style_mat3(style_rec2020_from_xyz_d65, x, y, z)
			StyleChannels{
				x: style_gamma_channel(r)
				y: style_gamma_channel(g)
				z: style_gamma_channel(b)
			}
		}
		'xyz', 'xyz-d65' {
			x, y, z := style_xyz_d65_from_linear(lr, lg, lb)
			StyleChannels{ x: x, y: y, z: z }
		}
		'xyz-d50' {
			x, y, z := style_xyz_d65_from_linear(lr, lg, lb)
			a, b, c := style_xyz_d50_from_d65(x, y, z)
			StyleChannels{ x: a, y: b, z: c }
		}
		'gray' {
			luminance := 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
			StyleChannels{ x: luminance, y: luminance, z: luminance }
		}
		else {
			return error('unknown color space "${space}"')
		}
	}
	return channels
}

// style_srgb_from_space composes an sRGB color from a named space.
fn style_srgb_from_space(space string, c1 f64, c2 f64, c3 f64, alpha f64) !StyleSrgb {
	match space {
		'srgb' {
			return StyleSrgb{ r: c1, g: c2, b: c3, a: alpha }
		}
		'srgb-linear' {
			r, g, b := style_gamma_channel(c1), style_gamma_channel(c2), style_gamma_channel(c3)
			return StyleSrgb{ r: r, g: g, b: b, a: alpha }
		}
		'hsl' {
			return style_srgb_from_hsl(c1, c2, c3, alpha)
		}
		'hwb' {
			return style_srgb_from_hwb(c1, c2, c3, alpha)
		}
		'lab' {
			x, y, z := style_xyz_from_lab(c1, c2, c3)
			x65, y65, z65 := style_xyz_d65_from_d50(x, y, z)
			r, g, b := style_linear_from_xyz_d65(x65, y65, z65)
			return style_srgb_from_linear(r, g, b, alpha)
		}
		'lch' {
			angle := c3 * math.pi / 180
			a := c2 * math.cos(angle)
			b := c2 * math.sin(angle)
			x, y, z := style_xyz_from_lab(c1, a, b)
			x65, y65, z65 := style_xyz_d65_from_d50(x, y, z)
			r, g, bl := style_linear_from_xyz_d65(x65, y65, z65)
			return style_srgb_from_linear(r, g, bl, alpha)
		}
		'oklab' {
			r, g, b := style_linear_from_oklab(c1, c2, c3)
			return style_srgb_from_linear(r, g, b, alpha)
		}
		'oklch' {
			angle := c3 * math.pi / 180
			a := c2 * math.cos(angle)
			b := c2 * math.sin(angle)
			r, g, bl := style_linear_from_oklab(c1, a, b)
			return style_srgb_from_linear(r, g, bl, alpha)
		}
		'display-p3' {
			lr, lg, lb := style_mat3(style_xyz_d65_from_p3, c1, c2, c3)
			r, g, b := style_linear_from_xyz_d65(lr, lg, lb)
			return style_srgb_from_linear(r, g, b, alpha)
		}
		'a98-rgb' {
			lr := math.pow(c1, 2.2)
			lg := math.pow(c2, 2.2)
			lb := math.pow(c3, 2.2)
			x, y, z := style_mat3(style_xyz_d65_from_a98, lr, lg, lb)
			r, g, b := style_linear_from_xyz_d65(x, y, z)
			return style_srgb_from_linear(r, g, b, alpha)
		}
		'prophoto-rgb' {
			lr := math.pow(c1, 1.8)
			lg := math.pow(c2, 1.8)
			lb := math.pow(c3, 1.8)
			x, y, z := style_mat3(style_xyz_d65_from_prophoto, lr, lg, lb)
			r, g, b := style_linear_from_xyz_d65(x, y, z)
			return style_srgb_from_linear(r, g, b, alpha)
		}
		'rec2020' {
			lr := style_linear_channel(c1)
			lg := style_linear_channel(c2)
			lb := style_linear_channel(c3)
			x, y, z := style_mat3(style_xyz_d65_from_rec2020, lr, lg, lb)
			r, g, b := style_linear_from_xyz_d65(x, y, z)
			return style_srgb_from_linear(r, g, b, alpha)
		}
		'xyz', 'xyz-d65' {
			r, g, b := style_linear_from_xyz_d65(c1, c2, c3)
			return style_srgb_from_linear(r, g, b, alpha)
		}
		'xyz-d50' {
			x65, y65, z65 := style_xyz_d65_from_d50(c1, c2, c3)
			r, g, b := style_linear_from_xyz_d65(x65, y65, z65)
			return style_srgb_from_linear(r, g, b, alpha)
		}
		else {
			return error('unknown color space "${space}"')
		}
	}
}

fn style_hsl_from_srgb(rgb StyleSrgb) (f64, f64, f64) {
	maximum := math.max(math.max(rgb.r, rgb.g), rgb.b)
	minimum := math.min(math.min(rgb.r, rgb.g), rgb.b)
	lightness := (maximum + minimum) / 2
	if maximum == minimum {
		return 0, 0, lightness
	}
	delta := maximum - minimum
	saturation := if lightness > 0.5 {
		delta / (2 - maximum - minimum)
	} else {
		delta / (maximum + minimum)
	}
	mut hue := 0.0
	if maximum == rgb.r {
		hue = (rgb.g - rgb.b) / delta + if rgb.g < rgb.b { 6.0 } else { 0.0 }
	} else if maximum == rgb.g {
		hue = (rgb.b - rgb.r) / delta + 2.0
	} else {
		hue = (rgb.r - rgb.g) / delta + 4.0
	}
	return hue * 60, saturation, lightness
}

fn style_srgb_from_hsl(hue_deg f64, saturation f64, lightness f64, alpha f64) StyleSrgb {
	hue := math.fmod(math.fmod(hue_deg, 360) + 360, 360) / 360
	saturation_clamped := unit_clamp(saturation)
	lightness_clamped := unit_clamp(lightness)
	if saturation_clamped == 0 {
		return StyleSrgb{
			r: lightness_clamped
			g: lightness_clamped
			b: lightness_clamped
			a: alpha
		}
	}
	second := if lightness_clamped < 0.5 {
		lightness_clamped * (1 + saturation_clamped)
	} else {
		lightness_clamped + saturation_clamped - lightness_clamped * saturation_clamped
	}
	first := 2 * lightness_clamped - second
	return StyleSrgb{
		r: style_hue_channel(first, second, hue + 1.0 / 3.0)
		g: style_hue_channel(first, second, hue)
		b: style_hue_channel(first, second, hue - 1.0 / 3.0)
		a: alpha
	}
}

fn style_hue_channel(first f64, second f64, hue f64) f64 {
	mut wrapped := hue
	if wrapped < 0 {
		wrapped += 1
	}
	if wrapped > 1 {
		wrapped -= 1
	}
	if wrapped * 6 < 1 {
		return first + (second - first) * 6 * wrapped
	}
	if wrapped * 2 < 1 {
		return second
	}
	if wrapped * 3 < 2 {
		return first + (second - first) * (2.0 / 3.0 - wrapped) * 6
	}
	return first
}

fn style_hwb_from_srgb(rgb StyleSrgb) (f64, f64, f64) {
	hue, _, _ := style_hsl_from_srgb(rgb)
	maximum := math.max(math.max(rgb.r, rgb.g), rgb.b)
	minimum := math.min(math.min(rgb.r, rgb.g), rgb.b)
	return hue, minimum, 1 - maximum
}

fn style_srgb_from_hwb(hue_deg f64, white f64, black f64, alpha f64) StyleSrgb {
	w := unit_clamp(white)
	b := unit_clamp(black)
	if w + b >= 1 {
		gray := w / (w + b)
		return StyleSrgb{ r: gray, g: gray, b: gray, a: alpha }
	}
	pure := style_srgb_from_hsl(hue_deg, 1, 0.5, alpha)
	return StyleSrgb{
		r: pure.r * (1 - w - b) + w
		g: pure.g * (1 - w - b) + w
		b: pure.b * (1 - w - b) + w
		a: alpha
	}
}

// ── Entry points ────────────────────────────────────────────────

// style_parse_function_color parses lab(), lch(), oklab(), oklch(), hwb(),
// gray() and color().
pub fn style_parse_function_color(name string, inner string) !ComponentThemeToken {
	channels, alpha_raw := style_color_args(inner)!
	alpha := if alpha_raw == '' { 1.0 } else { style_alpha_value(alpha_raw)! }
	match name {
		'lab', 'oklch', 'lch', 'oklab', 'hwb', 'gray' {
			if channels.len != 3 && name != 'gray' {
				return error('"${name}()" needs three channels')
			}
		}
		else {}
	}
	rgb := match name {
		'lab' {
			l := style_lab_lightness(channels[0])!
			a := style_lab_axis(channels[1])!
			b := style_lab_axis(channels[2])!
			style_srgb_from_space('lab', l, a, b, alpha)!
		}
		'lch' {
			l := style_lab_lightness(channels[0])!
			c := style_lab_chroma(channels[1])!
			h := style_channel_angle(channels[2])!
			style_srgb_from_space('lch', l, c, h, alpha)!
		}
		'oklab' {
			l := style_oklab_lightness(channels[0])!
			a := style_lab_axis(channels[1])!
			b := style_lab_axis(channels[2])!
			style_srgb_from_space('oklab', l, a, b, alpha)!
		}
		'oklch' {
			l := style_oklab_lightness(channels[0])!
			c := style_lab_chroma(channels[1])!
			h := style_channel_angle(channels[2])!
			style_srgb_from_space('oklch', l, c, h, alpha)!
		}
		'hwb' {
			h := style_channel_angle(channels[0])!
			w := style_unit_fraction(channels[1])!
			b := style_unit_fraction(channels[2])!
			style_srgb_from_hwb(h, w, b, alpha)
		}
		'gray' {
			if channels.len != 1 {
				return error('"gray()" needs exactly one channel')
			}
			light := style_gray_value(channels[0])!
			StyleSrgb{ r: light, g: light, b: light, a: alpha }
		}
		'color' {
			if channels.len < 4 {
				return error('"color()" needs a space and three channels')
			}
			space := channels[0].to_lower()
			if space !in ['srgb', 'srgb-linear', 'display-p3', 'a98-rgb', 'prophoto-rgb', 'rec2020',
				'xyz', 'xyz-d50', 'xyz-d65'] {
				return error('"${space}" is not a supported color space')
			}
			c := [style_unit_fraction(channels[1])!, style_unit_fraction(channels[2])!,
				style_unit_fraction(channels[3])!]
			style_srgb_from_space(space, c[0], c[1], c[2], alpha)!
		}
		else {
			return error('"${name}()" is not a color function')
		}
	}
	return style_srgb_token(rgb)
}

fn style_lab_lightness(raw string) !f64 {
	lowered := raw.trim_space().to_lower()
	if lowered.ends_with('%') {
		number := query_plain_number(lowered[..lowered.len - 1]) or {
			return error('"${raw}" is not a lightness')
		}
		return number
	}
	number := query_plain_number(lowered) or { return error('"${raw}" is not a lightness') }
	return number
}

fn style_lab_axis(raw string) !f64 {
	trimmed := raw.trim_space()
	plain := if trimmed.to_lower().ends_with('%') { trimmed[..trimmed.len - 1] } else { trimmed }
	return query_plain_number(plain) or { error('"${raw}" is not a color axis') }
}

// style_lab_chroma parses a chroma channel: a bare number, or a percentage
// used as one (percentages carry no extra scaling here).
fn style_lab_chroma(raw string) !f64 {
	text := raw.trim_space()
	plain := if text.to_lower().ends_with('%') { text[..text.len - 1] } else { text }
	return query_plain_number(plain) or { error('"${raw}" is not a chroma') }
}

fn style_oklab_lightness(raw string) !f64 {
	text := raw.trim_space().to_lower()
	if text.ends_with('%') {
		number := query_plain_number(text[..text.len - 1]) or {
			return error('"${raw}" is not a lightness')
		}
		return number / 100
	}
	return query_plain_number(text) or { error('"${raw}" is not a lightness') }
}

fn style_unit_fraction(raw string) !f64 {
	text := raw.trim_space().to_lower()
	if text.ends_with('%') {
		number := query_plain_number(text[..text.len - 1]) or {
			return error('"${raw}" is not a fraction')
		}
		return number / 100
	}
	return query_plain_number(text) or { error('"${raw}" is not a fraction') }
}

// style_gray_value parses gray()'s 0..100 lightness, with or without `%`.
fn style_gray_value(raw string) !f64 {
	text := raw.trim_space().to_lower()
	plain := if text.ends_with('%') { text[..text.len - 1] } else { text }
	number := query_plain_number(plain) or { error('"${raw}" is not a gray lightness') }
	return unit_clamp(number / 100)
}

fn style_alpha_value(raw string) !f64 {
	text := raw.trim_space().to_lower()
	if text.ends_with('%') {
		number := query_plain_number(text[..text.len - 1]) or {
			return error('"${raw}" is not an alpha')
		}
		return unit_clamp(number / 100)
	}
	number := query_plain_number(text) or { error('"${raw}" is not an alpha') }
	return unit_clamp(number)
}

fn style_channel_angle(raw string) !f64 {
	trimmed := raw.trim_space()
	lower := trimmed.to_lower()
	if lower.ends_with('deg') || lower.ends_with('rad') || lower.ends_with('grad')
		|| lower.ends_with('turn') || (!lower.ends_with('%') && lower.contains('(')) {
		parsed := style_math_channel(trimmed, StyleLengthCtx{}) or {
			return error('"${raw}" is not an angle')
		}
		if parsed.dim == .angle {
			return parsed.value * 180 / math.pi
		}
		if parsed.dim == .scalar {
			return parsed.value
		}
		return error('"${raw}" is not an angle')
	}
	if lower.ends_with('%') {
		number := query_plain_number(lower[..lower.len - 1]) or {
			return error('"${raw}" is not an angle')
		}
		return number * 3.6
	}
	number := query_plain_number(lower) or { error('"${raw}" is not an angle') }
	return number
}

// ── Relative colors ─────────────────────────────────────────────
// `rgb(from red r g b)`, `hsl(from blue h s l / 50%)`, ...

fn style_is_relative(inner string) bool {
	trimmed := inner.trim_space()
	if trimmed.len <= 5 || trimmed[..4].to_lower() != 'from' {
		return false
	}
	sep := trimmed[4]
	return sep == ` ` || sep == `\t`
}

// style_parse_relative_color resolves `name(from origin channels...)`.
pub fn style_parse_relative_color(name string, inner string) !ComponentThemeToken {
	trimmed := inner.trim_space()[5..].trim_space()
	parts := style_split_top_level(trimmed)
	if parts.len < 2 {
		return error('relative "${name}()" needs an origin color and channels')
	}
	// The origin is the longest leading run that parses as a color; channel
	// idents (`r`, `hue`) would otherwise swallow it.
	mut origin := StyleSrgb{}
	mut rest := []string{}
	mut found := false
	for end := parts.len - 1; end >= 1; end-- {
		candidate := parts[..end].join(' ')
		token := component_theme_token(candidate) or { continue }
		if token.has_gradient() {
			continue
		}
		origin = StyleSrgb{
			r: f64((token.color >> 16) & 0xff) / 255
			g: f64((token.color >> 8) & 0xff) / 255
			b: f64(token.color & 0xff) / 255
			a: token.opacity
		}
		rest = parts[end..].clone()
		found = true
		break
	}
	if !found {
		return error('relative "${name}()" needs a color to start from')
	}
	mut channels, alpha := style_relative_channels(rest)!
	name_lower := name.to_lower()
	if name_lower == 'color' {
		// Relative color(): the space follows the origin explicitly.
		if channels.len < 1 {
			return error('relative "color()" needs a space after the origin color')
		}
		space := channels[0].to_lower()
		if space !in ['srgb', 'srgb-linear', 'display-p3', 'a98-rgb', 'prophoto-rgb', 'rec2020',
			'xyz', 'xyz-d50', 'xyz-d65'] {
			return error('"${channels[0]}" is not a supported color space')
		}
		mut rest_channels := channels[1..].clone()
		names := style_relative_names(space)
		for rest_channels.len < 3 {
			rest_channels << names[rest_channels.len]
		}
		if rest_channels.len != 3 {
			return error('relative "color()" needs three channels')
		}
		rgb := style_apply_relative(space, origin, rest_channels, alpha)!
		return style_srgb_token(rgb)
	}
	space := style_relative_named_space_unchecked(name_lower)!
	names := style_relative_names(space)
	channel_count := if space == 'gray' { 1 } else { 3 }
	if channels.len > channel_count {
		return error('relative "${name}" has too many channels')
	}
	for channels.len < channel_count {
		channels << names[channels.len]
	}
	rgb := style_apply_relative(space, origin, channels, alpha)!
	return style_srgb_token(rgb)
}

fn style_split_top_level(source string) []string {
	mut parts := []string{}
	mut depth := 0
	mut start := -1
	for index, ch in source.bytes() {
		if ch == `(` {
			depth++
		} else if ch == `)` {
			if depth > 0 {
				depth--
			}
		}
		is_space := ch == ` ` || ch == `\t` || ch == `\n` || ch == `\r`
		if depth == 0 && is_space {
			if start >= 0 {
				parts << source[start..index]
				start = -1
			}
			continue
		}
		if start < 0 && !(depth == 0 && is_space) {
			start = index
		}
	}
	if start >= 0 {
		parts << source[start..]
	}
	return parts
}

fn style_relative_channels(parts []string) !([]string, string) {
	mut channels := []string{}
	mut alpha := ''
	mut index := 0
	for index < parts.len {
		if parts[index] == '/' {
			if index + 1 >= parts.len || alpha != '' {
				return error('misplaced "/" in relative color')
			}
			alpha = parts[index + 1]
			index += 2
			continue
		}
		if parts[index].contains('/') && !parts[index].contains('(') {
			halves := parts[index].split('/')
			if halves.len != 2 || halves[0] == '' {
				return error('"${parts[index]}" misplaces "/" in relative color')
			}
			channels << halves[0]
			alpha = halves[1]
			index++
			continue
		}
		channels << parts[index]
		index++
	}
	return channels, alpha
}

// style_relative_named_space_unchecked maps a function name to its space
// without checking the channel count; the caller pads omitted channels
// first and rejects extras itself.
fn style_relative_named_space_unchecked(name string) !string {
	match name {
		'rgb', 'rgba' {
			return 'srgb'
		}
		'hsl', 'hsla' {
			return 'hsl'
		}
		'hwb' {
			return 'hwb'
		}
		'lab', 'oklab', 'lch', 'oklch', 'gray' {
			return name
		}
		else {
			return error('"${name}()" has no relative form here')
		}
	}
}

// style_relative_names lists the channel idents per space, in order.
fn style_relative_names(space string) []string {
	match space {
		'srgb' {
			return ['r', 'g', 'b', 'alpha']
		}
		'hsl' {
			return ['h', 's', 'l', 'alpha']
		}
		'hwb' {
			return ['h', 'w', 'b', 'alpha']
		}
		'lab', 'oklab' {
			return ['l', 'a', 'b', 'alpha']
		}
		'lch', 'oklch' {
			return ['l', 'c', 'h', 'alpha']
		}
		'gray' {
			return ['g', 'alpha']
		}
		else {
			return ['c1', 'c2', 'c3', 'alpha']
		}
	}
}

fn style_apply_relative(space string, origin StyleSrgb, channels []string, alpha_raw string) !StyleSrgb {
	origin_channels := style_space_channels(space, origin)!
	names := style_relative_names(space)
	mut values := [origin_channels.x, origin_channels.y, origin_channels.z]
	for index, channel in channels {
		if index >= 3 {
			return error('too many channels for relative color')
		}
		values[index] = style_relative_channel(space, names[index], channel, origin_channels)!
	}
	alpha := if alpha_raw == '' {
		origin.a
	} else {
		alpha_text := style_substitute_channels(alpha_raw, names, origin_channels)!
		style_alpha_value(alpha_text)!
	}
	return style_compose_relative(space, values, alpha)!
}

fn style_substitute_channels(raw string, names []string, origin StyleChannels) !string {
	trimmed := raw.trim_space()
	lower := trimmed.to_lower()
	if lower !in names {
		return raw
	}
	slot := names.index(lower)
	matched := match slot {
		0 {
			origin.x
		}
		1 {
			origin.y
		}
		2 {
			origin.z
		}
		else {
			return raw
		}
	}
	return matched.str()
}

// style_relative_channel resolves one relative channel: a plain value, a
// `calc()` over origin channels, or the origin channel ident itself.
fn style_relative_channel(space string, name string, raw string, origin StyleChannels) !f64 {
	expanded := style_expand_channel_idents(raw, name, space, origin)!
	match space {
		'srgb' {
			return style_relative_srgb_channel(expanded)
		}
		'hsl' {
			return style_relative_hsl_channel(name, expanded)
		}
		'hwb' {
			return style_relative_hwb_channel(name, expanded)
		}
		'lab', 'lch', 'oklab', 'oklch' {
			return style_relative_lab_channel(space, name, expanded)
		}
		'gray' {
			return style_relative_gray_channel(expanded)
		}
		else {
			return error('relative colors into "${space}" are not supported')
		}
	}
}

// style_expand_channel_idents swaps whole-word channel idents for the
// origin's numeric values, so `calc()` keeps working on top.
fn style_expand_channel_idents(raw string, name string, space string, origin StyleChannels) !string {
	names := style_relative_names(space)
	// Substituted idents use each channel's bare-number scale, so calc() on
	// top of them matches literal math: srgb runs 0..255, hsl s/l and gray
	// run 0..100, everything else is already unit-scale.
	mult := if space == 'srgb' {
		255.0
	} else if (space == 'hsl' && (name == 's' || name == 'l')) || space == 'gray' {
		100.0
	} else {
		1.0
	}
	origin_values := [origin.x * mult, origin.y * mult, origin.z * mult]
	mut out := []u8{}
	mut index := 0
	mut matched := -1
	for index < raw.len {
		matched = -1
		mut end := index
		if (raw[index] >= `a` && raw[index] <= `z`) || (raw[index] >= `A`
			&& raw[index] <= `Z`) {
			end = index
			for end < raw.len
				&& ((raw[end] >= `a` && raw[end] <= `z`) || (raw[end] >= `A` && raw[end] <= `Z`)) {
				end++
			}
			word := raw[index..end].to_lower()
			slot := names.index(word)
			if slot >= 0 && slot <= 2 {
				matched = slot
			} else if word in ['red', 'green', 'blue', 'hue', 'saturation', 'lightness', 'whiteness',
				'blackness', 'light', 'chroma'] {
				return error('"${word}" is not a channel of ${space} here; use ${names[..3].join('/')}')
			}
		}
		if matched >= 0 {
			out << origin_values[matched].str().bytes()
			index = end
		} else {
			out << raw[index]
			index++
		}
	}
	_ = name
	return out.bytestr()
}

fn style_relative_srgb_channel(expanded string) !f64 {
	text := expanded.trim_space().to_lower()
	if text.ends_with('%') {
		number := query_plain_number(text[..text.len - 1]) or {
			return error('"${expanded}" is not a color channel')
		}
		return unit_clamp(number / 100)
	}
	number := query_plain_number(text) or {
		parsed := style_math_channel(expanded, StyleLengthCtx{}) or {
			return error('"${expanded}" is not a color channel')
		}
		if parsed.dim == .percent {
			return unit_clamp(parsed.value / 100)
		}
		if parsed.dim == .scalar {
			return parsed.value / 255
		}
		return error('"${expanded}" is not a color channel')
	}
	return number / 255
}

fn style_relative_hsl_channel(name string, expanded string) !f64 {
	if name == 'h' {
		return style_channel_angle(expanded)!
	}
	text := expanded.trim_space().to_lower()
	if text.ends_with('%') {
		number := query_plain_number(text[..text.len - 1]) or {
			return error('"${expanded}" is not a color channel')
		}
		return unit_clamp(number / 100)
	}
	number := query_plain_number(text) or {
		parsed := style_math_channel(expanded, StyleLengthCtx{}) or {
			return error('"${expanded}" is not a color channel')
		}
		if parsed.dim == .percent {
			return unit_clamp(parsed.value / 100)
		}
		if parsed.dim == .scalar {
			return parsed.value / 100
		}
		return error('"${expanded}" is not a color channel')
	}
	return number / 100
}

fn style_relative_hwb_channel(name string, expanded string) !f64 {
	if name == 'h' {
		return style_channel_angle(expanded)!
	}
	return style_relative_hsl_channel(name, expanded)!
}

fn style_relative_lab_channel(space string, name string, expanded string) !f64 {
	if (space == 'lch' || space == 'oklch') && name == 'h' {
		return style_channel_angle(expanded)!
	}
	text := expanded.trim_space()
	number := query_plain_number(text) or {
		parsed := style_math_channel(expanded, StyleLengthCtx{}) or {
			return error('"${expanded}" is not a color channel')
		}
		if parsed.dim == .percent && (space == 'lab' || space == 'lch') && name == 'l' {
			return parsed.value
		}
		if parsed.dim == .percent && (space == 'oklab' || space == 'oklch') && name == 'l' {
			return parsed.value / 100
		}
		if parsed.dim == .percent {
			// a/b/c percentages behave as bare numbers (documented).
			return parsed.value
		}
		if parsed.dim == .scalar {
			return parsed.value
		}
		return error('"${expanded}" is not a color channel')
	}
	return number
}

fn style_relative_gray_channel(expanded string) !f64 {
	text := expanded.trim_space().to_lower()
	if text.ends_with('%') {
		number := query_plain_number(text[..text.len - 1]) or {
			return error('"${expanded}" is not a gray channel')
		}
		return unit_clamp(number / 100)
	}
	number := query_plain_number(text) or {
		return error('"${expanded}" is not a gray channel')
	}
	return unit_clamp(number / 100)
}

fn style_compose_relative(space string, values []f64, alpha f64) !StyleSrgb {
	a := unit_clamp(alpha)
	match space {
		'srgb' {
			return StyleSrgb{
				r: unit_clamp(values[0])
				g: unit_clamp(values[1])
				b: unit_clamp(values[2])
				a: a
			}
		}
		'hsl' {
			return style_srgb_from_hsl(values[0], values[1], values[2], a)
		}
		'hwb' {
			return style_srgb_from_hwb(values[0], values[1], values[2], a)
		}
		'lab' {
			return style_srgb_from_space('lab', values[0], values[1], values[2], a)!
		}
		'lch' {
			return style_srgb_from_space('lch', values[0], values[1], values[2], a)!
		}
		'oklab' {
			return style_srgb_from_space('oklab', values[0], values[1], values[2], a)!
		}
		'oklch' {
			return style_srgb_from_space('oklch', values[0], values[1], values[2], a)!
		}
		'gray' {
			gray := unit_clamp(values[0])
			return StyleSrgb{ r: gray, g: gray, b: gray, a: a }
		}
		else {
			return error('relative colors into "${space}" are not supported')
		}
	}
}
