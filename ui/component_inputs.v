module ui2

import math

// Text-entry components: input_group here, number_input in
// component_inputs_number.v and otp_input in component_inputs_otp.v.
//
// Each is built around a native text field, and a native field draws its own
// frame: AppKit gives it a bezel, the custom renderer an outline. No backend
// lets an element turn that frame off, so the components do not try to hide a
// field inside a borderless box. The field spans the full height of the
// component and keeps its frame, which then reads as the divider between the
// field and the addons or buttons beside it, while the component's own border
// and corner radius go round the whole row.

// inputs_field_box is the box a component gives its native field: the
// field's background and a one-pixel border in the theme's border color, or
// its danger color while the content is invalid. The radius stays zero. On
// AppKit a corner radius masks the field's layer, which would clip its focus
// ring as well; the component's outer corners are rounded by its own frame.
fn inputs_field_box(theme ComponentTheme, invalid bool) BoxStyle {
	return component_box(theme.background, if invalid { theme.danger } else { theme.border },
		0)
}

fn inputs_frame_box(theme ComponentTheme, invalid bool, radius f64) BoxStyle {
	return component_box(theme.muted, if invalid { theme.danger } else { theme.border },
		radius)
}

struct InputsFieldSpec {
	id          string
	submit_id   string
	placeholder string
	text        string
	frame       Rect
	font_size   f64
	align       Align
	padding     f64  = 12
	enabled     bool = true
	readonly    bool
	secure      bool
	invalid     bool
	autocorrect bool = true
	keyboard    int
	role        string
	label       string
	key         string
	// A standalone field keeps the backend's own frame (AppKit's bezel, the
	// custom renderer's outline and focus ring) with this corner radius until it
	// is invalid. Fields inside a component frame always get the theme border,
	// which reads as the divider between the field and its neighbours.
	standalone_radius f64
	theme             ComponentTheme
}

// inputs_field is the change-emitting native text field the input
// components share. Its id is also its action, so an application reads the
// edited text with text(id) when that id arrives.
fn inputs_field(spec InputsFieldSpec) Element {
	box := if spec.standalone_radius > 0 && !spec.invalid {
		BoxStyle{
			bg:     spec.theme.background
			radius: spec.standalone_radius
		}
	} else {
		inputs_field_box(spec.theme, spec.invalid)
	}
	field := text_field_with_change_and_submit(spec.id, spec.submit_id, spec.placeholder,
		spec.text, spec.frame, box, TextStyle{
			color: if spec.enabled { spec.theme.foreground } else { spec.theme.muted_foreground }
			size:  spec.font_size
			align: spec.align
		}, spec.keyboard)
	return Element{
		...field
		key:                 spec.key
		enabled:             spec.enabled
		readonly:            spec.readonly
		secure:              spec.secure
		autocorrect:         spec.autocorrect
		padding_left:        spec.padding
		accessibility_role:  spec.role
		accessibility_label: spec.label
	}
}

// inputs_symbol is a `symbol:` image tinted with color, which every
// renderer draws as the same icon for names symbol_known accepts.
fn inputs_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

// inputs_centered_square is a size-by-size square centered in frame,
// shrunk to fit when frame is smaller.
fn inputs_centered_square(frame Rect, size f64) Rect {
	side := math.max(math.min(size, math.min(frame.width, frame.height)), 0)
	return rect(frame.x + (frame.width - side) / 2, frame.y + (frame.height - side) / 2,
		side, side)
}

// inputs_icon_size is the side of an icon drawn beside text of a size.
fn inputs_icon_size(metrics ComponentMetrics) f64 {
	return metrics.font_size + 2
}

pub enum InputGroupAddonKind {
	text   // Muted text such as a unit, protocol or domain.
	icon   // A `symbol:` icon such as magnifyingglass or lock.
	button // An action with a title, an icon, or both.
}

pub enum InputGroupSide {
	leading
	trailing
}

// InputGroupAddon is one part beside the field. Addons on the same side keep
// the order they are listed in.
pub struct InputGroupAddon {
pub:
	id                  string // Stable key, unique within the group; names a button's action.
	kind                InputGroupAddonKind
	side                InputGroupSide
	text                string // Text addon content or button title.
	icon                string // Symbol name (see symbol_known) for icon addons and buttons.
	enabled             bool = true
	primary             bool // Button: a solid primary fill instead of a ghost button.
	tooltip             string
	accessibility_label string // Required wording for icon-only buttons; defaults to text.
}

pub struct InputGroupConfig {
pub:
	id                  string
	frame               Rect
	text                string // Controlled: the application stores edits and rebuilds.
	placeholder         string
	addons              []InputGroupAddon
	clearable           bool // Show a clear button while there is text to clear.
	enabled             bool = true
	readonly            bool // Selectable but not editable; addon buttons still work.
	invalid             bool // Draw the danger border; edits are still accepted.
	secure              bool // Native password entry.
	keyboard            int
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub enum InputGroupEventKind {
	change // The text changed: read it with text(input_group_field_id(id)).
	submit // Return was pressed in the field.
	clear  // The clear button was pressed: store '' and focus the field.
	addon  // An addon button was pressed; the event's addon holds its id.
}

pub struct InputGroupEvent {
pub:
	kind  InputGroupEventKind
	addon string
}

// input_group_field_id is the id of the group's native field, for text(),
// set_text() and focus(). It is also the action the field emits on each edit.
pub fn input_group_field_id(id string) string {
	return component_part_id(id, 'field')
}

fn input_group_addon_part(addon_id string) string {
	return 'addon:' + addon_id.bytes().hex()
}

fn input_group_shows_clear(config InputGroupConfig) bool {
	return config.clearable && config.enabled && !config.readonly && config.text.len > 0
}

// input_group_event decodes an action the group emitted against the
// application's current configuration. It rejects foreign and forged actions,
// every action while the group is disabled, edits of a read-only field, a clear
// with nothing to clear, and presses of disabled, missing or non-button addons.
pub fn input_group_event(config InputGroupConfig, action string) ?InputGroupEvent {
	part := component_action_part(config.id, action) or { return none }
	if !config.enabled {
		return none
	}
	match part {
		'field' {
			if config.readonly {
				return none
			}
			return InputGroupEvent{
				kind: .change
			}
		}
		'submit' {
			return InputGroupEvent{
				kind: .submit
			}
		}
		'clear' {
			if !input_group_shows_clear(config) {
				return none
			}
			return InputGroupEvent{
				kind: .clear
			}
		}
		else {}
	}
	if !part.starts_with('addon:') {
		return none
	}
	for addon in config.addons {
		if addon.kind == .button && input_group_addon_part(addon.id) == part {
			if !addon.enabled {
				return none
			}
			return InputGroupEvent{
				kind:  .addon
				addon: addon.id
			}
		}
	}
	return none
}

fn input_group_validate(config InputGroupConfig) ! {
	mut ids := map[string]bool{}
	for addon in config.addons {
		if addon.id.trim_space().len == 0 || addon.id in ids {
			return error('input group addon ids must be non-empty and unique')
		}
		ids[addon.id] = true
		match addon.kind {
			.text {
				if addon.text.len == 0 {
					return error('input group text addon `${addon.id}` has no text')
				}
			}
			.icon {
				if addon.icon.len == 0 {
					return error('input group icon addon `${addon.id}` has no icon')
				}
			}
			.button {
				if addon.text.len == 0 && addon.icon.len == 0 {
					return error('input group button `${addon.id}` needs a title or an icon')
				}
				if addon.text.len == 0 && addon.accessibility_label.trim_space().len == 0 {
					return error('input group icon button `${addon.id}` needs an accessibility label')
				}
			}
		}
		if addon.icon.len > 0 && !symbol_known(addon.icon) {
			return error('input group addon `${addon.id}` uses `${addon.icon}`, which not every renderer can draw; pick a name from symbol_names()')
		}
	}
}

// input_group_addon_width is the room an addon asks for: a square for an icon
// or an icon-only button, an estimate of its text plus padding otherwise.
fn input_group_addon_width(addon InputGroupAddon, height f64, metrics ComponentMetrics) f64 {
	if addon.kind == .icon || (addon.kind == .button && addon.text.len == 0) {
		return height
	}
	mut width := component_text_width_estimate(addon.text, metrics.font_size) +
		2 * metrics.padding
	if addon.kind == .button {
		// Button titles get some slack over the estimate, more for a bold
		// primary title, because a title that does not fit is cut short.
		width += metrics.padding / 2 + if addon.primary {
			component_text_width_estimate(addon.text, metrics.font_size) * 0.08
		} else {
			0.0
		}
		if addon.icon.len > 0 {
			width += inputs_icon_size(metrics) + metrics.gap
		}
	}
	return width
}

struct InputGroupLayout {
	leading  []Rect // In the order the leading addons are listed.
	trailing []Rect // In the order the trailing addons are listed.
	field    Rect
	clear    Rect // Empty while the clear button is hidden.
}

// input_group_layout packs leading addons from the left edge and trailing ones
// against the right edge, and gives the field the rest. When the addons would
// leave the field less than two control heights, they all shrink evenly. The
// clear button sits inside the right end of the field, one pixel in from its
// border, so showing it does not move the field's edges while typing.
fn input_group_layout(config InputGroupConfig) InputGroupLayout {
	metrics := component_metrics(config.size)
	width := config.frame.width
	height := config.frame.height
	mut wanted := []f64{cap: config.addons.len}
	mut total := 0.0
	for addon in config.addons {
		w := input_group_addon_width(addon, height, metrics)
		wanted << w
		total += w
	}
	room := math.max(width - math.min(width, 2 * metrics.height), 0)
	scale := if total > room && total > 0 { room / total } else { 1.0 }
	mut leading := []Rect{}
	mut trailing := []Rect{}
	mut leading_width := 0.0
	mut trailing_width := 0.0
	for index, addon in config.addons {
		if addon.side == .leading {
			leading_width += wanted[index] * scale
		} else {
			trailing_width += wanted[index] * scale
		}
	}
	mut left := 0.0
	mut right := width - trailing_width
	for index, addon in config.addons {
		w := wanted[index] * scale
		if addon.side == .leading {
			leading << rect(left, 0, w, height)
			left += w
		} else {
			trailing << rect(right, 0, w, height)
			right += w
		}
	}
	field := rect(leading_width, 0, math.max(width - leading_width - trailing_width, 0),
		height)
	mut clear := Rect{}
	if input_group_shows_clear(config) && field.width > 2 && field.height > 2 {
		side := math.min(field.height - 2, field.width / 2)
		clear = rect(field.x + field.width - 1 - side, 1, side, field.height - 2)
	}
	return InputGroupLayout{
		leading:  leading
		trailing: trailing
		field:    field
		clear:    clear
	}
}

fn input_group_addon(config InputGroupConfig, addon InputGroupAddon, frame Rect) Element {
	theme := config.theme
	metrics := component_metrics(config.size)
	enabled := config.enabled && addon.enabled
	part := component_part_id(config.id, input_group_addon_part(addon.id))
	icon_size := inputs_icon_size(metrics)
	local := component_local(frame)
	description := if addon.accessibility_label.len > 0 {
		addon.accessibility_label
	} else {
		addon.text
	}
	if addon.kind != .button {
		content := if addon.kind == .text {
			label('', addon.text, local, TextStyle{
				color: theme.muted_foreground
				size:  metrics.font_size
				align: .center
			})
		} else {
			inputs_symbol(addon.icon, inputs_centered_square(local, icon_size),
				theme.muted_foreground)
		}
		return Element{
			...view('', frame, BoxStyle{ transparent: true }, [content])
			key:                 'addon:' + addon.id
			tooltip:             addon.tooltip
			accessibility_role:  if addon.kind == .text { 'text' } else { 'img' }
			accessibility_label: description
		}
	}
	// A primary button is a filled pill inset from the frame; a ghost button
	// fills its slot so the whole addon is the target.
	inset := if addon.primary { math.min(3.0, frame.height / 4) } else { 0.0 }
	body := rect(frame.x + inset, frame.y + inset, math.max(frame.width - 2 * inset, 0),
		math.max(frame.height - 2 * inset, 0))
	inner := component_local(body)
	color := if !enabled {
		theme.muted_foreground
	} else if addon.primary {
		theme.primary_foreground
	} else {
		theme.primary
	}
	style := TextStyle{
		color: color
		size:  metrics.font_size
		bold:  addon.primary
		align: .center
	}
	mut children := []Element{}
	if addon.text.len == 0 {
		children << inputs_symbol(addon.icon, inputs_centered_square(inner, icon_size),
			color)
	} else if addon.icon.len == 0 {
		children << label('', addon.text, inner, style)
	} else {
		pad := math.min(metrics.padding, inner.width / 4)
		icon_frame := inputs_centered_square(rect(pad, 0, icon_size, inner.height),
			icon_size)
		text_x := pad + icon_size + metrics.gap
		children << inputs_symbol(addon.icon, icon_frame, color)
		children << label('', addon.text, rect(text_x, 0, math.max(inner.width - text_x - pad / 2,
			0), inner.height), TextStyle{
			...style
			align: .left
		})
	}
	box := if addon.primary {
		BoxStyle{
			bg:     if enabled { theme.primary } else { theme.border }
			radius: math.max(metrics.radius - inset, 0)
		}
	} else {
		BoxStyle{
			transparent: true
		}
	}
	return Element{
		...button_view(part, body, box, children)
		key:                 'addon:' + addon.id
		enabled:             enabled
		tooltip:             addon.tooltip
		accessibility_label: description
	}
}

// input_group places a native text field between leading and trailing addons
// inside one frame with a shared border and corner radius. The application
// owns the text: store it on every change event and rebuild. Text and icon
// addons are decoration; buttons and the clear button emit actions that
// input_group_event decodes.
pub fn input_group(config InputGroupConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	input_group_validate(config)!
	metrics := component_metrics(config.size)
	theme := config.theme
	layout := input_group_layout(config)
	mut children := []Element{}
	mut leading_index := 0
	for addon in config.addons {
		if addon.side == .leading {
			children << input_group_addon(config, addon, layout.leading[leading_index])
			leading_index++
		}
	}
	description := if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else {
		config.placeholder
	}
	children << inputs_field(
		id:          input_group_field_id(config.id)
		submit_id:   component_part_id(config.id, 'submit')
		placeholder: config.placeholder
		text:        config.text
		frame:       layout.field
		font_size:   metrics.font_size
		enabled:     config.enabled
		readonly:    config.readonly
		secure:      config.secure
		invalid:     config.invalid
		keyboard:    config.keyboard
		label:       description
		key:         'field'
		theme:       theme
	)
	if layout.clear.width > 0 {
		children << Element{
			...button_view(component_part_id(config.id, 'clear'), layout.clear, BoxStyle{
				bg: theme.background
			}, [
				inputs_symbol('xmark', inputs_centered_square(component_local(layout.clear),
					metrics.font_size - 2), theme.muted_foreground),
			])
			key:                 'clear'
			tooltip:             'Clear'
			accessibility_label: 'Clear'
		}
	}
	mut trailing_index := 0
	for addon in config.addons {
		if addon.side == .trailing {
			children << input_group_addon(config, addon, layout.trailing[trailing_index])
			trailing_index++
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, inputs_frame_box(theme, config.invalid, metrics.radius),
			children)
		accessibility_role:  'group'
		accessibility_label: description
	})
}
