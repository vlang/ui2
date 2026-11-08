module ui2

import math

// AvatarGroupOverflow is what an avatar group shows for the avatars past its
// limit.
pub enum AvatarGroupOverflow {
	count    // A '+N' avatar.
	ellipsis // An ellipsis avatar.
	hidden   // Nothing.
}

pub struct AvatarGroupConfig {
pub:
	id string
	// frame holds the group: the avatars run from its left edge, centered
	// vertically. avatar_group_width tells how wide they are.
	frame Rect
	// avatars are drawn in order, each overlapping the next. The group sets
	// their frame and theme; their id, name and image_path are kept.
	avatars  []AvatarConfig
	limit    int = 3 // Most avatars shown; zero or less shows all of them.
	overflow AvatarGroupOverflow
	// overlap is the share of an avatar's diameter the one before it covers, 0
	// to 0.9. GPUI uses 0.3 without a ring; with the ring, 0.25 covers as much.
	overlap f64 = 0.25
	// diameter of each avatar; 0 uses the size preset: 24, 32 or 40.
	diameter        f64
	ring            f64 = 2 // A ring in the surface color around each avatar keeps them apart.
	ring_color      ?u32 // Defaults to the theme's background.
	identity_colors bool          = true // Color initials by name (avatar_identity_theme).
	size            ComponentSize = .medium
	theme           ComponentTheme
	// accessibility_label defaults to the names, ending with how many are hidden.
	accessibility_label string
}

// avatar_group_diameter is the avatar size of a size preset.
pub fn avatar_group_diameter(size ComponentSize) f64 {
	return component_metrics(size).height
}

fn avatar_group_size(config AvatarGroupConfig) f64 {
	return if config.diameter > 0 && component_finite(config.diameter) {
		config.diameter
	} else {
		avatar_group_diameter(config.size)
	}
}

// avatar_group_counts returns how many avatars a group of total shows within
// limit, how many it hides, and whether an overflow avatar stands for them.
pub fn avatar_group_counts(total int, limit int, overflow AvatarGroupOverflow) (int, int, bool) {
	count := math.max(total, 0)
	if limit <= 0 || count <= limit {
		return count, 0, false
	}
	return limit, count - limit, overflow != .hidden
}

// avatar_group_overflow_text is the '+N' of hidden avatars.
pub fn avatar_group_overflow_text(hidden int) string {
	return if hidden > 99 { '99+' } else { '+${hidden}' }
}

fn avatar_group_step(config AvatarGroupConfig) f64 {
	overlap := if component_finite(config.overlap) {
		math.clamp(config.overlap, 0, 0.9)
	} else {
		0.3
	}
	return avatar_group_size(config) * (1 - overlap)
}

fn avatar_group_ring(config AvatarGroupConfig) f64 {
	return if component_finite(config.ring) { math.max(config.ring, 0) } else { 0.0 }
}

// avatar_group_overflow_gap separates the overflow avatar from the last one: it
// stands apart rather than overlapping, as GPUI's ellipsis does.
const avatar_group_overflow_gap = 4.0

// avatar_group_width is how wide an avatar group draws config.
pub fn avatar_group_width(config AvatarGroupConfig) f64 {
	shown, _, extra := avatar_group_counts(config.avatars.len, config.limit, config.overflow)
	if shown == 0 && !extra {
		return 0
	}
	d := avatar_group_size(config)
	mut width := f64(math.max(shown - 1, 0)) * avatar_group_step(config) + d +
		2 * avatar_group_ring(config)
	if extra && shown > 0 {
		width += d + avatar_group_overflow_gap
	}
	return width
}

// avatar_group_initials_scale sizes initials to the diameter. They are smaller
// than a lone avatar's so the part of each avatar an overlap leaves shows them.
const avatar_group_initials_scale = 0.32

fn avatar_group_label(config AvatarGroupConfig, shown int, hidden int) string {
	if config.accessibility_label.len > 0 {
		return config.accessibility_label
	}
	mut names := []string{}
	for avatar_config in config.avatars[..shown] {
		if avatar_config.name.len > 0 {
			names << avatar_config.name
		}
	}
	mut summary := names.join(', ')
	if hidden > 0 {
		more := if hidden == 1 { '1 more' } else { '${hidden} more' }
		summary = if summary.len > 0 { '${summary} and ${more}' } else { more }
	}
	return summary
}

// avatar_group overlaps avatars in a row, the first on top, and stands one
// avatar in for those past the limit: '+N', an ellipsis, or nothing.
pub fn avatar_group(config AvatarGroupConfig) !Element {
	component_validate_frame(config.frame)!
	chat_validate_length('avatar group diameter', config.diameter)!
	chat_validate_length('avatar group ring', config.ring)!
	if !component_finite(config.overlap) || config.overlap < 0 || config.overlap > 0.9 {
		return error('avatar group overlap must be between 0 and 0.9')
	}
	theme := config.theme
	d := avatar_group_size(config)
	ring := avatar_group_ring(config)
	step := avatar_group_step(config)
	ring_color := config.ring_color or { theme.background }
	shown, hidden, extra := avatar_group_counts(config.avatars.len, config.limit, config.overflow)
	outer := d + 2 * ring
	y := math.round((config.frame.height - outer) / 2)
	mut items := []Element{cap: shown + 1}
	for index in 0 .. shown {
		person := config.avatars[index]
		person_theme := if config.identity_colors && person.image_path.len == 0 {
			avatar_identity_theme(person.name, theme)
		} else {
			theme
		}
		mut face := avatar(AvatarConfig{
			...person
			frame: rect(ring, ring, d, d)
			theme: person_theme
		})!
		if face.children.len == 1 && face.children[0].kind == .label {
			// Initials center in the part of the circle the avatar before this
			// one leaves showing. The frame keeps the whole width, so a native
			// label has its usual room and never truncates them.
			covered := if index > 0 { math.min(d - step + ring, d / 2) } else { 0.0 }
			initials := face.children[0]
			face = Element{
				...face
				children: [
					Element{
						...initials
						frame:      rect(covered / 2, 0, d, d)
						text_style: TextStyle{
							...initials.text_style
							size: math.max(math.round(d * avatar_group_initials_scale), 8)
						}
					},
				]
			}
		}
		mut item := Element{
			...view('', rect(f64(index) * step, y, outer, outer), BoxStyle{
				bg:     ring_color
				radius: outer / 2
			}, [face])
			key: 'avatar:${index}'
		}
		if person.name.len > 0 {
			item = with_tooltip(item, person.name)
		}
		items << item
	}
	if extra {
		local := rect(ring, ring, d, d)
		indicator := if config.overflow == .ellipsis {
			glyph := math.round(d * 0.5)
			chat_symbol('ellipsis', rect(ring + (d - glyph) / 2, ring + (d - glyph) / 2, glyph,
				glyph), theme.muted_foreground)
		} else {
			label('', avatar_group_overflow_text(hidden), local, TextStyle{
				color: theme.muted_foreground
				size:  math.max(math.round(d * 0.36), 8)
				bold:  true
				align: .center
			})
		}
		x := if shown > 0 { f64(shown - 1) * step + d + avatar_group_overflow_gap } else { 0.0 }
		items << Element{
			...view('', rect(x, y, outer, outer), BoxStyle{
				bg:     ring_color
				radius: outer / 2
			}, [
				view('', local, BoxStyle{
					bg:     theme.muted
					radius: d / 2
				}, []Element{}),
				indicator,
			])
			key:                 'more'
			accessibility_role:  'text'
			accessibility_label: if hidden == 1 { '1 more' } else { '${hidden} more' }
		}
	}
	// The first avatar is drawn last, so it lies on top of the one after it.
	items.reverse_in_place()
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, items)
		accessibility_role:  'group'
		accessibility_label: avatar_group_label(config, shown, hidden)
	})
}
