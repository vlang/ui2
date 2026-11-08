module ui2

import math

// Dialogs, alert dialogs and sheets are overlays drawn inside the window, as
// opposed to message_box(), which shows the operating system's own blocking
// alert. Each builder returns one Element that the application adds as the last
// child of its screen, so it is drawn on top and receives the clicks over it.
// The application owns `open`: it decodes the actions the overlay emits with the
// matching *_from_action function, updates its state and rebuilds.

// dialog_window_margin is the room a dialog keeps clear around it, so a small
// window shrinks the dialog rather than letting it run past the edges.
pub const dialog_window_margin = 16.0

// Scroll elements keep this much blank space below their content on AppKit, UIKit
// and the custom renderer, so a body gets it as its bottom padding.
const dialog_scroll_inset = 16.0
// A native multi-line label lays its lines out a little taller than the custom
// renderer spaces them, so wrapped text gets this much more room.
const dialog_wrap_slack = 4.0
const dialog_entrance_travel = 48.0
const dialog_entrance_duration = 0.2
const dialog_text_line_limit = 1000

// DialogBackdrop is what a dialog or sheet puts over the rest of the window.
pub enum DialogBackdrop {
	dim   // a translucent scrim that dims the page, as GPUI's overlay does
	clear // transparent: the page stays visible but cannot be clicked
	solid // an opaque fill, the theme background darkened
	none  // no backdrop: the page around the panel stays interactive
}

// dialog_scrim_opacity is how strongly the dim backdrop darkens the page: a
// little more over a dark theme, where black on dark shows less.
fn dialog_scrim_opacity(theme ComponentTheme) f64 {
	luminance := f64(((theme.background >> 16) & 0xff) + ((theme.background >> 8) & 0xff) +
		(theme.background & 0xff)) / (3 * 255.0)
	return if luminance < 0.5 { 0.6 } else { 0.4 }
}

// DialogButtonRole says what a footer button means, which is what the decoders
// report for it. It does not close anything by itself: the application does.
pub enum DialogButtonRole {
	action  // reported as .action with the button's id
	confirm // reported as .confirm; Enter activates the first enabled one
	cancel  // reported as .cancel, which dismisses like Escape
}

pub enum DialogButtonVariant {
	auto    // primary for a confirm role, outline otherwise
	primary // filled with the theme's primary color
	danger  // filled with the theme's danger color, for destructive actions
	outline // background fill with a border
	ghost   // no fill and no border
}

pub enum DialogFooterAlign {
	end     // packed to the right, in the order given
	center  // packed in the middle
	stretch // sharing the footer width equally
}

// DialogButton is one footer action. Its id is a stable key: the decoders
// report it back, and it never becomes an element id on its own.
pub struct DialogButton {
pub:
	id      string
	text    string
	role    DialogButtonRole
	variant DialogButtonVariant
	enabled bool = true
}

pub enum DialogReason {
	close_button // the header's close button
	backdrop     // a press on the backdrop, when close_on_backdrop allows it
	escape       // Escape, from dialog_key_event or sheet_key_event
	confirm      // a confirm-role button, or Enter on the first one
	cancel       // a cancel-role button
	action       // another footer button
}

// DialogEvent is a decoded request from a dialog or sheet. `button` is the
// footer button's id for confirm, cancel and action, and empty otherwise.
pub struct DialogEvent {
pub:
	reason DialogReason
	button string
}

// dismisses reports whether the event asks to close without confirming: the
// close button, the backdrop, Escape or a cancel-role button.
pub fn (event DialogEvent) dismisses() bool {
	return event.reason in [.close_button, .backdrop, .escape, .cancel]
}

// DialogLayout is the geometry a dialog or sheet is built from. `surface` is in
// the coordinates of the config frame; every other rectangle is relative to the
// surface. Body children are laid out in a box `content_width` wide whose top
// left is the top left of the body's content.
pub struct DialogLayout {
pub:
	surface           Rect
	offscreen         Rect // sheets: where the panel slides in from; dialogs: the surface
	icon              Rect
	title             Rect
	description       Rect
	close_button      Rect
	body              Rect // the visible part of the body
	content_width     f64
	content_height    f64
	scrolls           bool // the body content is taller than the body
	footer            Rect
	buttons           []Rect // in the order of the config's buttons
	resize_handle     Rect   // sheets with resizable set
	title_lines       int
	description_lines int
}

// The panel-local metrics shared by dialogs, alert dialogs and sheets.
struct DialogSpacing {
	pad           f64 // around the panel content
	text_gap      f64 // between the title and the description
	section       f64 // between the header and the body
	button_gap    f64
	close_size    f64
	close_inset   f64
	title_font    f64
	text_font     f64
	button_height f64
	radius        f64
}

fn dialog_spacing(size ComponentSize) DialogSpacing {
	metrics := component_metrics(size)
	return DialogSpacing{
		pad:           metrics.padding * 2
		text_gap:      math.round(metrics.gap * 0.67)
		section:       metrics.padding * 1.5
		button_gap:    metrics.gap + 2
		close_size:    math.round(metrics.height * 0.75)
		close_inset:   metrics.padding
		title_font:    metrics.font_size + 2
		text_font:     metrics.font_size
		button_height: metrics.height
		radius:        metrics.radius + 2
	}
}

// What a panel shows, independent of where it sits.
struct DialogPanelSpec {
	title          string
	description    string
	icon           string
	close_button   bool
	has_body       bool
	content_height f64
	buttons        []DialogButton
	footer_align   DialogFooterAlign
	size           ComponentSize
}

fn dialog_validate_buttons(buttons []DialogButton) ! {
	mut ids := map[string]bool{}
	for item in buttons {
		if item.id.trim_space().len == 0 || item.id in ids {
			return error('dialog button ids must be non-empty and unique')
		}
		ids[item.id] = true
	}
}

fn dialog_validate_extent(value f64, name string) ! {
	if !component_finite(value) || value < 0 {
		return error('${name} must be finite and non-negative')
	}
}

fn dialog_validate_content_height(value f64) ! {
	if value != -1 {
		dialog_validate_extent(value, 'dialog content height')!
	}
}

// dialog_wrap_width estimates how wide a line of wrapped text draws, in ems of
// `em` pixels. component_text_width_estimate errs wide on purpose, so a button
// is never too narrow for its title; wrapping against it breaks lines early and
// leaves a blank line under a paragraph. This one tells narrow letters from
// wide ones and comes out within a few percent of SF Pro and Roboto, a little
// over rather than under.
fn dialog_wrap_width(line string, em f64) f64 {
	mut ems := 0.0
	for r in line.runes() {
		ems += if r >= 0x2e80 {
			1.0
		} else if r >= 0x80 {
			0.62
		} else if r == ` ` || r in [`i`, `j`, `l`, `I`, `.`, `,`, `;`, `:`, `'`, `!`, `|`] {
			0.28
		} else if r in [`f`, `r`, `t`, `(`, `)`, `[`, `]`, `-`, `"`, `/`] {
			0.36
		} else if r in [`m`, `w`, `M`, `W`, `@`, `%`] {
			0.86
		} else if r >= `A` && r <= `Z` {
			0.68
		} else if r >= `0` && r <= `9` {
			0.6
		} else {
			0.56
		}
	}
	return ems * em
}

// dialog_line_count estimates how many lines `text` wraps to in `width`. It
// breaks the text where a multi-line label does, measured at the pixels the
// platform draws a point at, with a little slack so a native label does not
// have to truncate.
fn dialog_line_count(text string, font_size f64, bold bool, width f64) int {
	if text.len == 0 {
		return 0
	}
	em := font_em_pixels(font_size) * if bold { 1.09 } else { 1.03 }
	lines := wrap_text_lines_measured(text, width, dialog_text_line_limit, fn [em] (line string) f64 {
		return dialog_wrap_width(line, em)
	})
	return math.max(lines.len, 1)
}

// dialog_text_height is the height of a block of `lines` lines of text.
fn dialog_text_height(lines int, font_size f64) f64 {
	if lines <= 0 {
		return 0
	}
	return f64(lines) * font_line_height(font_size) + if lines > 1 {
		dialog_wrap_slack
	} else {
		0.0
	}
}

// dialog_children_height is how far the visible children reach downwards.
fn dialog_children_height(children []Element) f64 {
	mut height := 0.0
	for child in children {
		if !child.hidden {
			height = math.max(height, child.frame.y + child.frame.height)
		}
	}
	return height
}

// dialog_fit keeps r inside a width by height box, so tiny windows squeeze the
// parts of a panel together instead of pushing them out of it.
fn dialog_fit(r Rect, width f64, height f64) Rect {
	x := math.max(0.0, math.min(r.x, width))
	y := math.max(0.0, math.min(r.y, height))
	return rect(x, y, math.max(0.0, math.min(r.width, width - x)), math.max(0.0, math.min(r.height,
		height - y)))
}

struct DialogHeaderLayout {
	icon              Rect
	title             Rect
	description       Rect
	close_button      Rect
	height            f64
	title_lines       int
	description_lines int
}

fn dialog_header_layout(spec DialogPanelSpec, spacing DialogSpacing, width f64) DialogHeaderLayout {
	icon_size := if spec.icon.len > 0 { spacing.close_size } else { 0.0 }
	text_x := spacing.pad + if icon_size > 0 { icon_size + spacing.text_gap * 2 } else { 0.0 }
	text_right := if spec.close_button {
		width - spacing.close_inset - spacing.close_size - spacing.text_gap
	} else {
		width - spacing.pad
	}
	text_width := math.max(0.0, text_right - text_x)
	title_lines := dialog_line_count(spec.title, spacing.title_font, true, text_width)
	description_lines := dialog_line_count(spec.description, spacing.text_font, false,
		text_width)
	title_height := dialog_text_height(title_lines, spacing.title_font)
	description_height := dialog_text_height(description_lines, spacing.text_font)
	description_y := spacing.pad + title_height + if title_lines > 0 && description_lines > 0 {
		spacing.text_gap
	} else {
		0.0
	}
	text_height := description_y + description_height - spacing.pad
	close_height := if spec.close_button {
		spacing.close_inset + spacing.close_size - spacing.pad
	} else {
		0.0
	}
	return DialogHeaderLayout{
		icon:              if icon_size > 0 {
			rect(spacing.pad, spacing.pad, icon_size, icon_size)
		} else {
			Rect{}
		}
		title:             rect(text_x, spacing.pad, text_width, title_height)
		description:       rect(text_x, description_y, text_width, description_height)
		close_button:      if spec.close_button {
			rect(width - spacing.close_inset - spacing.close_size, spacing.close_inset,
				spacing.close_size, spacing.close_size)
		} else {
			Rect{}
		}
		height:            math.max(math.max(text_height, icon_size), close_height)
		title_lines:       title_lines
		description_lines: description_lines
	}
}

// dialog_panel_heights returns where the body starts and how much of a panel's
// height is not body: everything else in the panel has a fixed size. The blank
// space a scroll keeps below its content stands in for the padding under the body.
fn dialog_panel_heights(spec DialogPanelSpec, spacing DialogSpacing, header_height f64) (f64, f64) {
	mut y := spacing.pad + header_height
	if spec.has_body && header_height > 0 {
		y += spacing.section
	}
	body_y := y
	mut fixed := y
	if spec.has_body {
		fixed += math.max(0.0, spacing.pad - dialog_scroll_inset)
	}
	if spec.buttons.len > 0 {
		if !spec.has_body && header_height > 0 {
			fixed += spacing.pad
		}
		fixed += spacing.button_height + spacing.pad
	} else if !spec.has_body {
		fixed += spacing.pad
	}
	return body_y, fixed
}

fn dialog_panel_natural_height(spec DialogPanelSpec, spacing DialogSpacing, width f64) f64 {
	header := dialog_header_layout(spec, spacing, width)
	_, fixed := dialog_panel_heights(spec, spacing, header.height)
	return fixed + if spec.has_body { spec.content_height + dialog_scroll_inset } else { 0.0 }
}

// dialog_panel_layout lays a panel out in a width by height box. The body takes
// whatever height the header and footer leave, and the footer sits at the bottom.
fn dialog_panel_layout(spec DialogPanelSpec, spacing DialogSpacing, width f64, height f64) DialogLayout {
	header := dialog_header_layout(spec, spacing, width)
	body_y, fixed := dialog_panel_heights(spec, spacing, header.height)
	room := if spec.has_body { math.max(0.0, height - fixed) } else { 0.0 }
	overflows := spec.has_body && spec.content_height + dialog_scroll_inset > room + 0.5
	// Content cut off at the bottom of a scrolling body would otherwise run right
	// up to the footer, so the body stops a little short of it.
	body_height := if overflows && spec.buttons.len > 0 {
		math.max(0.0, room - spacing.button_gap)
	} else {
		room
	}
	footer_y := height - spacing.pad - spacing.button_height
	footer := if spec.buttons.len > 0 {
		dialog_fit(rect(spacing.pad, footer_y, width - spacing.pad * 2, spacing.button_height),
			width, height)
	} else {
		Rect{}
	}
	mut buttons := []Rect{cap: spec.buttons.len}
	for frame in dialog_button_frames(spec, spacing, width) {
		buttons << dialog_fit(rect(frame.x, footer.y, frame.width, footer.height), width,
			height)
	}
	// The body spans the panel inside its one-pixel border, so a scroller sits at
	// the edge, while its content keeps the panel padding.
	body := if spec.has_body {
		dialog_fit(rect(1, body_y, width - 2, body_height), width, height)
	} else {
		Rect{}
	}
	return DialogLayout{
		surface:           rect(0, 0, width, height)
		icon:              dialog_fit(header.icon, width, height)
		title:             dialog_fit(header.title, width, height)
		description:       dialog_fit(header.description, width, height)
		close_button:      dialog_fit(header.close_button, width, height)
		body:              body
		content_width:     math.max(0.0, width - spacing.pad * 2)
		content_height:    if spec.has_body { spec.content_height } else { 0.0 }
		scrolls:           overflows
		footer:            footer
		buttons:           buttons
		title_lines:       header.title_lines
		description_lines: header.description_lines
	}
}

// dialog_button_frames sizes each footer button to an estimate of its text,
// shrinks them evenly when they do not fit and places them per the alignment.
// Only x and width are meaningful; the caller supplies the footer's y.
fn dialog_button_frames(spec DialogPanelSpec, spacing DialogSpacing, width f64) []Rect {
	count := spec.buttons.len
	if count == 0 {
		return []Rect{}
	}
	inner := math.max(0.0, width - spacing.pad * 2)
	gap := math.min(spacing.button_gap, inner / f64(count * 2))
	available := inner - gap * f64(count - 1)
	em := font_em_pixels(spacing.text_font)
	mut widths := []f64{cap: count}
	mut total := 0.0
	for item in spec.buttons {
		natural := if spec.footer_align == .stretch {
			available / f64(count)
		} else {
			math.max(component_text_width_estimate(item.text, em) + spacing.pad * 2,
				spacing.button_height * 2.5)
		}
		widths << natural
		total += natural
	}
	if total > available && total > 0 {
		scale := math.max(available, 0) / total
		for i in 0 .. widths.len {
			widths[i] *= scale
		}
		total = math.max(available, 0)
	}
	used := total + gap * f64(count - 1)
	mut x := match spec.footer_align {
		.end { spacing.pad + inner - used }
		.center { spacing.pad + (inner - used) / 2 }
		.stretch { spacing.pad }
	}
	mut frames := []Rect{cap: count}
	for w in widths {
		frames << rect(x, 0, w, 0)
		x += w + gap
	}
	return frames
}

// dialog_backdrop_color is the solid backdrop: the theme background darkened,
// so it reads as a dimmed window in both light and dark themes.
pub fn dialog_backdrop_color(theme ComponentTheme) u32 {
	r := u32(f64((theme.background >> 16) & 0xff) * 0.55)
	g := u32(f64((theme.background >> 8) & 0xff) * 0.55)
	b := u32(f64(theme.background & 0xff) * 0.55)
	return (r << 16) | (g << 8) | b
}

fn dialog_backdrop_box(backdrop DialogBackdrop, theme ComponentTheme) BoxStyle {
	return match backdrop {
		.solid {
			BoxStyle{
				bg: dialog_backdrop_color(theme)
			}
		}
		.dim {
			BoxStyle{
				bg:      0x000000
				opacity: dialog_scrim_opacity(theme)
			}
		}
		else {
			BoxStyle{
				transparent: true
			}
		}
	}
}

fn dialog_button_part(button_id string) string {
	return 'button:' + button_id.bytes().hex()
}

// dialog_button_action_id is the action a footer button emits, so an
// application can recognize one before decoding it.
pub fn dialog_button_action_id(id string, button_id string) string {
	return component_part_id(id, dialog_button_part(button_id))
}

fn dialog_resolved_variant(item DialogButton) DialogButtonVariant {
	if item.variant != .auto {
		return item.variant
	}
	return if item.role == .confirm { .primary } else { .outline }
}

fn dialog_button_element(id string, item DialogButton, frame Rect, enabled bool, spacing DialogSpacing, theme ComponentTheme) Element {
	variant := dialog_resolved_variant(item)
	// Filled buttons carry no border: the custom renderer draws borders square,
	// which would show at the corners of a rounded fill.
	box := match variant {
		.primary {
			BoxStyle{
				bg:     theme.primary
				radius: spacing.radius - 2
			}
		}
		.danger {
			BoxStyle{
				bg:     theme.danger
				radius: spacing.radius - 2
			}
		}
		.ghost {
			BoxStyle{
				transparent: true
				radius:      spacing.radius - 2
			}
		}
		else { component_box(theme.background, theme.border, spacing.radius - 2) }
	}
	foreground := match variant {
		.primary { theme.primary_foreground }
		.danger { theme.danger_foreground }
		else { theme.foreground }
	}
	part := dialog_button_part(item.id)
	return Element{
		...button(component_part_id(id, part), item.text, frame, box, TextStyle{
			color: foreground
			size:  spacing.text_font
			bold:  variant in [.primary, .danger]
			align: .center
		})
		key:                 part
		enabled:             enabled && item.enabled
		accessibility_label: item.text
	}
}

// dialog_close_element is the header's close control: an xmark symbol on a view
// with button behavior, since a button title cannot hold an icon on every
// backend.
fn dialog_close_element(id string, frame Rect, enabled bool, theme ComponentTheme) Element {
	glyph := math.round(math.min(frame.width, frame.height) * 0.6)
	mark := Element{
		...image('', 'symbol:xmark', rect((frame.width - glyph) / 2, (frame.height - glyph) / 2,
			glyph, glyph))
		text_style: TextStyle{
			color: theme.muted_foreground
		}
	}
	return Element{
		...with_button_behavior(view(component_part_id(id, 'close'), frame, BoxStyle{
			transparent: true
		}, [mark]))
		key:                 'close'
		enabled:             enabled
		cursor:              cursor_pointing_hand
		accessibility_label: 'Close'
	}
}

// dialog_panel_children builds the header, body and footer of a panel from its
// layout. Body children are wrapped in a view at the panel padding inside a
// scroll element, which only scrolls when they are taller than the body.
fn dialog_panel_children(id string, spec DialogPanelSpec, geom DialogLayout, children []Element, enabled bool, icon_color u32, theme ComponentTheme) []Element {
	spacing := dialog_spacing(spec.size)
	mut parts := []Element{}
	if spec.icon.len > 0 {
		parts << Element{
			...image('', 'symbol:' + spec.icon, geom.icon)
			key:        'icon'
			text_style: TextStyle{
				color: icon_color
			}
		}
	}
	if spec.title.len > 0 {
		parts << Element{
			...label(component_part_id(id, 'title'), spec.title, geom.title, TextStyle{
				color:  theme.foreground
				size:   spacing.title_font
				bold:   true
				valign: .top
				lines:  geom.title_lines
			})
			key: 'title'
		}
	}
	if spec.description.len > 0 {
		parts << Element{
			...label(component_part_id(id, 'description'), spec.description, geom.description,
				TextStyle{
					color:  theme.muted_foreground
					size:   spacing.text_font
					valign: .top
					lines:  geom.description_lines
				})
			key: 'description'
		}
	}
	if spec.has_body {
		content := view('', rect(spacing.pad - geom.body.x, 0, geom.content_width, geom.content_height),
			BoxStyle{ transparent: true }, children)
		parts << Element{
			...scroll(component_part_id(id, 'body'), geom.body, theme.background, [
				content,
			])
			key: 'body'
		}
	}
	for index, item in spec.buttons {
		parts << dialog_button_element(id, item, geom.buttons[index], enabled, spacing,
			theme)
	}
	if spec.close_button {
		parts << dialog_close_element(id, geom.close_button, enabled, theme)
	}
	return parts
}

// dialog_decode turns an action a dialog or sheet emitted back into a request,
// rejecting foreign, malformed and forged actions, disabled buttons, and every
// action of a closed or disabled overlay.
fn dialog_decode(id string, open bool, enabled bool, close_button bool, backdrop_closes bool, buttons []DialogButton, action string) ?DialogEvent {
	if !open || !enabled {
		return none
	}
	part := component_action_part(id, action) or { return none }
	if part == 'close' {
		return if close_button {
			DialogEvent{
				reason: .close_button
			}
		} else {
			none
		}
	}
	if part == 'backdrop' {
		return if backdrop_closes {
			DialogEvent{
				reason: .backdrop
			}
		} else {
			none
		}
	}
	if !part.starts_with('button:') {
		return none
	}
	for item in buttons {
		if dialog_button_part(item.id) == part {
			if !item.enabled {
				return none
			}
			return DialogEvent{
				reason: match item.role {
					.action { DialogReason.action }
					.confirm { DialogReason.confirm }
					.cancel { DialogReason.cancel }
				}
				button: item.id
			}
		}
	}
	return none
}

// dialog_decode_key reads Escape and, when Enter confirms, Enter or keypad
// Enter. Keys with a modifier belong to the application's shortcuts.
fn dialog_decode_key(open bool, enabled bool, close_on_escape bool, confirm_on_enter bool, buttons []DialogButton, event KeyEvent) ?DialogEvent {
	if !open || !enabled || event.shift || event.ctrl || event.alt || event.cmd {
		return none
	}
	if event.code == .escape {
		return if close_on_escape {
			DialogEvent{
				reason: .escape
			}
		} else {
			none
		}
	}
	if confirm_on_enter && (event.code == .enter || event.code == .kp_enter) {
		for item in buttons {
			if item.role == .confirm && item.enabled {
				return DialogEvent{
					reason: .confirm
					button: item.id
				}
			}
		}
	}
	return none
}

// dialog_release_animation returns an element to its declaration once its
// entrance or slide has finished, so a later resize lays it out afresh instead
// of keeping the position the animation ended on.
fn dialog_release_animation(event AnimationEvent) {
	if event.kind == .complete {
		clear_animation(event.id)
	}
}

// ── Dialog ─────────────────────────────────────────────────────────

pub enum DialogWidth {
	small  // 360
	medium // 448, GPUI Kit's default
	large  // 640
	full   // the whole window less the margins
}

fn dialog_preset_width(width DialogWidth, available f64) f64 {
	return match width {
		.small { 360.0 }
		.medium { 448.0 }
		.large { 640.0 }
		.full { available }
	}
}

pub struct DialogConfig {
pub:
	id    string
	frame Rect // the area the dialog is centered in and its backdrop covers: normally the window
	open  bool
	// Header. icon is a symbol name (see symbol_known) drawn before the title.
	title       string
	description string
	icon        string
	icon_tone   ComponentTone = .warning
	// Body children are positioned relative to the body content, which is
	// dialog_body_width(config) wide. content_height -1 measures the children.
	children       []Element
	content_height f64 = -1
	buttons        []DialogButton
	footer_align   DialogFooterAlign = .end
	width          DialogWidth       = .medium
	custom_width   f64 // > 0 replaces the width preset
	height         f64 // > 0 fixes the dialog height instead of fitting its content
	// Dismissal. The application handles each in its event and key handlers.
	close_button      bool           = true
	close_on_backdrop bool           = true
	close_on_escape   bool           = true
	confirm_on_enter  bool           = true
	backdrop          DialogBackdrop = .dim
	enabled           bool           = true // false disables every action, e.g. while saving
	size              ComponentSize  = .medium
	theme             ComponentTheme
}

fn modal_dialog_spec(config DialogConfig) DialogPanelSpec {
	return DialogPanelSpec{
		title:          config.title
		description:    config.description
		icon:           config.icon
		close_button:   config.close_button
		has_body:       config.children.len > 0 || config.content_height > 0
		content_height: if config.content_height >= 0 {
			config.content_height
		} else {
			dialog_children_height(config.children)
		}
		buttons:        config.buttons
		footer_align:   config.footer_align
		size:           config.size
	}
}

fn modal_dialog_validate(config DialogConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	dialog_validate_extent(config.custom_width, 'dialog width')!
	dialog_validate_extent(config.height, 'dialog height')!
	dialog_validate_content_height(config.content_height)!
	dialog_validate_buttons(config.buttons)!
}

fn modal_dialog_width(config DialogConfig) f64 {
	available := math.max(0.0, config.frame.width - 2 * math.min(dialog_window_margin,
		config.frame.width / 2))
	requested := if config.custom_width > 0 {
		config.custom_width
	} else {
		dialog_preset_width(config.width, available)
	}
	return math.min(requested, available)
}

// dialog_body_width is the width body children are laid out in, so an
// application can size them before building the dialog.
pub fn dialog_body_width(config DialogConfig) f64 {
	return math.max(0.0, modal_dialog_width(config) - dialog_spacing(config.size).pad * 2)
}

// dialog_layout centers the dialog in its frame. It is as tall as its content
// unless height fixes it, and never comes closer than dialog_window_margin to
// the frame's edges: a dialog that would, keeps its header and footer and
// scrolls its body instead.
pub fn dialog_layout(config DialogConfig) !DialogLayout {
	modal_dialog_validate(config)!
	spec := modal_dialog_spec(config)
	spacing := dialog_spacing(config.size)
	width := modal_dialog_width(config)
	max_height := math.max(0.0, config.frame.height - 2 * math.min(dialog_window_margin,
		config.frame.height / 2))
	requested := if config.height > 0 {
		config.height
	} else {
		dialog_panel_natural_height(spec, spacing, width)
	}
	height := math.min(requested, max_height)
	geom := modal_view_geometry(
		frame:          config.frame
		content_width:  width
		content_height: height
	)!
	panel := dialog_panel_layout(spec, spacing, width, height)
	return DialogLayout{
		...panel
		surface:   geom.content
		offscreen: geom.content
	}
}

// dialog_surface_id is the id of the element that draws a dialog's surface,
// which dialog_open_animation moves.
pub fn dialog_surface_id(id string) string {
	return component_part_id(id, 'surface')
}

// modal_dialog builds a structured dialog on modal_view: modal_view supplies the
// backdrop, the centering and a surface that keeps clicks inside the dialog from
// reaching the backdrop; this adds the header, the scrolling body, the footer
// and the close button. A closed dialog stays in the tree, hidden, so text
// fields in it keep their native state between openings.
pub fn modal_dialog(config DialogConfig) !Element {
	geom := dialog_layout(config)!
	spec := modal_dialog_spec(config)
	spacing := dialog_spacing(config.size)
	icon_color, _ := config.theme.colors(config.icon_tone)
	parts := dialog_panel_children(config.id, spec, geom, config.children, config.enabled,
		if config.icon_tone == .neutral { config.theme.foreground } else { icon_color },
		config.theme)
	surface_el := Element{
		...view(dialog_surface_id(config.id), geom.surface, BoxStyle{
			...component_box(config.theme.background, config.theme.border, spacing.radius)
			shadow: component_popup_shadow()
		}, parts)
		accessibility_role:  'group'
		accessibility_label: config.title
	}
	// Without a backdrop the modal view covers only the dialog itself, so the
	// rest of the window keeps working.
	non_modal := config.backdrop == .none
	modal_frame := if non_modal {
		rect(config.frame.x + geom.surface.x, config.frame.y + geom.surface.y, geom.surface.width,
			geom.surface.height)
	} else {
		config.frame
	}
	host := modal_view(
		id:                config.id
		frame:             modal_frame
		open:              config.open
		auto_dismiss:      config.close_on_backdrop && !non_modal
		dismiss_action_id: component_part_id(config.id, 'backdrop')
		content_width:     geom.surface.width
		content_height:    geom.surface.height
		overlay_box:       dialog_backdrop_box(config.backdrop, config.theme)
		content_box:       BoxStyle{
			transparent: true
		}
		content:           surface_el
	)!
	return component_finish(Element{
		...host
		accessibility_role:  'dialog'
		accessibility_label: config.title
	})
}

// dialog_event_from_action decodes an action from modal_dialog against the
// config the dialog was built with. Handle the event and rebuild, usually with
// open set to false.
pub fn dialog_event_from_action(config DialogConfig, action string) ?DialogEvent {
	return dialog_decode(config.id, config.open, config.enabled, config.close_button,
		config.close_on_backdrop && config.backdrop != .none, config.buttons, action)
}

// dialog_key_event is for the application's on_key_event handler: Escape asks
// to dismiss and Enter confirms with the first enabled confirm button. Call
// consume_key when it returns an event. On AppKit a focused text field keeps
// Return and emits its submit_id instead, so route that to the same answer.
pub fn dialog_key_event(config DialogConfig, event KeyEvent) ?DialogEvent {
	return dialog_decode_key(config.open, config.enabled, config.close_on_escape, config.confirm_on_enter,
		config.buttons, event)
}

// dialog_open_animation is an optional entrance: start it on
// dialog_surface_id(config.id) when the dialog opens and the surface drops into
// place from a little above. The surface returns to its declaration when the
// animation ends.
pub fn dialog_open_animation(config DialogConfig) !Animation {
	geom := dialog_layout(config)!
	final_y := if config.backdrop == .none { 0.0 } else { geom.surface.y }
	return (animation(duration: 0, y: final_y - dialog_entrance_travel) + animation(
		duration:   dialog_entrance_duration
		transition: .out_cubic
		y:          final_y
	)).with_event_handler(dialog_release_animation)
}
