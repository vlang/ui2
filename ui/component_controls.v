module ui2

import math

// Drawn form controls following GPUI Kit's Checkbox, Switch and Slider. ui2's
// `checkbox`, `switch_control` and `slider` are platform controls: AppKit draws
// an NSButton, NSSwitch and NSSlider whatever the theme, and none of them can
// show a description, an indeterminate mark, a second thumb or marks. The
// styled_* components here are views drawn the same way on every backend from a
// ComponentTheme. This file holds what they share plus the checkbox and the
// checkbox group; the switch and the slider live in component_controls_*.v.
//
// Like the other components they are controlled: they emit actions (and, for
// the slider, pointer events), the application decodes them with the
// component's decoder against the config it built with, stores the result and
// rebuilds.

// ── Shared ──────────────────────────────────────────────────────────

// controls_ring is the width of the focus ring drawn around a focused
// indicator. Components keep that much room around the indicator inside their
// frame, so the ring is never clipped.
const controls_ring = 2.0

// controls_label_lines and controls_detail_lines cap how many lines a label and
// a description wrap onto.
const controls_label_lines = 3
const controls_detail_lines = 4

fn controls_detail_size(font f64) f64 {
	return math.max(11.0, font - 2)
}

fn controls_text_style(color u32, size f64, lines int) TextStyle {
	return TextStyle{
		color:  color
		size:   size
		valign: .top
		lines:  lines
	}
}

// controls_wrapped_lines is how many lines text wraps onto at width, between 1
// and limit, or 0 for no text.
fn controls_wrapped_lines(text string, size f64, width f64, limit int) int {
	if text.len == 0 {
		return 0
	}
	if width <= 0 {
		return 1
	}
	count := wrap_text_to_width(text, TextStyle{ size: size }, width).len
	return if count < 1 {
		1
	} else if count > limit {
		limit
	} else {
		count
	}
}

// controls_text_width is the room a one-line label needs: the measured width
// and a point of slack, so a label laid out at that width never truncates.
fn controls_text_width(text string, size f64) f64 {
	if text.len == 0 {
		return 0
	}
	return math.ceil(measure_text_width(text, TextStyle{ size: size })) + 1
}

// ControlsRow lays out an indicator (a checkbox box or a switch track) with a
// label and a description beside it, as GPUI Kit's checkbox and switch do: the
// indicator is centered on the label's first line, the description goes under
// the label, and both wrap.
struct ControlsRow {
	height       f64  // Natural height of the row.
	indicator    Rect // Where the indicator goes, before vertical centering.
	label        Rect
	label_lines  int
	detail       Rect
	detail_lines int
}

struct ControlsRowSpec {
	width       f64
	indicator_w f64
	indicator_h f64
	label       string
	description string
	label_left  bool // The text goes before the indicator, which sits at the right edge.
	font        f64
	gap         f64
}

fn controls_row(spec ControlsRowSpec) ControlsRow {
	line := font_line_height(spec.font)
	detail_size := controls_detail_size(spec.font)
	detail_line := font_line_height(detail_size)
	band := math.max(spec.indicator_h + 2 * controls_ring, line)
	box_w := spec.indicator_w + 2 * controls_ring
	has_text := spec.label.len > 0 || spec.description.len > 0
	text_w := math.max(0.0, spec.width - box_w - if has_text {
		spec.gap - controls_ring
	} else {
		0.0
	})
	text_x := if spec.label_left { 0.0 } else { spec.width - text_w }
	label_lines := controls_wrapped_lines(spec.label, spec.font, text_w, controls_label_lines)
	detail_lines := controls_wrapped_lines(spec.description, detail_size, text_w, controls_detail_lines)
	label_y := (band - line) / 2
	label_h := f64(label_lines) * line
	detail_y := if label_lines > 0 { label_y + label_h + 2 } else { label_y }
	detail_h := f64(detail_lines) * detail_line
	mut height := band
	if label_lines > 0 {
		height = math.max(height, label_y + label_h + label_y)
	}
	if detail_lines > 0 {
		height = math.max(height, detail_y + detail_h + label_y)
	}
	indicator_x := if spec.label_left {
		math.max(0.0, spec.width - controls_ring - spec.indicator_w)
	} else {
		controls_ring
	}
	return ControlsRow{
		height:       height
		indicator:    rect(indicator_x, (band - spec.indicator_h) / 2, spec.indicator_w,
			spec.indicator_h)
		label:        rect(text_x, label_y, text_w, label_h)
		label_lines:  label_lines
		detail:       rect(text_x, detail_y, text_w, detail_h)
		detail_lines: detail_lines
	}
}

// controls_row_width is how wide a row must be to show its label on one line.
// A description wraps to whatever width the row is given.
fn controls_row_width(indicator_w f64, label string, font f64, gap f64) f64 {
	box_w := indicator_w + 2 * controls_ring
	if label.len == 0 {
		return box_w
	}
	return box_w + gap - controls_ring + controls_text_width(label, font)
}

// controls_shift moves a frame down by dy.
fn controls_shift(frame Rect, dy f64) Rect {
	return rect(frame.x, frame.y + dy, frame.width, frame.height)
}

// controls_row_children draws a row's label and description, offset by dy.
fn controls_row_children(row ControlsRow, dy f64, label_text string, description string, font f64, label_color u32, detail_color u32, width f64, height f64) []Element {
	mut children := []Element{}
	if row.label_lines > 0 {
		children << label('', label_text, choice_fit(controls_shift(row.label, dy), width,
			height), controls_text_style(label_color, font, row.label_lines))
	}
	if row.detail_lines > 0 {
		children << label('', description, choice_fit(controls_shift(row.detail, dy), width,
			height), controls_text_style(detail_color, controls_detail_size(font), row.detail_lines))
	}
	return children
}

// controls_focus_ring is the ring around a focused indicator: a rounded fill
// one ring wider than the indicator on every side, drawn under it. The
// indicator is opaque, so only the ring shows. It is half the accent over the
// background, as GPUI Kit's focus ring.
fn controls_focus_ring(frame Rect, radius f64, accent u32, theme ComponentTheme) Element {
	w := controls_ring
	return view('', rect(frame.x - w, frame.y - w, frame.width + 2 * w, frame.height + 2 * w),
		BoxStyle{
			bg:     choice_mix(accent, theme.background, 0.5)
			radius: radius + w
		}, []Element{})
}

// controls_enter_or_space reports whether a key activates a focused checkbox
// or switch: Space or Return without Command, Control or Option.
fn controls_enter_or_space(event KeyEvent) bool {
	if event.cmd || event.ctrl || event.alt {
		return false
	}
	return event.code in [.space, .enter, .kp_enter]
}

// ── Checkbox ────────────────────────────────────────────────────────

pub struct StyledCheckboxConfig {
pub:
	id          string
	frame       Rect
	label       string
	description string // Muted text under the label; both wrap to the frame's width.
	checked     bool
	// indeterminate draws a dash instead of the check and reports `mixed` to
	// assistive technology; activating it checks the box, as upstream.
	indeterminate bool
	enabled       bool = true
	// focused draws the focus ring around the box. Components cannot take
	// keyboard focus; set it while the application routes keys to the checkbox
	// (see styled_checkbox_checked_after_key).
	focused             bool
	tooltip             string
	action_id           string // Defaults to id.
	accessibility_label string // Defaults to label.
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// CheckboxMetrics are the box side and fonts of a checkbox size: GPUI Kit's
// 0.875rem, 1rem and 1.125rem boxes for small, medium and large.
struct CheckboxMetrics {
	box  f64
	font f64
	gap  f64
}

fn checkbox_metrics(size ComponentSize) CheckboxMetrics {
	return match size {
		.small { CheckboxMetrics{14, 12, 6} }
		.medium { CheckboxMetrics{16, 14, 8} }
		.large { CheckboxMetrics{18, 16, 8} }
	}
}

fn checkbox_value_text(checked bool, indeterminate bool) string {
	return if indeterminate {
		'mixed'
	} else if checked {
		'checked'
	} else {
		'unchecked'
	}
}

// checkbox_mark_path is the check (or the dash of an indeterminate box) for a
// box `side` units square, in the box's coordinates.
fn checkbox_mark_path(side f64, indeterminate bool) []PathCommand {
	if indeterminate {
		return path_polyline([path_point(side * 0.28, side * 0.5), path_point(side * 0.72, side * 0.5)], false)
	}
	return path_polyline([path_point(side * 0.26, side * 0.52), path_point(side * 0.43, side * 0.69),
		path_point(side * 0.75, side * 0.33)], false)
}

// checkbox_indicator draws the box at frame: the border under an inset fill,
// and the mark as a stroked path, so it is drawn alike everywhere and scales
// with the box. mark_id names the path, which the custom renderer caches.
fn checkbox_indicator(frame Rect, mark_id string, checked bool, indeterminate bool, enabled bool, focused bool, theme ComponentTheme) []Element {
	side := math.min(frame.width, frame.height)
	on := checked || indeterminate
	radius := math.round(side / 4)
	mut fill := if on { theme.primary } else { theme.background }
	mut border := if on { theme.primary } else { theme.border }
	mut mark := theme.primary_foreground
	if !enabled {
		fill = choice_mix(fill, theme.background, 0.5)
		border = choice_mix(border, theme.background, 0.5)
		mark = choice_mix(mark, fill, 0.3)
	}
	mut box_children := choice_ring(rect(0, 0, side, side), radius, border, fill, .all, false)
	if on && mark_id.len > 0 {
		box_children << shape(mark_id, rect(0, 0, side, side), checkbox_mark_path(side,
			indeterminate), ShapeStyle{
			stroke:       mark
			stroke_width: math.max(1.5, side / 8)
			line_cap:     .round
			line_join:    .round
		})
	}
	mut parts := []Element{}
	if focused && enabled {
		parts << controls_focus_ring(frame, radius, theme.primary, theme)
	}
	parts << view('', frame, BoxStyle{ transparent: true }, box_children)
	return parts
}

fn checkbox_row(config StyledCheckboxConfig, width f64) ControlsRow {
	cm := checkbox_metrics(config.size)
	return controls_row(ControlsRowSpec{
		width:       width
		indicator_w: cm.box
		indicator_h: cm.box
		label:       config.label
		description: config.description
		font:        cm.font
		gap:         cm.gap
	})
}

// styled_checkbox_width is how wide a checkbox's frame must be to show its
// label on one line. A description wraps to the width it is given.
pub fn styled_checkbox_width(config StyledCheckboxConfig) f64 {
	cm := checkbox_metrics(config.size)
	return controls_row_width(cm.box, config.label, cm.font, cm.gap)
}

// styled_checkbox_height is how tall a checkbox is at its frame's width, with
// its label and description wrapped.
pub fn styled_checkbox_height(config StyledCheckboxConfig) f64 {
	return checkbox_row(config, config.frame.width).height
}

fn checkbox_action(config StyledCheckboxConfig) string {
	return if config.action_id.len > 0 { config.action_id } else { config.id }
}

// styled_checkbox is GPUI Kit's Checkbox: a themed box with a label and an
// optional description, an indeterminate state and three sizes. The whole row
// is clickable. Decode its action with styled_checkbox_checked_from_action.
pub fn styled_checkbox(config StyledCheckboxConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	return component_finish(styled_checkbox_element(config, config.frame))
}

fn styled_checkbox_element(config StyledCheckboxConfig, frame Rect) Element {
	cm := checkbox_metrics(config.size)
	theme := config.theme
	row := checkbox_row(config, frame.width)
	dy := math.max(0.0, (frame.height - row.height) / 2)
	mut children := checkbox_indicator(choice_fit(controls_shift(row.indicator, dy), frame.width,
		frame.height), component_part_id(config.id, 'mark'), config.checked, config.indeterminate,
		config.enabled, config.focused, theme)
	label_color := if config.enabled { theme.foreground } else { choice_disabled_text(theme) }
	detail_color := if config.enabled {
		theme.muted_foreground
	} else {
		choice_disabled_text(theme)
	}
	children << controls_row_children(row, dy, config.label, config.description, cm.font,
		label_color, detail_color, frame.width, frame.height)
	el := Element{
		...button_view(config.id, frame, BoxStyle{ transparent: true }, children)
		action_id:           checkbox_action(config)
		enabled:             config.enabled
		accessibility_role:  'checkbox'
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			config.label
		}
		accessibility_value: checkbox_value_text(config.checked, config.indeterminate)
	}
	return if config.tooltip.len > 0 { with_tooltip(el, config.tooltip) } else { el }
}

// styled_checkbox_checked_from_action returns the checked value an action asks
// for: the opposite of `checked`, or true for an indeterminate box. None for
// other actions and while disabled.
pub fn styled_checkbox_checked_from_action(config StyledCheckboxConfig, action string) ?bool {
	if !config.enabled || config.id.len == 0 || action != checkbox_action(config) {
		return none
	}
	return config.indeterminate || !config.checked
}

// styled_checkbox_checked_after_key toggles the checkbox on Space or Return,
// as a focused GPUI Kit checkbox does. Call it from on_key_event while the
// application routes keys to the checkbox.
pub fn styled_checkbox_checked_after_key(config StyledCheckboxConfig, event KeyEvent) ?bool {
	if !config.enabled || !controls_enter_or_space(event) {
		return none
	}
	return config.indeterminate || !config.checked
}

// ── Checkbox group ──────────────────────────────────────────────────

pub struct CheckboxOption {
pub:
	value       string // Stable key returned by the decoder; defaults to label.
	label       string
	description string
	enabled     bool = true
}

pub struct CheckboxGroupConfig {
pub:
	id          string
	frame       Rect
	options     []CheckboxOption
	selected    []string // Values of the checked options.
	orientation LayoutOrientation = .vertical
	// select_all, when not empty, is the label of a parent checkbox shown first:
	// checked when every enabled option is, indeterminate when only some are,
	// and toggling every enabled option at once. In a vertical group the
	// options are indented under it.
	select_all          string
	enabled             bool = true
	accessibility_label string // Names the group for assistive technology; not drawn.
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub fn checkbox_group_action_id(id string, value string) string {
	return component_part_id(id, choice_item_part('option:', value))
}

// checkbox_group_select_all_action_id is the action of the select-all checkbox.
pub fn checkbox_group_select_all_action_id(id string) string {
	return component_part_id(id, 'all')
}

fn checkbox_group_values(options []CheckboxOption) []string {
	return options.map(choice_value(it.value, it.label))
}

// checkbox_group_all_state is the select-all checkbox's state: checked when
// every enabled option is selected, indeterminate when some selected value is
// one of the options but not all enabled ones are.
fn checkbox_group_all_state(config CheckboxGroupConfig) (bool, bool) {
	values := checkbox_group_values(config.options)
	mut enabled_count := 0
	mut enabled_selected := 0
	mut any_selected := false
	for index, value in values {
		chosen := value in config.selected
		if chosen {
			any_selected = true
		}
		if config.options[index].enabled {
			enabled_count++
			if chosen {
				enabled_selected++
			}
		}
	}
	all := enabled_count > 0 && enabled_selected == enabled_count
	return all, any_selected && !all
}

// checkbox_group_frames places the select-all row (when shown) and then the
// options: one under another, indented under select-all, or left to right
// wrapping onto new rows. Rows are squeezed to fit a frame that is too short.
fn checkbox_group_frames(config CheckboxGroupConfig) []Rect {
	cm := checkbox_metrics(config.size)
	width := config.frame.width
	spacing := component_metrics(config.size).padding
	mut frames := []Rect{}
	mut y := 0.0
	if config.select_all.len > 0 {
		h := checkbox_row(StyledCheckboxConfig{
			label: config.select_all
			size:  config.size
		}, width).height + spacing
		frames << rect(0, 0, width, h)
		y = h
	}
	if config.orientation == .vertical {
		indent := if config.select_all.len > 0 { cm.box + cm.gap } else { 0.0 }
		for option in config.options {
			h := checkbox_row(StyledCheckboxConfig{
				label:       option.label
				description: option.description
				size:        config.size
			}, width - indent).height + spacing
			frames << rect(indent, y, math.max(0.0, width - indent), h)
			y += h
		}
	} else {
		mut x := 0.0
		mut row_h := 0.0
		for option in config.options {
			item := StyledCheckboxConfig{
				label:       option.label
				description: option.description
				size:        config.size
			}
			natural := math.min(width, styled_checkbox_width(item) + spacing * 2)
			h := checkbox_row(item, natural).height + spacing
			if x > 0 && x + natural > width {
				x = 0
				y += row_h
				row_h = 0
			}
			frames << rect(x, y, natural, h)
			x += natural
			row_h = math.max(row_h, h)
		}
		y += row_h
	}
	if y > config.frame.height && y > 0 {
		scale := config.frame.height / y
		for i, frame in frames {
			frames[i] = rect(frame.x, frame.y * scale, frame.width, frame.height * scale)
		}
	}
	return frames
}

// checkbox_group_height is how tall a group's frame must be to show every
// option at its frame's width.
pub fn checkbox_group_height(config CheckboxGroupConfig) f64 {
	frames := checkbox_group_frames(CheckboxGroupConfig{
		...config
		frame: rect(config.frame.x, config.frame.y, config.frame.width, 1e9)
	})
	mut bottom := 0.0
	for frame in frames {
		bottom = math.max(bottom, frame.y + frame.height)
	}
	return bottom
}

// checkbox_group shows a set of independent options, like GPUI Kit's checkbox
// lists. It is controlled: decode an action with
// checkbox_group_selection_from_action and rebuild with the returned values.
pub fn checkbox_group(config CheckboxGroupConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	values := checkbox_group_values(config.options)
	choice_validate_values(values, 'checkbox group')!
	frames := checkbox_group_frames(config)
	mut children := []Element{cap: frames.len}
	mut index := 0
	if config.select_all.len > 0 {
		all, some := checkbox_group_all_state(config)
		has_enabled := config.options.any(it.enabled)
		children << Element{
			...styled_checkbox_element(StyledCheckboxConfig{
				id:            checkbox_group_select_all_action_id(config.id)
				label:         config.select_all
				checked:       all
				indeterminate: some
				enabled:       config.enabled && has_enabled
				size:          config.size
				theme:         config.theme
			}, frames[0])
			key: 'all'
		}
		index = 1
	}
	mut selected_labels := []string{}
	for i, option in config.options {
		checked := values[i] in config.selected
		if checked {
			selected_labels << option.label
		}
		children << Element{
			...styled_checkbox_element(StyledCheckboxConfig{
				id:          checkbox_group_action_id(config.id, values[i])
				label:       option.label
				description: option.description
				checked:     checked
				enabled:     config.enabled && option.enabled
				size:        config.size
				theme:       config.theme
			}, frames[index + i])
			key: 'option:' + values[i]
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
		accessibility_value: selected_labels.join(', ')
	})
}

// checkbox_group_selection_from_action returns the selected values after an
// action, in option order: an option's action toggles it, and the select-all
// action selects every enabled option, or clears them when all are selected
// (disabled options keep their state). None for foreign or forged actions and
// for disabled groups and options.
pub fn checkbox_group_selection_from_action(config CheckboxGroupConfig, action string) ?[]string {
	if !config.enabled {
		return none
	}
	values := checkbox_group_values(config.options)
	mut chosen := map[string]bool{}
	for value in config.selected {
		if value in values {
			chosen[value] = true
		}
	}
	if config.select_all.len > 0 && action == checkbox_group_select_all_action_id(config.id) {
		all, _ := checkbox_group_all_state(config)
		mut changed := false
		for i, value in values {
			if config.options[i].enabled {
				changed = true
				if all {
					chosen.delete(value)
				} else {
					chosen[value] = true
				}
			}
		}
		if !changed {
			return none
		}
	} else {
		index := choice_item_index(config.id, 'option:', values, action) or { return none }
		if !config.options[index].enabled {
			return none
		}
		if values[index] in chosen {
			chosen.delete(values[index])
		} else {
			chosen[values[index]] = true
		}
	}
	return values.filter(it in chosen)
}
