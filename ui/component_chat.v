module ui2

import hash.fnv1a
import math

// Shared parts of the chat components ported from GPUI Kit: Bubble
// (component_chat_bubble.v), Message (component_chat_message.v), Marker
// (component_chat_marker.v) and AvatarGroup (component_chat_avatar.v). They are
// original V implementations of GPUI Kit's documented behavior.

// MessageAlignment places a message, a bubble or a reaction region at the
// leading (start) or trailing (end) edge of its row: incoming messages usually
// start, outgoing ones end.
pub enum MessageAlignment {
	start
	end
}

// ChatGroupPosition is where a message or bubble sits in a run of consecutive
// ones from the same sender. A run shows the sender's name once, above the
// first, and the avatar once, beside the last; the bubbles' corners where two
// of them meet are tightened so the run reads as one block.
pub enum ChatGroupPosition {
	single
	first
	middle
	last
}

// chat_group_positions groups consecutive equal keys, such as the author of
// each message in a transcript, and returns each one's position in its run. An
// empty key (a marker, a system notice) never joins a run, and breaks one.
pub fn chat_group_positions(keys []string) []ChatGroupPosition {
	mut positions := []ChatGroupPosition{cap: keys.len}
	for i, key in keys {
		joins_previous := key.len > 0 && i > 0 && keys[i - 1] == key
		joins_next := key.len > 0 && i + 1 < keys.len && keys[i + 1] == key
		positions << if joins_previous && joins_next {
			ChatGroupPosition.middle
		} else if joins_previous {
			ChatGroupPosition.last
		} else if joins_next {
			ChatGroupPosition.first
		} else {
			ChatGroupPosition.single
		}
	}
	return positions
}

// chat_group_opens reports whether a position starts its run, so it carries the
// run's header.
fn chat_group_opens(position ChatGroupPosition) bool {
	return position == .single || position == .first
}

// chat_group_closes reports whether a position ends its run, so it carries the
// run's avatar.
fn chat_group_closes(position ChatGroupPosition) bool {
	return position == .single || position == .last
}

// ── Text estimates ─────────────────────────────────────────────────

// chat_line_limit bounds how many lines a wrap estimate produces.
const chat_line_limit = 1000

// chat_label_slack is room a label gets beyond the estimated width of its text,
// so a native control that pads its text never has to truncate it.
const chat_label_slack = 4.0

fn chat_is_emoji_modifier(r rune) bool {
	return (r >= 0xfe00 && r <= 0xfe0f) || r == 0x200d || r == 0x20e3
		|| (r >= 0x1f3fb && r <= 0x1f3ff)
}

fn chat_is_emoji(r rune) bool {
	return r >= 0x1f000 || (r >= 0x2600 && r <= 0x27bf) || (r >= 0x2b00 && r <= 0x2bff)
}

// chat_text_width estimates how wide text draws at font_size points. Letters use
// the per-letter estimate the dialogs wrap their text with, which errs a little
// wide; an emoji draws wider than an em, and the selectors, joiners and skin
// tones that follow one draw nothing on their own.
fn chat_text_width(text string, font_size f64, bold bool) f64 {
	em := font_em_pixels(font_size) * if bold { 1.09 } else { 1.03 }
	mut letters := []rune{cap: text.len}
	mut emoji := 0
	for r in text.runes() {
		if chat_is_emoji_modifier(r) {
			continue
		}
		if chat_is_emoji(r) {
			emoji++
			continue
		}
		letters << r
	}
	return dialog_wrap_width(letters.string(), em) + f64(emoji) * 1.3 * em
}

// chat_wrap breaks text into the lines a label width wide draws it on: at its
// own newlines and between words. max_lines above zero keeps that many, the last
// one holding the rest of the text as the label truncates it.
fn chat_wrap(text string, font_size f64, bold bool, width f64, max_lines int) []string {
	if text.len == 0 {
		return []string{}
	}
	if max_lines == 1 {
		return [text.replace('\n', ' ')]
	}
	limit := if max_lines > 0 { max_lines } else { chat_line_limit }
	return wrap_text_lines_measured(text, math.max(width - chat_label_slack, 1), limit,
		fn [font_size, bold] (line string) f64 {
			return chat_text_width(line, font_size, bold)
		})
}

// chat_lines_height is how tall `lines` lines of font_size text are.
fn chat_lines_height(lines int, font_size f64) f64 {
	if lines <= 0 {
		return 0
	}
	return math.ceil(f64(lines) * font_line_height(font_size)) + if lines > 1 { 2.0 } else { 0.0 }
}

// chat_widest is the width of the widest line, with the label slack.
fn chat_widest(lines []string, font_size f64, bold bool) f64 {
	mut widest := 0.0
	for line in lines {
		widest = math.max(widest, chat_text_width(line, font_size, bold))
	}
	return if lines.len > 0 { math.ceil(widest + chat_label_slack) } else { 0.0 }
}

fn chat_font(requested f64, preset f64) f64 {
	return if requested > 0 { requested } else { preset }
}

// chat_length is a length the layouts can use: non-finite and negative
// values count as zero, so a list can size rows from any input.
fn chat_length(value f64) f64 {
	return if component_finite(value) { math.max(value, 0) } else { 0.0 }
}

fn chat_validate_length(name string, value f64) ! {
	if !component_finite(value) || value < 0 {
		return error('${name} must be finite and non-negative')
	}
}

// ── Colors ─────────────────────────────────────────────────────────

fn chat_luminance(color u32) f64 {
	r := f64((color >> 16) & 0xff) / 255
	g := f64((color >> 8) & 0xff) / 255
	b := f64(color & 0xff) / 255
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

// chat_is_dark tells a dark theme from a light one by its background, since a
// ComponentTheme carries colors rather than a mode.
fn chat_is_dark(theme ComponentTheme) bool {
	return chat_luminance(theme.background) < 0.5
}

fn chat_mix(from u32, to u32, amount f64) u32 {
	return interpolate_color(from, to, math.clamp(amount, 0, 1))
}

// Identity colors: twelve hues, each a pale fill with deep initials in a light
// theme and a deep fill with pale initials in a dark one, all at least WCAG AA.
const chat_identity_light = [u32(0xfee2e2), 0x991b1b, 0xffedd5, 0x9a3412, 0xfef3c7, 0x92400e, 0xecfccb,
	0x3f6212, 0xdcfce7, 0x166534, 0xccfbf1, 0x115e59, 0xcffafe, 0x155e75, 0xe0f2fe, 0x075985, 0xe0e7ff,
	0x3730a3, 0xede9fe, 0x5b21b6, 0xfae8ff, 0x86198f, 0xffe4e6, 0x9f1239]
const chat_identity_dark = [u32(0x7f1d1d), 0xfecaca, 0x7c2d12, 0xfed7aa, 0x78350f, 0xfde68a, 0x365314,
	0xd9f99d, 0x14532d, 0xbbf7d0, 0x134e4a, 0x99f6e4, 0x164e63, 0xa5f3fc, 0x0c4a6e, 0xbae6fd, 0x312e81,
	0xc7d2fe, 0x4c1d95, 0xddd6fe, 0x701a75, 0xf5d0fe, 0x881337, 0xfecdd3]

// avatar_identity_colors returns the fill and initials colors of a name: one of
// twelve hues picked from its initials, so the same person always gets the same
// color, in the light or the dark variant.
pub fn avatar_identity_colors(name string, dark bool) (u32, u32) {
	hue := int(fnv1a.sum32_string(avatar_initials(name)) % 12)
	pairs := if dark { chat_identity_dark } else { chat_identity_light }
	return pairs[hue * 2], pairs[hue * 2 + 1]
}

// avatar_identity_theme returns theme with its muted fill and foreground set to
// name's identity colors, which is what `avatar` draws initials with:
// `avatar(name: n, frame: f, theme: avatar_identity_theme(n, theme))`.
pub fn avatar_identity_theme(name string, theme ComponentTheme) ComponentTheme {
	bg, fg := avatar_identity_colors(name, chat_is_dark(theme))
	return ComponentTheme{
		...theme
		muted:      bg
		foreground: fg
	}
}

// ── Surfaces ───────────────────────────────────────────────────────

// ChatCorners names the corners of a surface that take the tighter radius.
struct ChatCorners {
	top_left     bool
	top_right    bool
	bottom_right bool
	bottom_left  bool
}

// chat_joined_corners returns the corners a bubble at position tightens: those
// on its sender's side that face the bubble above or below it in the run.
fn chat_joined_corners(alignment MessageAlignment, position ChatGroupPosition) ChatCorners {
	above := position == .middle || position == .last
	below := position == .first || position == .middle
	if alignment == .start {
		return ChatCorners{
			top_left:    above
			bottom_left: below
		}
	}
	return ChatCorners{
		top_right:    above
		bottom_right: below
	}
}

// chat_surface draws a rounded surface whose `corners` have the tighter radius
// `joined`. A BoxStyle has one radius, so a tightened corner is a patch in the
// surface color with the small radius laid over the round one. A border is a
// border-colored shape with the fill inset over it, patched the same way, so
// it follows the corners on every renderer.
fn chat_surface(frame Rect, fill u32, border u32, border_width f64, radius f64, joined f64, corners ChatCorners) []Element {
	r := math.max(0, math.min(radius, math.min(frame.width, frame.height) / 2))
	if border_width <= 0 {
		return chat_surface_layer(frame, fill, r, joined, corners)
	}
	bw := math.min(border_width, math.min(frame.width, frame.height) / 2)
	mut out := chat_surface_layer(frame, border, r, joined, corners)
	inner := rect(frame.x + bw, frame.y + bw, frame.width - 2 * bw, frame.height - 2 * bw)
	out << chat_surface_layer(inner, fill, math.max(r - bw, 0), math.max(joined - bw, 0),
		corners)
	return out
}

fn chat_surface_layer(frame Rect, color u32, radius f64, joined f64, corners ChatCorners) []Element {
	mut out := [view('', frame, BoxStyle{
		bg:     color
		radius: radius
	}, []Element{})]
	tight := math.max(0, math.min(joined, radius))
	if tight >= radius {
		return out
	}
	// A patch reaches past the round corner by its own radius, so its other,
	// rounded corners lie over the straight edges of the surface.
	width := math.min(radius + tight, frame.width)
	height := math.min(radius + tight, frame.height)
	for corner in 0 .. 4 {
		wanted := match corner {
			0 { corners.top_left }
			1 { corners.top_right }
			2 { corners.bottom_right }
			else { corners.bottom_left }
		}
		if !wanted {
			continue
		}
		x := if corner == 0 || corner == 3 { frame.x } else { frame.x + frame.width - width }
		y := if corner < 2 { frame.y } else { frame.y + frame.height - height }
		out << view('', rect(x, y, width, height), BoxStyle{
			bg:     color
			radius: tight
		}, []Element{})
	}
	return out
}

// chat_symbol draws a known symbol filling frame in color.
fn chat_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}
