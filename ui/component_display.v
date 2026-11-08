module ui2

import math

pub struct BadgeConfig {
pub:
	id        string
	frame     Rect
	text      string
	count     int = -1 // Negative means use text instead of a counter.
	max_count int = 99
	show_zero bool
	dot       bool
	tone      ComponentTone = .primary
	size      ComponentSize = .medium
	theme     ComponentTheme
}

pub fn badge_text(count int, max_count int) string {
	if count < 0 {
		return ''
	}
	limit := if max_count > 0 { max_count } else { 99 }
	return if count > limit { '${limit}+' } else { count.str() }
}

pub fn badge(config BadgeConfig) !Element {
	component_validate_frame(config.frame)!
	metrics := component_metrics(config.size)
	bg, fg := config.theme.colors(config.tone)
	badge_label := if config.count >= 0 {
		badge_text(config.count, config.max_count)
	} else {
		config.text
	}
	mut children := []Element{}
	if !config.dot {
		inner := component_inset(component_local(config.frame), metrics.padding / 2)!
		children << label('', badge_label, inner, TextStyle{
			color: fg
			size:  metrics.font_size
			align: .center
		})
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{
			bg:     bg
			radius: math.min(config.frame.width, config.frame.height) / 2
		}, children)
		hidden:              config.count == 0 && !config.show_zero && !config.dot
		accessibility_role:  'status'
		accessibility_label: if config.count >= 0 { config.count.str() } else { config.text }
	})
}

pub struct AvatarConfig {
pub:
	id         string
	frame      Rect
	name       string
	image_path string
	theme      ComponentTheme
}

// avatar_initials takes whole characters, never individual UTF-8 bytes.
// A single word contributes one initial; multiple words use first and last.
pub fn avatar_initials(name string) string {
	words := name.fields()
	if words.len == 0 {
		return '?'
	}
	first := avatar_initial(words[0])
	if words.len == 1 {
		return first.to_upper()
	}
	return (first + avatar_initial(words[words.len - 1])).to_upper()
}

// avatar_initial is a word's first Unicode scalar plus the combining marks after
// it, so a decomposed accent stays on its letter instead of being dropped.
fn avatar_initial(word string) string {
	runes := word.runes()
	mut end := 1
	for end < runes.len && avatar_is_combining_mark(runes[end]) {
		end++
	}
	return runes[..end].string()
}

fn avatar_is_combining_mark(r rune) bool {
	return (r >= 0x0300 && r <= 0x036f) || (r >= 0x1ab0 && r <= 0x1aff)
		|| (r >= 0x1dc0 && r <= 0x1dff) || (r >= 0x20d0 && r <= 0x20ff)
		|| (r >= 0xfe20 && r <= 0xfe2f)
}

pub fn avatar(config AvatarConfig) !Element {
	component_validate_frame(config.frame)!
	local := component_local(config.frame)
	child := if config.image_path.len > 0 {
		image('', config.image_path, local)
	} else {
		label('', avatar_initials(config.name), local, TextStyle{
			color: config.theme.foreground
			size:  math.min(config.frame.width, config.frame.height) * 0.4
			bold:  true
			align: .center
		})
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{
			bg:     config.theme.muted
			radius: math.min(config.frame.width, config.frame.height) / 2
		}, [child])
		accessibility_role:  'img'
		accessibility_label: config.name
	})
}

pub struct TagConfig {
pub:
	id           string
	frame        Rect
	text         string
	close_action string // Empty means the tag is not dismissible.
	enabled      bool = true
	outline      bool
	tone         ComponentTone
	size         ComponentSize = .medium
	theme        ComponentTheme
}

pub fn tag(config TagConfig) !Element {
	component_validate_frame(config.frame)!
	if config.close_action.len > 0 {
		component_validate_id(config.id)!
	}
	metrics := component_metrics(config.size)
	bg, fg := config.theme.colors(config.tone)
	background := if config.outline { config.theme.background } else { bg }
	foreground := if config.outline && config.tone != .neutral {
		bg
	} else if config.outline {
		config.theme.foreground
	} else {
		fg
	}
	inner := component_inset(component_local(config.frame), metrics.padding / 2)!
	close_width := if config.close_action.len > 0 {
		math.min(inner.height, inner.width)
	} else {
		0.0
	}
	mut children := [component_text(config.text, rect(inner.x, inner.y, inner.width - close_width,
		inner.height), foreground, metrics.font_size, false)]
	if config.close_action.len > 0 {
		children << Element{
			...button(component_part_id(config.id, 'close'), '×', rect(inner.x + inner.width - close_width,
				inner.y, close_width, inner.height), BoxStyle{ transparent: true }, TextStyle{
				color: foreground
				size:  metrics.font_size
				align: .center
			})
			action_id:           config.close_action
			enabled:             config.enabled
			accessibility_label: 'Remove ${config.text}'
		}
	}
	return component_finish(view(config.id, config.frame, component_box(background, if config.outline {
		bg
	} else {
		background
	}, metrics.radius), children))
}

pub struct SeparatorConfig {
pub:
	id          string
	frame       Rect
	orientation LayoutOrientation = .horizontal
	thickness   f64               = 1
	theme       ComponentTheme
}

pub fn separator(config SeparatorConfig) !Element {
	component_validate_frame(config.frame)!
	if !component_finite(config.thickness) || config.thickness < 0 {
		return error('separator thickness must be finite and non-negative')
	}
	vertical := config.orientation == .vertical
	extent := if vertical { config.frame.width } else { config.frame.height }
	thickness := math.min(config.thickness, extent)
	line := if vertical {
		rect((config.frame.width - thickness) / 2, 0, thickness, config.frame.height)
	} else {
		rect(0, (config.frame.height - thickness) / 2, config.frame.width, thickness)
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, [
			view('', line, BoxStyle{ bg: config.theme.border }, []Element{}),
		])
		accessibility_role: 'separator'
	})
}

pub struct SkeletonConfig {
pub:
	id     string
	frame  Rect
	circle bool
	radius f64 = 6
	theme  ComponentTheme
}

// skeleton is a static placeholder; applications can animate its color with
// UI2's animation API. It does not create timers or global animation state.
pub fn skeleton(config SkeletonConfig) !Element {
	component_validate_frame(config.frame)!
	if !component_finite(config.radius) || config.radius < 0 {
		return error('skeleton radius must be finite and non-negative')
	}
	limit := math.min(config.frame.width, config.frame.height) / 2
	if config.circle {
		side := limit * 2
		return component_finish(view(config.id, config.frame, BoxStyle{ transparent: true }, [
			view('', rect((config.frame.width - side) / 2, (config.frame.height - side) / 2,
				side, side), BoxStyle{ bg: config.theme.muted, radius: limit }, []Element{}),
		]))
	}
	return component_finish(view(config.id, config.frame, BoxStyle{
		bg:     config.theme.muted
		radius: math.min(config.radius, limit)
	}, []Element{}))
}

pub struct KbdConfig {
pub:
	id    string
	frame Rect
	keys  []string
	size  ComponentSize = .small
	theme ComponentTheme
}

pub fn kbd(config KbdConfig) !Element {
	component_validate_frame(config.frame)!
	metrics := component_metrics(config.size)
	hint := config.keys.join(' + ')
	inner := component_inset(component_local(config.frame), metrics.padding / 2)!
	return component_finish(Element{
		...view(config.id, config.frame, component_box(config.theme.muted, config.theme.border,
			metrics.radius), [label('', hint, inner, TextStyle{
			color:       config.theme.foreground
			size:        metrics.font_size
			font_family: 'monospace'
			align:       .center
		})])
		accessibility_label: hint
	})
}

pub struct LinkConfig {
pub:
	id        string
	frame     Rect
	text      string
	action_id string
	enabled   bool          = true
	size      ComponentSize = .medium
	theme     ComponentTheme
}

// link emits an ordinary UI2 action. The application owns navigation and URL
// validation; rendering a link never opens a browser as a side effect. Like
// every button, its text is centered in frame, so size the frame to the text.
pub fn link(config LinkConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	return component_finish(Element{
		...button(config.id, config.text, config.frame, BoxStyle{ transparent: true }, TextStyle{
			color:     if config.enabled {
				config.theme.primary
			} else {
				config.theme.muted_foreground
			}
			size:      component_metrics(config.size).font_size
			underline: true
		})
		action_id:           config.action_id
		enabled:             config.enabled
		accessibility_role:  'link'
		accessibility_label: config.text
	})
}
