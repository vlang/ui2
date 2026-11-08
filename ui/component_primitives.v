module ui2

import math

// ComponentSize provides shared metrics for the portable component catalog.
pub enum ComponentSize {
	small
	medium
	large
}

pub struct ComponentMetrics {
pub:
	height    f64
	font_size f64
	padding   f64
	gap       f64
	radius    f64
}

pub fn component_metrics(size ComponentSize) ComponentMetrics {
	return match size {
		.small { ComponentMetrics{24, 12, 6, 4, 4} }
		.medium { ComponentMetrics{32, 14, 8, 6, 6} }
		.large { ComponentMetrics{40, 16, 12, 8, 8} }
	}
}

pub enum ComponentTone {
	neutral
	primary
	success
	warning
	danger
}

// ComponentTheme is a value, not global state. Pass the same theme to related
// components and rebuild with a different value to change their appearance.
pub struct ComponentTheme {
pub:
	background         u32 = 0xffffff
	foreground         u32 = 0x172033
	muted              u32 = 0xf1f5f9
	muted_foreground   u32 = 0x64748b
	border             u32 = 0xcbd5e1
	primary            u32 = 0x2563eb
	primary_foreground u32 = 0xffffff
	success            u32 = 0x15803d
	success_foreground u32 = 0xffffff
	warning            u32 = 0xfbbf24
	warning_foreground u32 = 0x172033
	danger             u32 = 0xb91c1c
	danger_foreground  u32 = 0xffffff
}

pub fn component_theme(dark bool) ComponentTheme {
	if !dark {
		return ComponentTheme{}
	}
	return ComponentTheme{
		background:         0x172033
		foreground:         0xf8fafc
		muted:              0x263449
		muted_foreground:   0xb4c0d0
		border:             0x475569
		primary:            0x93c5fd
		primary_foreground: 0x172033
		success:            0x86efac
		success_foreground: 0x172033
		warning:            0xfbbf24
		warning_foreground: 0x172033
		danger:             0xfca5a5
		danger_foreground:  0x172033
	}
}

// colors returns background and foreground colors for a semantic tone.
pub fn (theme ComponentTheme) colors(tone ComponentTone) (u32, u32) {
	match tone {
		.neutral { return theme.muted, theme.foreground }
		.primary { return theme.primary, theme.primary_foreground }
		.success { return theme.success, theme.success_foreground }
		.warning { return theme.warning, theme.warning_foreground }
		.danger { return theme.danger, theme.danger_foreground }
	}
}

fn component_finite(value f64) bool {
	return !math.is_nan(value) && !math.is_inf(value, 0)
}

fn component_validate_frame(frame Rect) ! {
	if !component_finite(frame.x) || !component_finite(frame.y)
		|| !component_finite(frame.width) || !component_finite(frame.height)
		|| !component_finite(frame.x + frame.width)
		|| !component_finite(frame.y + frame.height)
		|| frame.width < 0 || frame.height < 0 {
		return error('component frame must be finite with non-negative dimensions')
	}
}

fn component_validate_id(id string) ! {
	if id.trim_space().len == 0 {
		return error('interactive component requires a non-empty id')
	}
}

// component_inset clamps padding to half each dimension. It preserves the
// coordinate space of frame, including when the available space is zero.
pub fn component_inset(frame Rect, padding f64) !Rect {
	component_validate_frame(frame)!
	if !component_finite(padding) || padding < 0 {
		return error('component padding must be finite and non-negative')
	}
	px := math.min(padding, frame.width / 2)
	py := math.min(padding, frame.height / 2)
	return rect(frame.x + px, frame.y + py, frame.width - 2 * px, frame.height - 2 * py)
}

// component_text_width_estimate approximates how wide text renders. ui/ has no
// backend-neutral measurement, so wide (CJK, emoji) runes count as one em and the
// rest as a typical proportional glyph; callers add padding for the slack. The em
// is the platform's: a point is 4/3 of a pixel on Windows and Linux.
fn component_text_width_estimate(text string, font_size f64) f64 {
	mut ems := 0.0
	for r in text.runes() {
		ems += if r >= 0x2e80 { 1.0 } else { 0.62 }
	}
	return ems * font_em_pixels(font_size)
}

fn component_local(frame Rect) Rect {
	return rect(0, 0, frame.width, frame.height)
}

fn component_part_id(id string, part string) string {
	return if id.len == 0 { '' } else { '${id}:component:${part}' }
}

// component_action_part returns what follows `${id}:component:` in an action an
// interactive component emitted, or none when the action belongs to something
// else. Each component's decoder builds on it to turn an action back into a
// typed request against the application's current state.
pub fn component_action_part(id string, action string) ?string {
	if id.len == 0 {
		return none
	}
	prefix := component_part_id(id, '')
	if !action.starts_with(prefix) || action.len == prefix.len {
		return none
	}
	return action[prefix.len..]
}

// component_parse_index decodes the decimal a component wrote into an action:
// digits only, no sign and no leading zero, and no larger than limit. Checking
// against limit digit by digit means a forged action can neither overflow nor
// name something the component never showed.
fn component_parse_index(digits string, limit int) ?int {
	if digits.len == 0 || limit < 0 || (digits.len > 1 && digits[0] == `0`) {
		return none
	}
	mut value := 0
	for ch in digits.bytes() {
		if ch < `0` || ch > `9` {
			return none
		}
		digit := int(ch - `0`)
		if digit > limit || value > (limit - digit) / 10 {
			return none
		}
		value = value * 10 + digit
	}
	return value
}

// component_keep_animating starts definition on id unless an animation is
// already running there, so a component can ask for its looping animation on
// every build without restarting it from the beginning.
pub fn component_keep_animating(id string, definition Animation) {
	if id.len == 0 || animation_info(id).status == .running {
		return
	}
	definition.start(id)
}

fn component_box(bg u32, border u32, radius f64) BoxStyle {
	return BoxStyle{
		bg:            bg
		radius:        radius
		border_color:  border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}
}

fn component_text(text string, frame Rect, color u32, size f64, bold bool) Element {
	return label('', text, frame, TextStyle{
		color: color
		size:  size
		bold:  bold
	})
}

fn component_finish(el Element) !Element {
	validate_element_tree(el)!
	return el
}

// component_popup_shadow is the drop shadow a floating surface casts: popovers,
// menus, hover cards, dialogs and sheets, as GPUI Kit's popups do.
pub fn component_popup_shadow() BoxShadow {
	return box_shadow(0x000000, 0.16, 24, 8)
}

// component_card_shadow is the lighter shadow of a surface that floats closer to
// the page, such as a notification.
pub fn component_card_shadow() BoxShadow {
	return box_shadow(0x000000, 0.12, 16, 4)
}
