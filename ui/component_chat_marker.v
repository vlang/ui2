module ui2

import math

// MarkerVariant is a marker's decoration.
pub enum MarkerVariant {
	plain     // A compact status row.
	separator // A line on each side of the label, such as a date divider.
	border    // A line under the row.
}

// MarkerAlignment places a marker's content in its full-width row.
pub enum MarkerAlignment {
	auto  // Separators center their label, other variants start.
	start // A separator then draws only its trailing line.
	center
	end // A separator then draws only its leading line.
}

// MarkerLoadingStyle is how a loading marker moves.
pub enum MarkerLoadingStyle {
	spinner // A small spinner in the icon slot, unless the marker has an icon.
	shimmer // The text pulses with shimmer_text.
}

pub struct MarkerConfig {
pub:
	id string // Required while loading (the animation runs on its parts) and with an action.
	// frame is the marker's row: x, y and width. The element is as tall as
	// frame.height or its content (marker_height), whichever is more.
	frame         Rect
	text          string // Wraps when wider than the row, except while it shimmers.
	icon          string // A symbol name (symbol_known) before the text.
	variant       MarkerVariant
	alignment     MarkerAlignment
	loading       bool
	loading_style MarkerLoadingStyle
	reduce_motion bool // Loading markers stay still.
	// shimmer_duration is one shimmer pulse, in seconds.
	shimmer_duration f64 = 2.0
	// action_label adds a trailing text button such as 'Retry' or 'Show'; it
	// emits marker_action_id.
	action_label string
	color        ?u32 // Text color; defaults to the muted text color.
	icon_color   ?u32 // Defaults to the text color.
	line_color   ?u32 // Separator lines and the border; defaults to the border color.
	// background draws a rounded surface behind the content, for a notice that
	// should stand out such as a pinned message.
	background          ?u32
	bold                bool
	font_size           f64 // 0 uses the size preset: 12, 13 or 15.
	size                ComponentSize = .medium
	theme               ComponentTheme
	accessibility_role  string // Defaults to 'status' while loading.
	accessibility_label string // Defaults to the text.
}

struct MarkerMetrics {
	font       f64
	icon       f64
	gap        f64
	border_pad f64
	pad_x      f64
	pad_y      f64
	min_line   f64
}

fn marker_metrics(size ComponentSize) MarkerMetrics {
	return match size {
		.small { MarkerMetrics{12, 12, 6, 6, 8, 2, 16} }
		.medium { MarkerMetrics{13, 14, 8, 8, 10, 3, 24} }
		.large { MarkerMetrics{15, 16, 8, 10, 12, 4, 32} }
	}
}

struct MarkerLayout {
	height   f64
	surface  Rect
	icon     Rect
	text     Rect
	action   Rect
	leading  Rect // Separator line before the content.
	trailing Rect // Separator line after it.
	border   Rect
	lines    int
}

// marker_alignment resolves .auto: separators center, everything else starts.
fn marker_alignment(config MarkerConfig) MarkerAlignment {
	if config.alignment != .auto {
		return config.alignment
	}
	return if config.variant == .separator { MarkerAlignment.center } else { MarkerAlignment.start }
}

fn marker_shimmers(config MarkerConfig) bool {
	return config.loading && config.loading_style == .shimmer
}

fn marker_spins(config MarkerConfig) bool {
	return config.loading && config.loading_style == .spinner && config.icon.len == 0
}

fn marker_layout(config MarkerConfig) MarkerLayout {
	m := marker_metrics(config.size)
	font := chat_font(config.font_size, m.font)
	row := if component_finite(config.frame.width) { math.max(config.frame.width, 0) } else { 0.0 }
	alignment := marker_alignment(config)
	line_height := math.ceil(font_line_height(font))
	icon := if config.icon.len > 0 || marker_spins(config) { m.icon } else { 0.0 }
	action := if config.action_label.len > 0 {
		math.ceil(chat_text_width(config.action_label, font, true) + chat_label_slack)
	} else {
		0.0
	}
	pad_x := if config.background != none { m.pad_x } else { 0.0 }
	pad_y := if config.background != none { m.pad_y } else { 0.0 }
	separator_lines := if config.variant != .separator {
		0
	} else if alignment == .center {
		2
	} else {
		1
	}
	mut fixed := 2 * pad_x + f64(separator_lines) * (m.min_line + m.gap)
	if icon > 0 {
		fixed += icon + if config.text.len > 0 { m.gap } else { 0.0 }
	}
	if action > 0 {
		fixed += action + m.gap
	}
	room := math.max(row - fixed, 0)
	lines := if marker_shimmers(config) {
		if config.text.len > 0 { [config.text.replace('\n', ' ')] } else { []string{} }
	} else {
		chat_wrap(config.text, font, config.bold, room, 0)
	}
	text_width := if lines.len == 1 {
		math.min(chat_widest(lines, font, config.bold), room)
	} else if lines.len > 1 {
		room
	} else {
		0.0
	}
	text_height := chat_lines_height(lines.len, font)
	block_inner := math.max(text_height, if icon > 0 || action > 0 {
		math.max(icon, line_height)
	} else {
		0.0
	})
	mut content_width := text_width
	if icon > 0 {
		content_width += icon + if text_width > 0 { m.gap } else { 0.0 }
	}
	if action > 0 {
		content_width += action + if content_width > 0 { m.gap } else { 0.0 }
	}
	block_width := math.min(content_width + 2 * pad_x, row)
	block_height := block_inner + 2 * pad_y
	x := match alignment {
		.start, .auto { 0.0 }
		.center { math.round((row - block_width) / 2) }
		.end { row - block_width }
	}
	// Icons, the action and the lines line up with the first line of text.
	first := pad_y + math.min(line_height, block_inner) / 2
	mut cx := x + pad_x
	mut icon_frame := rect(0, 0, 0, 0)
	if icon > 0 {
		icon_frame = rect(cx, math.round(first - icon / 2), icon, icon)
		cx += icon + m.gap
	}
	text_frame := rect(cx, pad_y, text_width, text_height)
	if text_width > 0 {
		cx += text_width + m.gap
	}
	action_frame := if action > 0 {
		rect(cx, math.round(first - line_height / 2), action, line_height)
	} else {
		rect(0, 0, 0, 0)
	}
	line_y := math.round(first)
	mut leading := rect(0, 0, 0, 0)
	mut trailing := rect(0, 0, 0, 0)
	if config.variant == .separator {
		if alignment != .start {
			leading = rect(0, line_y, math.max(x - m.gap, 0), 1)
		}
		if alignment != .end {
			start := x + block_width + m.gap
			trailing = rect(start, line_y, math.max(row - start, 0), 1)
		}
	}
	mut height := block_height
	mut border := rect(0, 0, 0, 0)
	if config.variant == .border {
		border = rect(0, block_height + m.border_pad, row, 1)
		height = border.y + 1
	}
	return MarkerLayout{
		height:   height
		surface:  rect(x, 0, block_width, block_height)
		icon:     icon_frame
		text:     text_frame
		action:   action_frame
		leading:  leading
		trailing: trailing
		border:   border
		lines:    lines.len
	}
}

// marker_height is how tall marker draws config: what a list gives the row.
pub fn marker_height(config MarkerConfig) f64 {
	return marker_layout(config).height
}

// marker_action_id is the action a marker's action button emits.
pub fn marker_action_id(id string) string {
	return component_part_id(id, 'action')
}

// marker_action_activated reports whether action is config's action button.
pub fn marker_action_activated(config MarkerConfig, action string) bool {
	return config.action_label.len > 0 && config.id.len > 0 && action == marker_action_id(config.id)
}

// stop_marker_animations stops the spinner or shimmer of the marker id. Call it
// when a loading marker leaves the tree: its loop keeps the native backends
// redrawing otherwise. A marker that stops loading stops them itself.
pub fn stop_marker_animations(id string) {
	stop_feedback_animations(id)
}

fn marker_validate(config MarkerConfig) ! {
	component_validate_frame(config.frame)!
	chat_validate_length('marker font size', config.font_size)!
	chat_validate_length('marker shimmer duration', config.shimmer_duration)!
	if config.icon.len > 0 && !symbol_known(config.icon) {
		return error('unknown marker icon `${config.icon}`')
	}
	if config.loading || config.action_label.len > 0 {
		component_validate_id(config.id)!
	}
}

// marker draws a compact status or timeline row: an icon and text, a date or
// "New messages" divider with a line on each side, or a row with a line under
// it. While loading it shows a spinner or makes its text shimmer.
pub fn marker(config MarkerConfig) !Element {
	marker_validate(config)!
	m := marker_metrics(config.size)
	layout := marker_layout(config)
	theme := config.theme
	font := chat_font(config.font_size, m.font)
	text_color := config.color or { theme.muted_foreground }
	line_color := config.line_color or { theme.border }
	alignment := marker_alignment(config)
	// A marker that stopped loading, or loads another way, stops the loop it
	// started before.
	if config.id.len > 0 {
		if !marker_spins(config) {
			feedback_clear_parts(config.id, 'spinner')
		}
		if !marker_shimmers(config) {
			feedback_clear_parts(config.id, 'shimmer')
		}
	}
	mut children := []Element{}
	if background := config.background {
		children << view('', layout.surface, BoxStyle{
			bg:     background
			radius: math.min(8, layout.surface.height / 2)
		}, []Element{})
	}
	for line in [layout.leading, layout.trailing, layout.border] {
		if line.width > 0 {
			children << view('', line, BoxStyle{ bg: line_color }, []Element{})
		}
	}
	if config.icon.len > 0 {
		children << chat_symbol(config.icon, layout.icon, config.icon_color or { text_color })
	} else if marker_spins(config) {
		children << loading_spinner(
			id:            component_part_id(config.id, 'spinner')
			frame:         layout.icon
			diameter:      layout.icon.width
			color:         config.icon_color or { text_color }
			background:    config.background or { theme.background }
			reduce_motion: config.reduce_motion
			theme:         theme
		)!
	}
	// A single line sits in a frame sized to an estimate that errs wide. Beside
	// an icon or an action it keeps to them; alone it shares the spare room out
	// as the alignment says, so a separator's label stays centered between its
	// lines. Wrapped lines follow the alignment.
	label_align := if layout.lines == 1 && (layout.icon.width > 0 || layout.action.width > 0) {
		Align.left
	} else {
		match alignment {
			.center { Align.center }
			.end { Align.right }
			else { Align.left }
		}
	}
	if layout.lines > 0 {
		if marker_shimmers(config) {
			children << shimmer_text(
				id:            component_part_id(config.id, 'shimmer')
				frame:         layout.text
				text:          config.text
				duration:      math.max(config.shimmer_duration, 0.001)
				reduce_motion: config.reduce_motion
				color:         text_color
				font_size:     font
				bold:          config.bold
				align:         label_align
				theme:         theme
			)!
		} else {
			// One line keeps a one-line budget: an AppKit label that may wrap draws
			// its text twice when its frame is barely wider than the text.
			children << label('', config.text, layout.text, TextStyle{
				color:  text_color
				size:   font
				bold:   config.bold
				align:  label_align
				valign: .top
				lines:  if layout.lines == 1 { 1 } else { 0 }
			})
		}
	}
	if config.action_label.len > 0 {
		children << Element{
			...button(marker_action_id(config.id), config.action_label, layout.action,
				BoxStyle{ transparent: true }, TextStyle{
					color: theme.primary
					size:  font
					bold:  true
					align: .center
				})
			cursor: cursor_pointing_hand
		}
	}
	role := if config.accessibility_role.len > 0 {
		config.accessibility_role
	} else if config.loading {
		'status'
	} else {
		''
	}
	return component_finish(Element{
		...view(config.id, rect(config.frame.x, config.frame.y, config.frame.width, math.max(config.frame.height,
			layout.height)), BoxStyle{ transparent: true }, children)
		accessibility_role:  role
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			config.text
		}
	})
}
