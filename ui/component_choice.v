module ui2

import math

// Choice components: radio, rating, toggle, button group and stepper. This file
// holds what they share (colors, rounded segments, item identity) plus the
// button and toggle families; the others live in component_choice_*.v.
//
// Every interactive part is a view with button behavior rather than a native
// button, so the component decides every color itself: a native button dims its
// title when disabled and centers a single line, and neither suits a segment
// that is selected, an icon beside a caption, or a star.

// ── Colors ──────────────────────────────────────────────────────────

// choice_mix blends two 0xRRGGBB colors; t = 0 is a, t = 1 is b.
fn choice_mix(a u32, b u32, t f64) u32 {
	amount := math.max(0.0, math.min(1.0, t))
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		from := f64((a >> shift) & 0xff)
		to := f64((b >> shift) & 0xff)
		out |= u32(math.round(from + (to - from) * amount)) << shift
	}
	return out
}

fn choice_luminance(color u32) f64 {
	weights := [0.2126, 0.7152, 0.0722]
	mut sum := 0.0
	for i, shift in [u32(16), 8, 0] {
		channel := f64((color >> shift) & 0xff) / 255.0
		linear := if channel <= 0.03928 {
			channel / 12.92
		} else {
			math.pow((channel + 0.055) / 1.055, 2.4)
		}
		sum += weights[i] * linear
	}
	return sum
}

// choice_contrast is the WCAG contrast ratio of two colors, from 1 to 21.
fn choice_contrast(a u32, b u32) f64 {
	la := choice_luminance(a)
	lb := choice_luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
}

// choice_legible moves color toward `toward` (normally the theme foreground)
// until it reads at 4.5:1 on bg. Tone colors such as the warning yellow are
// fills, and need darkening before they can be text on a light background.
fn choice_legible(color u32, bg u32, toward u32) u32 {
	for i in 0 .. 11 {
		candidate := choice_mix(color, toward, f64(i) / 10)
		if choice_contrast(candidate, bg) >= 4.5 {
			return candidate
		}
	}
	return toward
}

// choice_disabled_text is the dimmed text shared by every disabled choice.
fn choice_disabled_text(theme ComponentTheme) u32 {
	return choice_mix(theme.muted_foreground, theme.background, 0.35)
}

// choice_pressed is the neutral fill of a pressed toggle or a selected ghost
// button: darker than `muted`, which barely differs from the background.
fn choice_pressed(theme ComponentTheme) u32 {
	return choice_mix(theme.muted, theme.border, 0.7)
}

// ── Geometry ────────────────────────────────────────────────────────

// choice_line_height is the height a line of text at `size` points takes on
// the platform the code runs on (points are larger on Windows and Linux).
fn choice_line_height(size f64) f64 {
	return font_line_height(size)
}

fn choice_text_width(caption string, size f64) f64 {
	return component_text_width_estimate(caption, font_em_pixels(size))
}

// choice_fit keeps a child frame inside a parent of the given size, so tiny
// or squeezed frames never produce children outside their parent.
fn choice_fit(frame Rect, width f64, height f64) Rect {
	x := math.max(0.0, math.min(frame.x, width))
	y := math.max(0.0, math.min(frame.y, height))
	return rect(x, y, math.max(0.0, math.min(frame.width, width - x)), math.max(0.0, math.min(frame.height,
		height - y)))
}

enum ChoiceCorners {
	all
	none
	start // left corners, or top corners when vertical
	end   // right corners, or bottom corners when vertical
}

// choice_shape fills frame with only the named corners rounded. BoxStyle has
// one radius for all corners, so a rounded view gets a square patch over the
// half whose corners must stay square. Overlapping views of one color show no
// seam on either renderer.
fn choice_shape(frame Rect, radius f64, color u32, corners ChoiceCorners, vertical bool) []Element {
	if frame.width <= 0 || frame.height <= 0 {
		return []Element{}
	}
	r := math.max(0.0, math.min(radius, math.min(frame.width, frame.height) / 2))
	if corners == .none || r == 0 {
		return [view('', frame, BoxStyle{ bg: color }, []Element{})]
	}
	mut shapes := [view('', frame, BoxStyle{ bg: color, radius: r }, []Element{})]
	if corners == .all {
		return shapes
	}
	half_w := frame.width / 2
	half_h := frame.height / 2
	patch := if vertical && corners == .start {
		rect(frame.x, frame.y + half_h, frame.width, frame.height - half_h)
	} else if vertical {
		rect(frame.x, frame.y, frame.width, half_h)
	} else if corners == .start {
		rect(frame.x + half_w, frame.y, frame.width - half_w, frame.height)
	} else {
		rect(frame.x, frame.y, half_w, frame.height)
	}
	shapes << view('', patch, BoxStyle{ bg: color }, []Element{})
	return shapes
}

// choice_ring draws a bordered rounded shape as two fills, the border color
// under an inset fill. A BoxStyle border is square-cornered in the custom
// renderer and clipped at the corners by AppKit, so this keeps both alike.
fn choice_ring(frame Rect, radius f64, border u32, fill u32, corners ChoiceCorners, vertical bool) []Element {
	mut shapes := choice_shape(frame, radius, border, corners, vertical)
	inner := rect(frame.x + 1, frame.y + 1, math.max(0.0, frame.width - 2), math.max(0.0,
		frame.height - 2))
	shapes << choice_shape(inner, radius - 1, fill, corners, vertical)
	return shapes
}

// ── Item identity ───────────────────────────────────────────────────

// choice_value is an item's stable key: its value, or its label when no value
// was given, so `RadioOption{ label: 'Light' }` needs nothing more.
fn choice_value(value string, fallback string) string {
	return if value.len > 0 { value } else { fallback }
}

fn choice_validate_values(values []string, component string) ! {
	mut seen := map[string]bool{}
	for value in values {
		if value.trim_space().len == 0 || value in seen {
			return error('${component} values must be non-empty and unique')
		}
		seen[value] = true
	}
}

// choice_item_part names an item in its element id and action. The value is
// hex-encoded, so any string is a valid id and the identity follows the item
// when the list is reordered.
fn choice_item_part(prefix string, value string) string {
	return prefix + value.bytes().hex()
}

// choice_item_index finds the item whose part an action names. Only parts the
// component could have emitted match, so a forged action finds nothing.
fn choice_item_index(id string, prefix string, values []string, action string) ?int {
	part := component_action_part(id, action) or { return none }
	if !part.starts_with(prefix) {
		return none
	}
	for index, value in values {
		if part == choice_item_part(prefix, value) {
			return index
		}
	}
	return none
}

// choice_icon draws a `symbol:` image tinted like the text beside it. Use
// names symbol_known accepts so every renderer draws the same icon.
fn choice_icon(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

fn choice_icon_size(metrics ComponentMetrics) f64 {
	return math.round(metrics.font_size * 1.15)
}

// choice_content_width estimates an icon plus caption laid out side by side.
fn choice_content_width(caption string, icon string, metrics ComponentMetrics) f64 {
	mut width := if caption.len > 0 { choice_text_width(caption, metrics.font_size) } else { 0.0 }
	if icon.len > 0 {
		width += choice_icon_size(metrics) + if caption.len > 0 { metrics.gap } else { 0.0 }
	}
	return width
}

// ── Button variants ─────────────────────────────────────────────────

// ButtonVariant follows GPUI Kit's button variants that ComponentTheme has
// colors for. `outline` is a separate flag, combinable with any of them.
pub enum ButtonVariant {
	secondary // Muted fill with a border; the default, as upstream.
	primary
	danger
	success
	warning
	ghost // No fill or border until selected.
}

pub struct ButtonVariantColors {
pub:
	fill       u32
	foreground u32
	border     u32  // The ring around the button.
	divider    u32  // Between attached buttons.
	filled     bool // False leaves the parent's background showing.
	bordered   bool
}

// button_variant_colors resolves a variant against a theme. Use it to color
// other controls so they match the buttons beside them.
pub fn button_variant_colors(theme ComponentTheme, variant ButtonVariant, outline bool, selected bool, enabled bool) ButtonVariantColors {
	if variant == .ghost {
		pressed := choice_pressed(theme)
		fill := if enabled { pressed } else { choice_mix(pressed, theme.background, 0.5) }
		return ButtonVariantColors{
			fill:       fill
			foreground: if enabled { theme.foreground } else { choice_disabled_text(theme) }
			border:     theme.border
			divider:    theme.border
			filled:     selected
			bordered:   false
		}
	}
	tone, tone_foreground := match variant {
		.primary { theme.primary, theme.primary_foreground }
		.danger { theme.danger, theme.danger_foreground }
		.success { theme.success, theme.success_foreground }
		.warning { theme.warning, theme.warning_foreground }
		else { theme.muted, theme.foreground }
	}
	neutral := variant == .secondary
	mut fill := tone
	mut foreground := tone_foreground
	mut border := if neutral { theme.border } else { tone }
	mut divider := if neutral { theme.border } else { choice_mix(tone, tone_foreground, 0.35) }
	if outline {
		fill = if !selected {
			theme.background
		} else if neutral {
			choice_pressed(theme)
		} else {
			choice_mix(theme.background, tone, 0.16)
		}
		foreground = if neutral {
			theme.foreground
		} else {
			choice_legible(tone, fill, theme.foreground)
		}
		divider = border
	} else if selected {
		fill = if neutral {
			choice_pressed(theme)
		} else {
			choice_mix(tone, theme.foreground, 0.25)
		}
		if !neutral {
			border = fill
		}
	}
	if !enabled {
		fill = choice_mix(fill, theme.background, 0.6)
		border = choice_mix(border, theme.background, 0.5)
		divider = choice_mix(divider, theme.background, 0.5)
		foreground = choice_disabled_text(theme)
	}
	return ButtonVariantColors{
		fill:       fill
		foreground: foreground
		border:     border
		divider:    divider
		filled:     true
		bordered:   true
	}
}

// choice_button_padding is the space on each side of a button caption.
fn choice_button_padding(metrics ComponentMetrics) f64 {
	return metrics.padding * 1.5
}

// styled_button_width estimates how wide a styled button, toggle or group
// segment wants to be for its caption, so an application can size frames.
// An icon-only button is square.
pub fn styled_button_width(caption string, icon string, size ComponentSize) f64 {
	metrics := component_metrics(size)
	if caption.len == 0 {
		return metrics.height
	}
	return math.max(metrics.height, choice_content_width(caption, icon, metrics) +
		2 * choice_button_padding(metrics))
}

// A segment is one clickable part of a button, toggle or group.
struct ChoiceSegment {
	frame   Rect
	id      string
	key     string
	action  string
	text    string
	icon    string // A symbol name drawn before the text.
	colors  ButtonVariantColors
	enabled bool
	role    string = 'button'
	label   string
	value   string
}

// choice_segment_content centers the caption, or an icon followed by the
// caption. A caption beside an icon is left-aligned after it, since only its
// estimated width is known; the pair is centered on that estimate.
fn choice_segment_content(segment ChoiceSegment, metrics ComponentMetrics) []Element {
	local := component_local(segment.frame)
	pad := math.min(choice_button_padding(metrics) / 2, local.width / 2)
	style := TextStyle{
		color: segment.colors.foreground
		size:  metrics.font_size
		align: .center
	}
	if segment.icon.len == 0 {
		return [label('', segment.text, rect(pad, 0, local.width - 2 * pad, local.height), style)]
	}
	icon_size := math.min(choice_icon_size(metrics), math.min(local.width, local.height))
	icon_y := (local.height - icon_size) / 2
	if segment.text.len == 0 {
		return [choice_icon(segment.icon, rect((local.width - icon_size) / 2, icon_y, icon_size,
			icon_size), segment.colors.foreground)]
	}
	content := choice_content_width(segment.text, segment.icon, metrics)
	x := math.max(pad, (local.width - content) / 2)
	icon_x := math.min(x, local.width - icon_size)
	text_x := math.min(icon_x + icon_size + metrics.gap, local.width)
	return [
		choice_icon(segment.icon, rect(icon_x, icon_y, icon_size, icon_size), segment.colors.foreground),
		label('', segment.text, rect(text_x, 0, math.max(0.0, local.width - text_x - pad / 2),
			local.height), TextStyle{
			...style
			align: .left
		}),
	]
}

fn choice_segment_element(segment ChoiceSegment, decoration []Element, metrics ComponentMetrics) Element {
	mut children := decoration.clone()
	children << choice_segment_content(segment, metrics)
	return Element{
		...button_view(segment.id, segment.frame, BoxStyle{ transparent: true }, children)
		key:                 segment.key
		action_id:           segment.action
		enabled:             segment.enabled
		accessibility_role:  segment.role
		accessibility_label: segment.label
		accessibility_value: segment.value
	}
}

// choice_free_segment is a button standing on its own: every corner rounded.
fn choice_free_segment(segment ChoiceSegment, metrics ComponentMetrics) Element {
	local := component_local(segment.frame)
	colors := segment.colors
	decoration := if colors.bordered {
		choice_ring(local, metrics.radius, colors.border, colors.fill, .all, false)
	} else if colors.filled {
		choice_shape(local, metrics.radius, colors.fill, .all, false)
	} else {
		[]Element{}
	}
	return choice_segment_element(segment, decoration, metrics)
}

// choice_attached_segments joins segments into one control. The group's
// border color goes under everything, each segment's fill is inset by one
// unit at the group's edge and leaves a one-unit gap before the next, and
// only the outer corners are rounded. Between solid buttons the gaps take a
// divider color so attached primary buttons stay distinguishable.
fn choice_attached_segments(segments []ChoiceSegment, group ButtonVariantColors, vertical bool, metrics ComponentMetrics) []Element {
	if segments.len == 0 {
		return []Element{}
	}
	first := segments[0].frame
	last := segments[segments.len - 1].frame
	outer := rect(first.x, first.y, last.x + last.width - first.x, last.y + last.height - first.y)
	edge := if group.bordered { 1.0 } else { 0.0 }
	mut children := []Element{}
	if group.bordered {
		children << choice_shape(outer, metrics.radius, group.border, .all, vertical)
		if group.divider != group.border {
			for segment in segments[1..] {
				children << view('', if vertical {
					rect(outer.x + edge, segment.frame.y, math.max(0.0, outer.width - 2 * edge),
						edge)
				} else {
					rect(segment.frame.x, outer.y + edge, edge, math.max(0.0, outer.height - 2 * edge))
				}, BoxStyle{ bg: group.divider }, []Element{})
			}
		}
	}
	for index, segment in segments {
		is_first := index == 0
		is_last := index == segments.len - 1
		local := component_local(segment.frame)
		// The first segment's leading edge is the group border; every later
		// segment's is the gap before it.
		lead := edge
		trail := if is_last { edge } else { 0.0 }
		fill := if vertical {
			rect(edge, lead, math.max(0.0, local.width - 2 * edge), math.max(0.0, local.height - lead - trail))
		} else {
			rect(lead, edge, math.max(0.0, local.width - lead - trail), math.max(0.0, local.height - 2 * edge))
		}
		corners := if is_first && is_last {
			ChoiceCorners.all
		} else if is_first {
			ChoiceCorners.start
		} else if is_last {
			ChoiceCorners.end
		} else {
			ChoiceCorners.none
		}
		decoration := if segment.colors.filled {
			choice_shape(fill, metrics.radius - edge, segment.colors.fill, corners, vertical)
		} else {
			[]Element{}
		}
		children << choice_segment_element(segment, decoration, metrics)
	}
	return children
}

// choice_pack sizes items from their natural extents. They keep those sizes
// and pack from the start unless they need more room than there is or fill is
// set, in which case they are scaled to the available extent.
fn choice_pack(naturals []f64, available f64, gap f64, fill bool) ([]f64, f64) {
	if naturals.len == 0 {
		return []f64{}, 0.0
	}
	space := math.max(available, 0.0)
	gaps := math.min(gap * f64(naturals.len - 1), space / 2)
	used_gap := if naturals.len > 1 { gaps / f64(naturals.len - 1) } else { 0.0 }
	mut total := 0.0
	for natural in naturals {
		total += natural
	}
	room := space - gaps
	scale := if total > 0 && (fill || total > room) { room / total } else { 1.0 }
	mut sizes := []f64{cap: naturals.len}
	for natural in naturals {
		sizes << natural * scale
	}
	return sizes, used_gap
}

// choice_row_frames lays item extents along a row (or column) of the frame.
fn choice_row_frames(sizes []f64, gap f64, frame Rect, cross f64, vertical bool) []Rect {
	mut frames := []Rect{cap: sizes.len}
	mut offset := 0.0
	for size in sizes {
		frames << if vertical {
			rect(0, offset, cross, size)
		} else {
			rect(offset, (frame.height - cross) / 2, size, cross)
		}
		offset += size + gap
	}
	return frames
}

// ── Styled button ───────────────────────────────────────────────────

pub struct StyledButtonConfig {
pub:
	id                  string
	frame               Rect
	label               string
	icon                string // Symbol name drawn before the label; see symbol_known.
	action_id           string // Defaults to id.
	variant             ButtonVariant
	outline             bool
	selected            bool
	enabled             bool = true
	accessibility_label string // Defaults to label; set it for icon-only buttons.
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// styled_button is a button in one of GPUI Kit's variants. ui2's `button`
// can take any solid color, but its border is square-cornered in the custom
// renderer, so outline buttons need this composite to look alike everywhere.
pub fn styled_button(config StyledButtonConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	metrics := component_metrics(config.size)
	segment := ChoiceSegment{
		frame:   config.frame
		id:      config.id
		action:  if config.action_id.len > 0 { config.action_id } else { config.id }
		text:    config.label
		icon:    config.icon
		colors:  button_variant_colors(config.theme, config.variant, config.outline, config.selected,
			config.enabled)
		enabled: config.enabled
		label:   if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			config.label
		}
		value:   if config.selected { 'selected' } else { '' }
	}
	return component_finish(choice_free_segment(segment, metrics))
}

// ── Button group ────────────────────────────────────────────────────

pub struct ButtonGroupItem {
pub:
	value               string // Stable key returned by the decoder; defaults to label.
	label               string
	icon                string
	action_id           string // Defaults to button_group_action_id(id, value).
	selected            bool
	enabled             bool = true
	accessibility_label string
}

pub struct ButtonGroupConfig {
pub:
	id                  string
	frame               Rect
	items               []ButtonGroupItem
	orientation         LayoutOrientation = .horizontal
	variant             ButtonVariant
	outline             bool
	fill                bool // Stretch the buttons over the frame instead of packing them.
	enabled             bool = true
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub fn button_group_action_id(id string, value string) string {
	return component_part_id(id, choice_item_part('item:', value))
}

fn button_group_values(items []ButtonGroupItem) []string {
	return items.map(choice_value(it.value, it.label))
}

fn button_group_item_action(id string, item ButtonGroupItem) string {
	return if item.action_id.len > 0 {
		item.action_id
	} else {
		button_group_action_id(id, choice_value(item.value, item.label))
	}
}

// button_group joins buttons that share their borders and outer corners, in
// a row or a column. Each button emits its own action; `selected` only changes
// how a button looks, so the application decides what a click selects.
pub fn button_group(config ButtonGroupConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	values := button_group_values(config.items)
	choice_validate_values(values, 'button group')!
	metrics := component_metrics(config.size)
	vertical := config.orientation == .vertical
	mut segments := []ChoiceSegment{cap: config.items.len}
	if config.items.len > 0 {
		naturals := config.items.map(styled_button_width(it.label, it.icon, config.size))
		mut frames := []Rect{}
		if vertical {
			mut widest := 0.0
			for natural in naturals {
				widest = math.max(widest, natural)
			}
			width := if config.fill {
				config.frame.width
			} else {
				math.min(widest, config.frame.width)
			}
			heights, _ := choice_pack([]f64{len: naturals.len, init: metrics.height},
				config.frame.height, 0, config.fill)
			frames = choice_row_frames(heights, 0, config.frame, width, true)
		} else {
			widths, _ := choice_pack(naturals, config.frame.width, 0, config.fill)
			frames = choice_row_frames(widths, 0, config.frame, math.min(metrics.height,
				config.frame.height), false)
		}
		for index, item in config.items {
			enabled := config.enabled && item.enabled
			segments << ChoiceSegment{
				frame:   frames[index]
				id:      button_group_action_id(config.id, values[index])
				key:     'item:' + values[index]
				action:  button_group_item_action(config.id, item)
				text:    item.label
				icon:    item.icon
				colors:  button_variant_colors(config.theme, config.variant, config.outline,
					item.selected, enabled)
				enabled: enabled
				label:   if item.accessibility_label.len > 0 {
					item.accessibility_label
				} else {
					item.label
				}
				value:   if item.selected { 'selected' } else { '' }
			}
		}
	}
	group := button_variant_colors(config.theme, config.variant, config.outline, false,
		config.enabled)
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, choice_attached_segments(segments,
			group, vertical, metrics))
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
	})
}

// button_group_value_from_action returns the value of the button an action
// came from, or none for foreign actions and disabled buttons.
pub fn button_group_value_from_action(config ButtonGroupConfig, action string) ?string {
	if !config.enabled || action.len == 0 {
		return none
	}
	for item in config.items {
		if button_group_item_action(config.id, item) == action {
			return if item.enabled { choice_value(item.value, item.label) } else { none }
		}
	}
	return none
}

// ── Toggle ──────────────────────────────────────────────────────────

pub enum ToggleVariant {
	ghost   // No fill or border until pressed; the default, as upstream.
	outline // Bordered whether pressed or not.
}

fn toggle_colors(theme ComponentTheme, variant ToggleVariant, pressed bool, enabled bool) ButtonVariantColors {
	return if variant == .outline {
		button_variant_colors(theme, .secondary, true, pressed, enabled)
	} else {
		button_variant_colors(theme, .ghost, false, pressed, enabled)
	}
}

fn toggle_value(pressed bool) string {
	return if pressed { 'pressed' } else { 'released' }
}

pub struct ToggleConfig {
pub:
	id                  string
	frame               Rect
	label               string
	icon                string // Symbol name drawn before the label; see symbol_known.
	pressed             bool
	enabled             bool = true
	action_id           string // Defaults to id.
	accessibility_label string // Defaults to label; set it for icon-only toggles.
	variant             ToggleVariant
	size                ComponentSize = .medium
	theme               ComponentTheme
}

fn toggle_action(config ToggleConfig) string {
	return if config.action_id.len > 0 { config.action_id } else { config.id }
}

// toggle is a button that shows an on/off state. It is controlled: decode
// its action with toggle_pressed_from_action and rebuild with the result. It
// composes a view rather than wrapping ui2's `toggle_button`, which keeps its
// own live state and would disagree with the application's model whenever the
// application declines a change.
pub fn toggle(config ToggleConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	metrics := component_metrics(config.size)
	segment := ChoiceSegment{
		frame:   config.frame
		id:      config.id
		action:  toggle_action(config)
		text:    config.label
		icon:    config.icon
		colors:  toggle_colors(config.theme, config.variant, config.pressed, config.enabled)
		enabled: config.enabled
		label:   if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			config.label
		}
		value:   toggle_value(config.pressed)
	}
	return component_finish(choice_free_segment(segment, metrics))
}

// toggle_pressed_from_action returns the toggle's new pressed state, or none
// when the action belongs to something else or the toggle is disabled.
pub fn toggle_pressed_from_action(config ToggleConfig, action string) ?bool {
	if !config.enabled || config.id.len == 0 || action != toggle_action(config) {
		return none
	}
	return !config.pressed
}

// ── Toggle group ────────────────────────────────────────────────────

pub struct ToggleItem {
pub:
	value               string // Stable key returned by the decoder; defaults to label.
	label               string
	icon                string
	enabled             bool = true
	accessibility_label string
}

pub struct ToggleGroupConfig {
pub:
	id                  string
	frame               Rect
	items               []ToggleItem
	selected            []string // Values of the pressed items.
	multiple            bool = true // False: pressing one item releases the others.
	allow_empty         bool = true // False: the last pressed item cannot be released.
	segmented           bool // Join the items into one bordered control.
	fill                bool // Stretch the items over the frame instead of packing them.
	enabled             bool = true
	accessibility_label string
	variant             ToggleVariant
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub fn toggle_group_action_id(id string, value string) string {
	return component_part_id(id, choice_item_part('item:', value))
}

fn toggle_group_values(items []ToggleItem) []string {
	return items.map(choice_value(it.value, it.label))
}

// toggle_group lays out toggles in a row, apart or joined (segmented), with
// single or multiple selection. Decode an action with
// toggle_group_selection_from_action and rebuild with the selection it returns.
pub fn toggle_group(config ToggleGroupConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	values := toggle_group_values(config.items)
	choice_validate_values(values, 'toggle group')!
	metrics := component_metrics(config.size)
	naturals := config.items.map(styled_button_width(it.label, it.icon, config.size))
	gap := if config.segmented { 0.0 } else { metrics.gap }
	widths, used_gap := choice_pack(naturals, config.frame.width, gap, config.fill)
	frames := choice_row_frames(widths, used_gap, config.frame, math.min(metrics.height,
		config.frame.height), false)
	mut segments := []ChoiceSegment{cap: config.items.len}
	for index, item in config.items {
		pressed := values[index] in config.selected
		enabled := config.enabled && item.enabled
		segments << ChoiceSegment{
			frame:   frames[index]
			id:      toggle_group_action_id(config.id, values[index])
			key:     'item:' + values[index]
			action:  toggle_group_action_id(config.id, values[index])
			text:    item.label
			icon:    item.icon
			colors:  toggle_colors(config.theme, config.variant, pressed, enabled)
			enabled: enabled
			label:   if item.accessibility_label.len > 0 {
				item.accessibility_label
			} else {
				item.label
			}
			value:   toggle_value(pressed)
		}
	}
	children := if config.segmented {
		// Outline segments share one border; ghost segments simply touch, so
		// pressed neighbours join into one fill with rounded outer corners.
		group := toggle_colors(config.theme, config.variant, false, config.enabled)
		choice_attached_segments(segments, group, false, metrics)
	} else {
		segments.map(choice_free_segment(it, metrics))
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
	})
}

// toggle_group_selection_from_action returns the selection after the item an
// action names is pressed, in item order. It returns none for foreign or
// forged actions, disabled items, and releasing the last pressed item when
// allow_empty is false. Selected values that name no item are dropped.
pub fn toggle_group_selection_from_action(config ToggleGroupConfig, action string) ?[]string {
	if !config.enabled {
		return none
	}
	values := toggle_group_values(config.items)
	index := choice_item_index(config.id, 'item:', values, action) or { return none }
	if !config.items[index].enabled {
		return none
	}
	was_pressed := values[index] in config.selected
	mut next := []string{}
	if config.multiple {
		for i, value in values {
			pressed := if i == index { !was_pressed } else { value in config.selected }
			if pressed {
				next << value
			}
		}
	} else if !was_pressed {
		next << values[index]
	}
	if next.len == 0 && !config.allow_empty {
		return none
	}
	return next
}
