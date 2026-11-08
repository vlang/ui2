module ui2

import math

// tooltip_popup is GPUI Kit's managed Tooltip next to ui2's with_tooltip, which
// keeps the platform's own hover text. tooltip_popup draws a themed surface the
// application places like a popover: text that wraps, a keyboard shortcut,
// a title and description with an icon, or any elements, on any side of its
// trigger, with or without an arrow, in the popover colors or a tone.
//
// Its timing is TooltipGroup, a pure state machine one window (or one group
// of triggers) shares: a tooltip opens after the pointer rests on a trigger
// for show_delay, stays for grace_period after the pointer leaves, and a
// trigger entered within that period shows its tooltip at once. A press on a
// trigger hides it until the pointer leaves. The application wraps each
// trigger with tooltip_trigger, feeds its pointer events to tooltip_step, runs
// the timers the steps ask for with `after` and `cancel_timer`, and builds
// tooltip_popup(...) last, open while state.shows(key).

// TooltipTimer names the delay a TooltipGroup waits out.
pub enum TooltipTimer {
	none
	show // The pointer rests on `current`; its tooltip opens when this fires.
	hide // The pointer left `current`; its tooltip closes when this fires.
}

pub struct TooltipGroup {
pub:
	show_delay   f64 = 0.5 // Seconds the pointer rests on a trigger before its tooltip shows.
	grace_period f64 = 0.3 // Seconds a tooltip stays after the pointer leaves its trigger.
	open         bool   // A tooltip shows: `current`'s.
	current      string // The trigger whose tooltip shows or is about to.
	hovered      string // The trigger under the pointer.
	// suppressed is a trigger that was pressed: its tooltip stays hidden until the
	// pointer leaves it.
	suppressed string
	pending    TooltipTimer
	// generation names the pending timer; a firing that carries another value is
	// stale and changes nothing.
	generation u64
}

// TooltipStep is a transition and the timer work it needs: cancel the timer an
// earlier step started when `cancel` is set, and start `after(delay)` when
// `schedule` is, passing `state.generation` to timer_fired when it runs.
pub struct TooltipStep {
pub:
	state    TooltipGroup
	cancel   bool
	schedule bool
	delay    f64
}

// shows reports whether the tooltip of trigger key is open.
pub fn (state TooltipGroup) shows(key string) bool {
	return state.open && key.len > 0 && state.current == key
}

fn tooltip_seconds(seconds f64) f64 {
	return if component_finite(seconds) && seconds > 0 { seconds } else { 0 }
}

fn (state TooltipGroup) wait(next TooltipGroup, timer TooltipTimer, delay f64) TooltipStep {
	return TooltipStep{
		state:    TooltipGroup{
			...next
			pending:    timer
			generation: state.generation + 1
		}
		cancel:   state.pending != .none
		schedule: true
		delay:    delay
	}
}

fn (state TooltipGroup) settle(next TooltipGroup) TooltipStep {
	if state.pending == .none {
		return TooltipStep{
			state: next
		}
	}
	return TooltipStep{
		state:  TooltipGroup{
			...next
			pending:    .none
			generation: state.generation + 1
		}
		cancel: true
	}
}

// entered is the pointer arriving on trigger key. A tooltip that shows, or is
// still in its grace period, switches to key at once, as does a zero delay;
// otherwise key's tooltip waits for delay, or show_delay when delay is negative.
pub fn (state TooltipGroup) entered(key string, delay f64) TooltipStep {
	next := TooltipGroup{
		...state
		hovered: key
	}
	if key.len == 0 || key == state.suppressed {
		return TooltipStep{
			state: next
		}
	}
	wait := tooltip_seconds(if delay < 0 { state.show_delay } else { delay })
	if state.open || wait == 0 {
		return state.settle(TooltipGroup{
			...next
			open:    true
			current: key
		})
	}
	return state.wait(TooltipGroup{
		...next
		current: key
	}, .show, wait)
}

// left is the pointer leaving trigger key: a tooltip still waiting is called
// off, and an open one starts its grace period. Leaving a pressed trigger lets
// its tooltip show again next time.
pub fn (state TooltipGroup) left(key string) TooltipStep {
	next := TooltipGroup{
		...state
		hovered:    if state.hovered == key { '' } else { state.hovered }
		suppressed: if state.suppressed == key { '' } else { state.suppressed }
	}
	if key.len == 0 || state.current != key {
		return TooltipStep{
			state: next
		}
	}
	if !state.open {
		return state.settle(TooltipGroup{
			...next
			current: ''
		})
	}
	grace := tooltip_seconds(state.grace_period)
	if grace == 0 {
		return state.settle(TooltipGroup{
			...next
			open:    false
			current: ''
		})
	}
	return state.wait(next, .hide, grace)
}

// timer_fired applies the timer named by generation, or changes nothing when
// that timer has since been replaced or called off.
pub fn (state TooltipGroup) timer_fired(generation u64) TooltipStep {
	if generation != state.generation || state.pending == .none {
		return TooltipStep{
			state: state
		}
	}
	if state.pending == .show {
		hovered := state.hovered == state.current
		return TooltipStep{
			state: TooltipGroup{
				...state
				open:    hovered
				current: if hovered { state.current } else { '' }
				pending: .none
			}
		}
	}
	return TooltipStep{
		state: TooltipGroup{
			...state
			open:    false
			current: ''
			pending: .none
		}
	}
}

// pressed hides the tooltip at once when trigger key is clicked, and keeps it
// hidden until the pointer leaves key. Call it from the trigger's own action.
pub fn (state TooltipGroup) pressed(key string) TooltipStep {
	return state.settle(TooltipGroup{
		...state
		open:       false
		current:    ''
		suppressed: key
	})
}

// dismissed hides the tooltip at once, for Escape (see popover_dismiss_key).
pub fn (state TooltipGroup) dismissed() TooltipStep {
	return state.settle(TooltipGroup{
		...state
		open:    false
		current: ''
	})
}

// tooltip_trigger_action is the hover action of trigger key, whose tooltip waits
// for the state's show_delay, or for delay seconds when delay is not negative.
pub fn tooltip_trigger_action(id string, key string, delay f64) string {
	if delay < 0 || !component_finite(delay) {
		return component_part_id(id, 'trigger:${key}')
	}
	ms := int(math.round(math.min(delay, 60) * 1000))
	return component_part_id(id, 'trigger@${ms}:${key}')
}

// TooltipTriggerEvent is a decoded pointer event of a tooltip trigger.
pub struct TooltipTriggerEvent {
pub:
	key     string
	entered bool
	delay   f64 = -1 // The trigger's own show delay; negative uses the state's.
}

// tooltip_trigger_event decodes the pointer entering or leaving a trigger of
// tooltip group id; anything else decodes to none.
pub fn tooltip_trigger_event(id string, event string) ?TooltipTriggerEvent {
	pointer := parse_pointer_event(event) or { return none }
	if pointer.phase != 'enter' && pointer.phase != 'leave' {
		return none
	}
	part := component_action_part(id, pointer.action) or { return none }
	mut delay := -1.0
	mut key := ''
	if part.starts_with('trigger:') {
		key = part['trigger:'.len..]
	} else if part.starts_with('trigger@') {
		rest := part['trigger@'.len..]
		colon := rest.index(':') or { return none }
		ms := component_parse_index(rest[..colon], 60000) or { return none }
		delay = f64(ms) / 1000
		key = rest[colon + 1..]
	} else {
		return none
	}
	if key.len == 0 {
		return none
	}
	return TooltipTriggerEvent{
		key:     key
		entered: pointer.phase == 'enter'
		delay:   delay
	}
}

// tooltip_step decodes a trigger's pointer event and returns the transition
// with the timer work to do. Every other event decodes to none.
pub fn tooltip_step(id string, state TooltipGroup, event string) ?TooltipStep {
	trigger := tooltip_trigger_event(id, event)?
	return if trigger.entered {
		state.entered(trigger.key, trigger.delay)
	} else {
		state.left(trigger.key)
	}
}

// tooltip_trigger wraps any element in the hover area of trigger key of tooltip
// group id. The wrapper takes the element's frame; the element keeps its own
// action. delay is the trigger's own show delay in seconds; pass -1 for the
// state's.
pub fn tooltip_trigger(id string, key string, delay f64, trigger Element) !Element {
	component_validate_id(id)!
	component_validate_id(key)!
	component_validate_frame(trigger.frame)!
	return component_finish(Element{
		...view(tooltip_trigger_action(id, key, delay), trigger.frame, BoxStyle{
			transparent: true
		}, [
			Element{
				...trigger
				frame: rect(0, 0, trigger.frame.width, trigger.frame.height)
			},
		])
		hoverable: true
	})
}

pub struct TooltipPopupConfig {
pub:
	id     string
	open   bool
	anchor Rect // The trigger, in window coordinates.
	window Rect // Pass ui2.bounds().
	// text is the tooltip's message; it wraps at max_width.
	text string
	// shortcut is a key binding shown after the text the way the platform writes
	// it ('cmd+s' is ⌘S on macOS and Ctrl+S elsewhere); keys shows keys as given.
	shortcut string
	keys     []string
	// title, description and icon make a richer tooltip: an icon (a symbol name)
	// before a bold title, with the text and a muted description below it.
	title       string
	description string
	icon        string
	// children are laid out under the text in content_width x content_height,
	// for content of any other kind.
	children       []Element
	content_width  f64
	content_height f64
	max_width      f64          = 280
	side           PopoverSide  = .bottom
	align          PopoverAlign = .center
	offset         f64          = 6
	margin         f64          = 4
	arrow          bool
	// tone paints the surface in a tone's colors; neutral is the popover's.
	tone  ComponentTone = .neutral
	size  ComponentSize = .small
	theme ComponentTheme
}

// tooltip_shortcut_text is how a tooltip writes its key binding.
pub fn tooltip_shortcut_text(config TooltipPopupConfig) string {
	if config.keys.len > 0 {
		return config.keys.join(' ')
	}
	if config.shortcut.len == 0 {
		return ''
	}
	formatted := menu_shortcut_label(config.shortcut)
	return if formatted.len > 0 { formatted } else { config.shortcut }
}

struct TooltipLine {
	text  string
	style TextStyle
}

struct TooltipPopupLayout {
	width       f64
	height      f64
	pad_x       f64
	pad_y       f64
	line_height f64
	icon        f64 // Icon side; zero without one.
	text_width  f64 // Room for the text lines.
	lines       []TooltipLine
	shortcut    string
	shortcut_w  f64
	content_y   f64 // Where children start, below the lines.
}

fn tooltip_colors(config TooltipPopupConfig) (u32, u32, u32, u32) {
	if config.tone == .neutral {
		return config.theme.background, config.theme.foreground, config.theme.border, config.theme.muted_foreground
	}
	bg, fg := config.theme.colors(config.tone)
	return bg, fg, bg, popover_blend(fg, bg, 0.3)
}

fn tooltip_popup_layout(config TooltipPopupConfig) TooltipPopupLayout {
	metrics := component_metrics(config.size)
	_, fg, _, muted := tooltip_colors(config)
	font := metrics.font_size
	lh := math.ceil(font * 1.4)
	pad_x := metrics.padding + 2
	pad_y := math.max(metrics.padding / 2, 3)
	icon := if config.icon.len > 0 { math.round(font + 2) } else { 0.0 }
	icon_gap := if icon > 0 { 6.0 } else { 0.0 }
	shortcut := tooltip_shortcut_text(config)
	shortcut_style := TextStyle{
		color: muted
		size:  math.max(font - 1, 10)
	}
	shortcut_w := if shortcut.len > 0 { basics_text_width(shortcut, shortcut_style) } else { 0.0 }
	shortcut_gap := if shortcut.len > 0 { 12.0 } else { 0.0 }
	inset := basics_label_inset()
	max_inner := math.max(config.max_width - 2 * pad_x - icon - icon_gap - shortcut_gap - shortcut_w,
		24)
	title_style := TextStyle{
		color: fg
		size:  font
		bold:  true
	}
	body_style := TextStyle{
		color: fg
		size:  font
	}
	desc_style := TextStyle{
		color: muted
		size:  math.max(font - 1, 10)
	}
	mut lines := []TooltipLine{}
	mut widest := 0.0
	for part in [TooltipLine{config.title, title_style}, TooltipLine{config.text, body_style},
		TooltipLine{config.description, desc_style}] {
		if part.text.len == 0 {
			continue
		}
		for line in wrap_text_to_width(part.text, part.style, max_inner + 2 * inset) {
			lines << TooltipLine{line, part.style}
			widest = math.max(widest, basics_text_width(line, part.style))
		}
	}
	text_width := math.max(widest, if config.children.len > 0 {
		math.max(config.content_width, 0)
	} else {
		0.0
	})
	content_gap := if lines.len > 0 && config.children.len > 0 { 6.0 } else { 0.0 }
	content_h := if config.children.len > 0 { math.max(config.content_height, 0) } else { 0.0 }
	text_h := f64(lines.len) * lh
	inner_h := math.max(text_h + content_gap + content_h, math.max(icon, lh))
	width := math.ceil(2 * pad_x + icon + icon_gap + text_width + shortcut_gap + shortcut_w)
	return TooltipPopupLayout{
		width:       width
		height:      math.ceil(2 * pad_y + inner_h)
		pad_x:       pad_x
		pad_y:       pad_y
		line_height: lh
		icon:        icon
		text_width:  text_width
		lines:       lines
		shortcut:    shortcut
		shortcut_w:  shortcut_w
		content_y:   pad_y + text_h + content_gap
	}
}

// tooltip_popup_size is how wide and tall a tooltip built from config is.
pub fn tooltip_popup_size(config TooltipPopupConfig) (f64, f64) {
	layout := tooltip_popup_layout(config)
	return layout.width, layout.height
}

// tooltip draws a tooltip next to its anchor, flipped and shifted to stay in
// the window, while open. It has no backdrop and answers no clicks; build it
// after everything it may cover.
pub fn tooltip_popup(config TooltipPopupConfig) !Element {
	component_validate_id(config.id)!
	if !component_finite(config.max_width) || config.max_width < 0
		|| !component_finite(config.content_width) || !component_finite(config.content_height) {
		return error('tooltip sizes must be finite and non-negative')
	}
	metrics := component_metrics(config.size)
	layout := tooltip_popup_layout(config)
	depth := if config.arrow { popover_arrow_depth(config.size) } else { 0.0 }
	placement := popover_place(
		anchor: config.anchor
		window: config.window
		width:  layout.width
		height: layout.height
		side:   config.side
		align:  config.align
		offset: config.offset
		margin: config.margin
		arrow:  depth
		radius: metrics.radius
	)!
	if !config.open {
		return component_finish(popover_closed(config.id))
	}
	bg, fg, border, muted := tooltip_colors(config)
	size := rect(0, 0, layout.width, layout.height)
	box, mut children := popover_panel(size, bg, border, metrics.radius, true)
	inset := basics_label_inset()
	text_x := layout.pad_x + layout.icon + if layout.icon > 0 { 6.0 } else { 0.0 }
	if layout.icon > 0 {
		children << basics_symbol(config.icon, rect(layout.pad_x, layout.pad_y + (layout.line_height - layout.icon) / 2,
			layout.icon, layout.icon), fg)
	}
	for i, line in layout.lines {
		children << label('', line.text, rect(text_x - inset, layout.pad_y + f64(i) * layout.line_height,
			layout.text_width + 2 * inset + 1, layout.line_height), line.style)
	}
	if layout.shortcut.len > 0 {
		children << label('', layout.shortcut, rect(layout.width - layout.pad_x - layout.shortcut_w - inset,
			layout.pad_y, layout.shortcut_w + 2 * inset + 1, layout.line_height), TextStyle{
			color: muted
			size:  math.max(metrics.font_size - 1, 10)
		})
	}
	if config.children.len > 0 {
		children << view('', rect(text_x, layout.content_y, math.max(config.content_width, 0),
			math.max(config.content_height, 0)), BoxStyle{ transparent: true }, config.children)
	}
	surface := Element{
		...view(component_part_id(config.id, 'surface'), placement.frame, box, children)
		accessibility_role:  'tooltip'
		accessibility_label: [config.title, config.text, config.description].filter(it.len > 0).join('. ')
	}
	chrome := popover_chrome(placement, surface, depth, ComponentTheme{
		...config.theme
		background: bg
		border:     border
	})
	return component_finish(Element{
		...chrome
		id: config.id
	})
}
