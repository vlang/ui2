module ui2

import math

pub struct StepperItem {
pub:
	title       string
	description string // Muted text under the title; wraps to at most two lines.
	icon        string // Symbol name shown in the indicator instead of the number.
	enabled     bool = true
}

pub struct StepperConfig {
pub:
	id          string
	frame       Rect
	items       []StepperItem
	current     int // Index of the current step; items.len marks every step completed.
	orientation LayoutOrientation = .horizontal
	clickable   bool              = true // False draws the steps without making them buttons.
	enabled     bool              = true
	text_center bool // Horizontal only: center each step's text under its indicator.
	size        ComponentSize = .medium
	theme       ComponentTheme
}

pub enum StepperStepState {
	completed
	current
	upcoming
}

// stepper_step_state classifies a step against the current one.
pub fn stepper_step_state(index int, current int) StepperStepState {
	return if index < current {
		.completed
	} else if index == current {
		.current
	} else {
		.upcoming
	}
}

pub fn stepper_action_id(id string, index int) string {
	return component_part_id(id, 'step:${index}')
}

fn stepper_clamped_current(config StepperConfig) int {
	return int(math.max(0, math.min(config.current, config.items.len)))
}

fn stepper_interactive(config StepperConfig) bool {
	return config.clickable && config.enabled
}

fn stepper_step_enabled(config StepperConfig, index int) bool {
	return stepper_interactive(config) && config.items[index].enabled
}

struct StepperMetrics {
	indicator   f64
	gap         f64
	thickness   f64 // Of the connecting lines.
	title_size  f64
	title_line  f64
	detail_size f64
	detail_line f64
}

fn stepper_metrics(size ComponentSize) StepperMetrics {
	metrics := component_metrics(size)
	detail_size := math.max(10.0, metrics.font_size - 2)
	return StepperMetrics{
		indicator:   match size {
			.small { 22.0 }
			.medium { 28.0 }
			.large { 36.0 }
		}
		gap:         metrics.gap
		thickness:   if size == .large { 3.0 } else { 2.0 }
		title_size:  metrics.font_size
		title_line:  choice_line_height(metrics.font_size)
		detail_size: detail_size
		detail_line: choice_line_height(detail_size)
	}
}

fn stepper_description_lines(description string, width f64, sm StepperMetrics) int {
	if description.len == 0 {
		return 0
	}
	if width <= 0 {
		return 1
	}
	return int(math.min(2.0, math.ceil(choice_text_width(description, sm.detail_size) / width)))
}

fn stepper_state_text(step_state StepperStepState) string {
	return match step_state {
		.completed { 'completed' }
		.current { 'current' }
		.upcoming { 'upcoming' }
	}
}

// stepper_indicator is the circle: filled with the primary color for completed
// and current steps, muted and ringed for upcoming ones. It shows the item's
// icon, a check mark for completed steps, or the step number.
fn stepper_indicator(frame Rect, index int, item StepperItem, step_state StepperStepState, enabled bool, theme ComponentTheme) Element {
	d := math.min(frame.width, frame.height)
	reached := step_state != .upcoming
	mut fill := if reached { theme.primary } else { theme.muted }
	mut ring := if reached { theme.primary } else { theme.border }
	mut ink := if reached { theme.primary_foreground } else { theme.muted_foreground }
	if !enabled {
		fill = choice_mix(fill, theme.background, 0.45)
		ring = choice_mix(ring, theme.background, 0.45)
		ink = choice_mix(ink, fill, 0.35)
	}
	mut children := choice_ring(rect(0, 0, d, d), d / 2, ring, fill, .all, false)
	if item.icon.len > 0 {
		icon := math.round(d * 0.55)
		children << choice_icon(item.icon, rect((d - icon) / 2, (d - icon) / 2, icon, icon),
			ink)
	} else {
		children << label('', if step_state == .completed { '✓' } else { '${index + 1}' }, rect(0, 0,
			d, d), TextStyle{
			color: ink
			size:  math.max(1.0, math.round(d * 0.46))
			bold:  step_state == .current
			align: .center
		})
	}
	return view('', frame, BoxStyle{ transparent: true }, children)
}

// stepper_text lays out a step's title and description inside a box of the
// given size, starting at y.
fn stepper_text(item StepperItem, x f64, y f64, width f64, lines int, step_state StepperStepState, enabled bool, align Align, box_width f64, box_height f64, sm StepperMetrics, theme ComponentTheme) []Element {
	title_color := if !enabled || step_state == .upcoming {
		theme.muted_foreground
	} else {
		theme.foreground
	}
	mut children := [
		label('', item.title, choice_fit(rect(x, y, width, sm.title_line), box_width, box_height), TextStyle{
			color: title_color
			size:  sm.title_size
			bold:  step_state == .current
			align: align
		}),
	]
	if lines > 0 {
		children << label('', item.description, choice_fit(rect(x, y + sm.title_line, width,
			f64(lines) * sm.detail_line), box_width, box_height), TextStyle{
			color:  if enabled { theme.muted_foreground } else { choice_disabled_text(theme) }
			size:   sm.detail_size
			align:  align
			valign: .top
			lines:  lines
		})
	}
	return children
}

struct StepperSlot {
	frame     Rect // The step, in stepper coordinates.
	indicator Rect // In step coordinates.
	text_x    f64
	text_y    f64
	text_w    f64
	lines     int
}

// stepper_slots divides the frame among the steps. Horizontally the last step
// only takes the room its text needs (as upstream, where every other step
// grows), unless text is centered, when all steps are equal. Vertically each
// step takes its natural height and the rest of the frame goes between them.
fn stepper_slots(config StepperConfig, sm StepperMetrics) []StepperSlot {
	n := config.items.len
	if n == 0 {
		return []StepperSlot{}
	}
	frame := config.frame
	d := math.max(0.0, math.min(sm.indicator, math.min(frame.width, frame.height)))
	mut slots := []StepperSlot{cap: n}
	if config.orientation == .horizontal {
		mut widths := []f64{len: n, init: frame.width / f64(n)}
		if !config.text_center && n > 1 {
			last := config.items[n - 1]
			natural := math.max(choice_text_width(last.title, sm.title_size), choice_text_width(last.description,
				sm.detail_size)) + sm.gap
			last_width := math.max(d, math.min(natural, frame.width / f64(n)))
			for i in 0 .. n - 1 {
				widths[i] = (frame.width - last_width) / f64(n - 1)
			}
			widths[n - 1] = last_width
		}
		mut x := 0.0
		for i, item in config.items {
			width := widths[i]
			text_w := math.max(0.0, width - sm.gap)
			indicator_x := if config.text_center { (width - d) / 2 } else { 0.0 }
			slots << StepperSlot{
				frame:     rect(x, 0, width, frame.height)
				indicator: rect(indicator_x, 0, d, d)
				text_x:    if config.text_center { sm.gap / 2 } else { 0.0 }
				text_y:    d + sm.gap
				text_w:    text_w
				lines:     stepper_description_lines(item.description, text_w, sm)
			}
			x += width
		}
		return slots
	}
	text_x := d + sm.gap * 2
	text_w := math.max(0.0, frame.width - text_x)
	// The title's first line is centered on the indicator.
	text_y := math.max(0.0, (d - sm.title_line) / 2)
	mut heights := []f64{cap: n}
	mut total := 0.0
	for item in config.items {
		lines := stepper_description_lines(item.description, text_w, sm)
		height := math.max(d, text_y + sm.title_line + f64(lines) * sm.detail_line)
		heights << height
		total += height
	}
	spacing := if n > 1 { math.max(0.0, (frame.height - total) / f64(n - 1)) } else { 0.0 }
	scale := if total > frame.height && total > 0 { frame.height / total } else { 1.0 }
	mut y := 0.0
	for i, item in config.items {
		height := heights[i] * scale + if i < n - 1 { spacing } else { 0.0 }
		slots << StepperSlot{
			frame:     rect(0, y, frame.width, height)
			indicator: rect(0, 0, d, d)
			text_x:    text_x
			text_y:    text_y
			text_w:    text_w
			lines:     stepper_description_lines(item.description, text_w, sm)
		}
		y += height
	}
	return slots
}

// stepper shows progress through a sequence of steps: completed steps before
// the current one, upcoming steps after it, joined by lines that take the
// primary color once passed. It is controlled: decode a click with
// stepper_step_from_action and rebuild with the returned step as `current`.
pub fn stepper(config StepperConfig) !Element {
	component_validate_frame(config.frame)!
	if stepper_interactive(config) {
		component_validate_id(config.id)!
	}
	sm := stepper_metrics(config.size)
	current := stepper_clamped_current(config)
	slots := stepper_slots(config, sm)
	horizontal := config.orientation == .horizontal
	mut children := []Element{}
	// Connectors go first so the steps, which cover them, stay on top.
	for i in 0 .. slots.len - 1 {
		from := slots[i]
		to := slots[i + 1]
		color := if i < current { config.theme.primary } else { config.theme.border }
		line := if horizontal {
			start := from.frame.x + from.indicator.x + from.indicator.width + sm.gap
			end := to.frame.x + to.indicator.x - sm.gap
			rect(start, from.indicator.y + (from.indicator.height - sm.thickness) / 2, end - start,
				sm.thickness)
		} else {
			start := from.frame.y + from.indicator.height + sm.gap
			end := to.frame.y - sm.gap
			rect((from.indicator.width - sm.thickness) / 2, start, sm.thickness, end - start)
		}
		if line.width > 0 && line.height > 0 {
			children << view('', choice_fit(line, config.frame.width, config.frame.height),
				BoxStyle{ bg: color }, []Element{})
		}
	}
	for index, item in config.items {
		slot := slots[index]
		step_state := stepper_step_state(index, current)
		item_enabled := config.enabled && item.enabled
		width := slot.frame.width
		height := slot.frame.height
		mut content := [
			stepper_indicator(choice_fit(slot.indicator, width, height), index, item, step_state,
				item_enabled, config.theme),
		]
		content << stepper_text(item, slot.text_x, slot.text_y, slot.text_w, slot.lines,
			step_state, item_enabled, if horizontal && config.text_center {
				Align.center
			} else {
				Align.left
			},
			width, height, sm, config.theme)
		label_text := 'Step ${index + 1} of ${config.items.len}: ${item.title}'
		children << if config.clickable {
			Element{
				...button_view(stepper_action_id(config.id, index), slot.frame, BoxStyle{ transparent: true }, content)
				key:                 'step:${index}'
				enabled:             stepper_step_enabled(config, index)
				accessibility_label: label_text
				accessibility_value: stepper_state_text(step_state)
			}
		} else {
			Element{
				...view('', slot.frame, BoxStyle{ transparent: true }, content)
				key:                 'step:${index}'
				accessibility_role:  'listitem'
				accessibility_label: label_text
				accessibility_value: stepper_state_text(step_state)
			}
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'list'
		accessibility_label: 'Progress'
		accessibility_value: if current >= config.items.len {
			'complete'
		} else {
			'Step ${current + 1} of ${config.items.len}'
		}
	})
}

// stepper_step_from_action returns the step a click asks for, or none for
// foreign, malformed or out-of-range actions, steppers that are not clickable
// or are disabled, disabled steps and the current step.
pub fn stepper_step_from_action(config StepperConfig, action string) ?int {
	if !stepper_interactive(config) || config.items.len == 0 {
		return none
	}
	part := component_action_part(config.id, action) or { return none }
	if !part.starts_with('step:') {
		return none
	}
	index := component_parse_index(part['step:'.len..], config.items.len - 1) or { return none }
	if !config.items[index].enabled || index == stepper_clamped_current(config) {
		return none
	}
	return index
}

// stepper_next_step is the first enabled step after the current one, for a
// Next button or the arrow keys. It does not require a clickable stepper.
pub fn stepper_next_step(config StepperConfig) ?int {
	if !config.enabled {
		return none
	}
	for index in stepper_clamped_current(config) + 1 .. config.items.len {
		if config.items[index].enabled {
			return index
		}
	}
	return none
}

// stepper_previous_step is the last enabled step before the current one.
pub fn stepper_previous_step(config StepperConfig) ?int {
	if !config.enabled {
		return none
	}
	mut index := stepper_clamped_current(config) - 1
	for index >= 0 {
		if config.items[index].enabled {
			return index
		}
		index--
	}
	return none
}

// stepper_step_after_key maps arrow keys along the stepper's orientation to
// the next or previous enabled step, and home/end to the first and last.
pub fn stepper_step_after_key(config StepperConfig, code KeyCode) ?int {
	horizontal := config.orientation == .horizontal
	if !config.enabled || config.items.len == 0 {
		return none
	}
	if (horizontal && code == .right) || (!horizontal && code == .down) {
		return stepper_next_step(config)
	}
	if (horizontal && code == .left) || (!horizontal && code == .up) {
		return stepper_previous_step(config)
	}
	enabled := []int{len: config.items.len, init: index}.filter(config.items[it].enabled)
	if enabled.len == 0 {
		return none
	}
	target := match code {
		.home { enabled[0] }
		.end { enabled[enabled.len - 1] }
		else { return none }
	}
	return if target == stepper_clamped_current(config) { none } else { target }
}
