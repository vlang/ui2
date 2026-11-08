module ui2

import math

// The date picker is two elements: date_picker, the trigger field, which goes
// wherever the form puts it, and date_picker_overlay, which the application
// adds last, after everything else, so the open popover draws on top. The
// overlay covers the window with a transparent backdrop that closes the
// popover on an outside click, and places the popover with
// date_picker_popover_frame, the one function that decides where it goes.

// DatePreset is a shortcut listed beside the calendar. In range mode a preset
// without an end selects its start alone; in single mode the end is ignored.
pub struct DatePreset {
pub:
	label string
	start CalendarDate
	end   ?CalendarDate
}

pub fn date_preset(caption string, date CalendarDate) DatePreset {
	return DatePreset{
		label: caption
		start: date
	}
}

pub fn date_range_preset(caption string, start CalendarDate, end CalendarDate) DatePreset {
	return DatePreset{
		label: caption
		start: start
		end:   end
	}
}

// date_presets_recent is Today, Yesterday and A week ago, counted from today.
pub fn date_presets_recent(today CalendarDate) []DatePreset {
	return [
		date_preset('Today', today),
		date_preset('Yesterday', today.add_days(-1)),
		date_preset('A week ago', today.add_days(-7)),
	]
}

// date_range_presets_recent is Today, Last 7 days, Last 30 days, This month
// and Last month, counted from today. Each range ends on or before today.
pub fn date_range_presets_recent(today CalendarDate) []DatePreset {
	this_month := today.year_month()
	last_month := this_month.add(-1)
	return [
		date_range_preset('Today', today, today),
		date_range_preset('Last 7 days', today.add_days(-6), today),
		date_range_preset('Last 30 days', today.add_days(-29), today),
		date_range_preset('This month', this_month.first_day(), today),
		date_range_preset('Last month', last_month.first_day(), last_month.last_day()),
	]
}

pub struct DatePickerConfig {
pub:
	id       string
	frame    Rect           // The trigger field.
	calendar CalendarConfig // Mode, state, months, bounds, disabled days, today; the picker sets its id, frame, size, theme, enabled and border.
	open     bool
	// The window the overlay covers to catch outside clicks, and keeps the
	// popover inside. ui2.bounds() returns it.
	window_width  f64
	window_height f64
	// The trigger in the overlay's (window) coordinates, when frame is relative
	// to a parent that is not at the window's origin. Defaults to frame.
	anchor              ?Rect
	format              string = '%Y/%m/%d' // See calendar_format.
	placeholder         string = 'Select a date'
	clearable           bool // Show a clear button while a date is selected.
	presets             []DatePreset
	with_time           bool            // Single mode: edit a time of day below the calendar too.
	time                TimeFieldConfig // State, precision, hour cycle, steps and bounds of that time; the picker sets the rest.
	enabled             bool = true
	invalid             bool // Draw the danger border.
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub enum DatePickerEventKind {
	open     // The trigger was pressed: the popover opens on the selection's month.
	close    // An outside click, Escape, Enter, or picking the selected day again.
	select   // A day or preset completed the selection; the popover closes unless it edits a time.
	clear    // The clear button emptied the selection.
	calendar // The calendar navigated, moved its focus or hover, or took the first end of a range.
	time     // The time changed, or its segment selection did.
}

// DatePickerEvent is a decoded request: store all three of open, state and
// time, then rebuild.
pub struct DatePickerEvent {
pub:
	kind  DatePickerEventKind
	open  bool
	state CalendarState  // The calendar's next state, selection included.
	time  TimeFieldState // The time field's next state; unchanged unless kind is .time.
}

fn date_picker_has_time(config DatePickerConfig) bool {
	return config.with_time && config.calendar.mode == .single
}

// date_picker_calendar is the calendar inside the popover, at frame.
fn date_picker_calendar(config DatePickerConfig, frame Rect) CalendarConfig {
	return CalendarConfig{
		...config.calendar
		id:       component_part_id(config.id, 'calendar')
		frame:    frame
		bordered: false
		enabled:  config.enabled
		size:     config.size
		theme:    config.theme
	}
}

fn date_picker_time(config DatePickerConfig, frame Rect) TimeFieldConfig {
	return TimeFieldConfig{
		...config.time
		id:      component_part_id(config.id, 'time')
		frame:   frame
		enabled: config.enabled
		size:    config.size
		theme:   config.theme
	}
}

fn date_picker_format(config DatePickerConfig) string {
	return if config.format.len > 0 { config.format } else { '%Y/%m/%d' }
}

// date_picker_text is what the trigger shows: the date, a range as
// `start – end` (`start – …` while its end is still to be picked), followed by
// the time when the picker edits one; '' with nothing selected.
pub fn date_picker_text(config DatePickerConfig) string {
	st := config.calendar.state
	start := st.start or { return '' }
	format := date_picker_format(config)
	if config.calendar.mode == .range {
		end := if e := st.end { calendar_format(e, format) } else { '…' }
		return '${calendar_format(start, format)} – ${end}'
	}
	if date_picker_has_time(config) {
		return calendar_format(start, format) + ' ' + time_format(config.time.state.time,
			config.time.precision, config.time.hour_cycle)
	}
	return calendar_format(start, format)
}

fn date_picker_shows_clear(config DatePickerConfig) bool {
	return config.clearable && config.enabled && config.calendar.state.start != none
}

// date_picker_opened is the calendar state a newly opened popover starts
// from: the days view of the selection's month (or today's), no focus ring.
fn date_picker_opened(config DatePickerConfig) CalendarState {
	return CalendarState{
		...config.calendar.state
		month:     CalendarMonth{}
		view:      .days
		year_page: 0
		focused:   none
		hovered:   none
	}
}

fn date_picker_result(kind DatePickerEventKind, open bool, next CalendarState, time_state TimeFieldState) DatePickerEvent {
	return DatePickerEvent{
		kind:  kind
		open:  open
		state: next
		time:  time_state
	}
}

// date_picker_from_calendar turns a calendar event into the picker's: a
// finished selection closes the popover unless a time is edited below it.
fn date_picker_from_calendar(config DatePickerConfig, ev CalendarEvent) DatePickerEvent {
	time_state := if ev.kind == .select { config.time.state.blurred() } else { config.time.state }
	if ev.kind == .select && ev.complete {
		keep_open := date_picker_has_time(config)
		return date_picker_result(.select, keep_open, if keep_open {
			ev.state
		} else {
			ev.state.blurred()
		}, time_state)
	}
	return date_picker_result(.calendar, true, ev.state, time_state)
}

fn date_picker_close(config DatePickerConfig) DatePickerEvent {
	return date_picker_result(.close, false, config.calendar.state.blurred(),
		config.time.state.blurred())
}

// date_picker_event decodes an action of the trigger, the overlay, the
// calendar or the time field inside it. It returns none for foreign and
// forged actions, everything while disabled, popover actions while it is
// closed, and actions that change nothing.
pub fn date_picker_event(config DatePickerConfig, action string) ?DatePickerEvent {
	if !config.enabled || config.id.len == 0 {
		return none
	}
	cal := date_picker_calendar(config, Rect{})
	if config.open {
		if ev := calendar_event(cal, action) {
			return date_picker_from_calendar(config, ev)
		}
		if date_picker_has_time(config) {
			if ev := time_field_event(date_picker_time(config, Rect{}), action) {
				return date_picker_result(.time, true, config.calendar.state.blurred(),
					ev.state)
			}
		}
	}
	part := component_action_part(config.id, action) or { return none }
	match part {
		'trigger' {
			if config.open {
				return date_picker_close(config)
			}
			return date_picker_result(.open, true, date_picker_opened(config),
				config.time.state)
		}
		'clear' {
			if !date_picker_shows_clear(config) {
				return none
			}
			return date_picker_clear(config)
		}
		'backdrop' {
			return if config.open { date_picker_close(config) } else { none }
		}
		else {}
	}
	if !config.open {
		return none
	}
	// Picking the selected day again confirms it, which the calendar itself
	// ignores as a no-op.
	if inner := component_action_part(cal.id, action) {
		if date := calendar_day_from_part(inner) {
			if start := config.calendar.state.start {
				if config.calendar.mode == .single && start == date
					&& calendar_date_visible(cal, calendar_resolved_state(cal), date) {
					return date_picker_close(config)
				}
			}
		}
		return none
	}
	if part.starts_with('preset:') {
		index := component_parse_index(part['preset:'.len..], config.presets.len - 1) or {
			return none
		}
		return date_picker_apply_preset(config, config.presets[index])
	}
	return none
}

fn date_picker_apply_preset(config DatePickerConfig, preset DatePreset) ?DatePickerEvent {
	cal := date_picker_calendar(config, Rect{})
	mut end := ?CalendarDate(none)
	if config.calendar.mode == .range {
		end = preset.end or { preset.start }
	}
	if !preset.start.is_valid() || calendar_date_disabled(cal, preset.start) {
		return none
	}
	if e := end {
		if !e.is_valid() || e < preset.start || calendar_date_disabled(cal, e) {
			return none
		}
	}
	st := calendar_resolved_state(cal)
	keep_open := date_picker_has_time(config)
	next := CalendarState{
		...st
		month:   calendar_month_showing(st.month, calendar_month_count(cal.months), preset.start)
		view:    .days
		start:   preset.start
		end:     end
		focused: none
		hovered: none
	}
	return date_picker_result(.select, keep_open, next, config.time.state.blurred())
}

// date_picker_clear is the event of the clear button: the selection emptied,
// the popover left as it is.
fn date_picker_clear(config DatePickerConfig) DatePickerEvent {
	return date_picker_result(.clear, config.open, CalendarState{
		...config.calendar.state
		start:   none
		end:     none
		focused: none
		hovered: none
	}, config.time.state)
}

// date_picker_key_event decodes a key for a picker the application treats as
// focused. Closed, Enter, Space and Down open it. Open, keys go to the time
// field while it is focused and to the calendar otherwise (see
// calendar_key_event and time_field_key_event); Tab moves between the two when
// there is a time; Escape and Enter close the popover once nothing inside
// uses them. Backspace and Delete clear a clearable picker, as its clear
// button does, unless the time field takes them. Other keys return none.
pub fn date_picker_key_event(config DatePickerConfig, event KeyEvent) ?DatePickerEvent {
	if !config.enabled || !datetime_plain_key(event) {
		return none
	}
	has_time := date_picker_has_time(config)
	time_keys := config.open && has_time && config.time.state.focused
	if event.code in [.backspace, .delete] && !time_keys {
		return if date_picker_shows_clear(config) { date_picker_clear(config) } else { none }
	}
	if !config.open {
		if event.code in [.enter, .kp_enter, .space, .down] && !event.shift {
			return date_picker_result(.open, true, date_picker_opened(config),
				config.time.state)
		}
		return none
	}
	if time_keys {
		tf := date_picker_time(config, Rect{})
		if ev := time_field_key_event(tf, event) {
			return date_picker_result(.time, true, config.calendar.state, ev.state)
		}
		if event.code == .tab {
			return date_picker_result(.calendar, true, config.calendar.state,
				config.time.state.blurred())
		}
	} else {
		cal := date_picker_calendar(config, Rect{})
		if ev := calendar_key_event(cal, event) {
			return date_picker_from_calendar(config, ev)
		}
		if event.code == .tab && has_time && !event.shift {
			return date_picker_result(.time, true, config.calendar.state.blurred(),
				TimeFieldState{
					...config.time.state
					focused: true
					pending: -1
				})
		}
	}
	if event.code in [.escape, .enter, .kp_enter] {
		return date_picker_close(config)
	}
	return none
}

// ── Popover geometry ────────────────────────────────────────────────

pub const date_picker_popover_gap = 4.0
pub const date_picker_popover_margin = 8.0

// date_picker_popover_frame places a popover of width by height for an anchor
// inside a window: below the anchor with their left edges aligned, or above it
// when it does not fit below but fits above; when it fits on neither side, on
// the side with more room, pushed into the window. It moves left as far as it
// must to stay inside the window, and keeps a margin from the window's edges.
// Pure and self-contained, this is the only placement logic the date picker
// has, so a shared popover can replace it.
pub fn date_picker_popover_frame(anchor Rect, width f64, height f64, window_width f64, window_height f64) Rect {
	// The shared positioner flips and shifts the same way every popover does.
	if placed := popover_place(PopoverPlacementConfig{
		anchor: anchor
		window: rect(0, 0, window_width, window_height)
		width:  width
		height: height
		side:   .bottom
		align:  .start
		offset: date_picker_popover_gap
		margin: date_picker_popover_margin
	})
	{
		return placed.frame
	}
	gap := date_picker_popover_gap
	margin := date_picker_popover_margin
	mut x := math.min(anchor.x, window_width - margin - width)
	x = math.max(x, margin)
	below := anchor.y + anchor.height + gap
	above := anchor.y - gap - height
	room_below := window_height - margin - below
	room_above := anchor.y - gap - margin
	y := if height <= room_below {
		below
	} else if height <= room_above {
		above
	} else if room_above > room_below {
		margin
	} else {
		math.max(margin, window_height - margin - height)
	}
	return rect(x, y, width, height)
}

struct DatePickerPopoverLayout {
	size       Rect   // Width and height of the popover.
	presets    []Rect // Popover-local.
	divider    Rect   // Between the presets and the calendar.
	calendar   Rect
	time_line  Rect // Above the time row.
	time_label Rect
	time       Rect
}

fn date_picker_preset_metrics(config DatePickerConfig) (f64, f64, f64) {
	metrics := component_metrics(config.size)
	cm := calendar_metrics(config.size)
	mut width := 0.0
	for preset in config.presets {
		width = math.max(width, component_text_width_estimate(preset.label, metrics.font_size))
	}
	return math.max(width + 2 * metrics.padding + 6, 96.0), cm.cell, 2.0
}

fn date_picker_popover_layout(config DatePickerConfig) DatePickerPopoverLayout {
	metrics := component_metrics(config.size)
	cm := calendar_metrics(config.size)
	cal_w, cal_h := calendar_size(config.size, config.calendar.months)
	mut x := 0.0
	mut presets := []Rect{}
	mut divider := Rect{}
	mut presets_h := 0.0
	if config.presets.len > 0 {
		preset_w, preset_h, preset_gap := date_picker_preset_metrics(config)
		for index in 0 .. config.presets.len {
			presets << rect(cm.pad - 4, cm.pad + f64(index) * (preset_h + preset_gap), preset_w,
				preset_h)
		}
		presets_h = 2 * cm.pad + f64(config.presets.len) * (preset_h + preset_gap) - preset_gap
		x = cm.pad - 4 + preset_w + cm.pad - 4
		divider = rect(x, 0, 1, 0)
		x += 1
	}
	calendar_frame := rect(x, 0, cal_w, cal_h)
	mut height := cal_h
	mut time_line := Rect{}
	mut time_label := Rect{}
	mut time_frame := Rect{}
	if date_picker_has_time(config) {
		row := metrics.height
		time_line = rect(x + cm.pad, cal_h, cal_w - 2 * cm.pad, 1)
		tw := time_field_width(date_picker_time(config, rect(0, 0, 0, row)))
		time_frame = rect(x + cal_w - cm.pad - tw, cal_h + 1 + cm.pad - 2, tw, row)
		time_label = rect(x + cm.pad, time_frame.y, math.max(0.0, time_frame.x - x - 2 * cm.pad),
			row)
		height = time_frame.y + row + cm.pad
	}
	height = math.max(height, presets_h)
	width := x + cal_w
	return DatePickerPopoverLayout{
		size:       rect(0, 0, width, height)
		presets:    presets
		divider:    if config.presets.len > 0 { rect(divider.x, 0, 1, height) } else { Rect{} }
		calendar:   calendar_frame
		time_line:  time_line
		time_label: time_label
		time:       time_frame
	}
}

// date_picker_popover_size is the width and height of the open popover.
pub fn date_picker_popover_size(config DatePickerConfig) (f64, f64) {
	layout := date_picker_popover_layout(config)
	return layout.size.width, layout.size.height
}

fn date_picker_anchor(config DatePickerConfig) Rect {
	return config.anchor or { config.frame }
}

// ── Elements ────────────────────────────────────────────────────────

fn date_picker_validate(config DatePickerConfig) ! {
	calendar_validate(date_picker_calendar(config, Rect{}))!
	if date_picker_has_time(config) {
		time_field_validate(date_picker_time(config, Rect{}))!
	}
	for preset in config.presets {
		if preset.label.trim_space().len == 0 {
			return error('date picker presets need a label')
		}
	}
}

// date_picker is the trigger: a field showing the selected date (or the
// placeholder) with a calendar icon, or a clear button while clearable and
// set. Pressing it emits an action date_picker_event decodes as .open. Add
// date_picker_overlay(config) after every other element for the popover.
pub fn date_picker(config DatePickerConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	date_picker_validate(config)!
	metrics := component_metrics(config.size)
	theme := config.theme
	w := config.frame.width
	h := config.frame.height
	value := date_picker_text(config)
	shows_clear := date_picker_shows_clear(config)
	icon_w := math.min(h, w / 3)
	icon := inputs_icon_size(metrics)
	ink := if !config.enabled {
		choice_disabled_text(theme)
	} else if value.len == 0 {
		theme.muted_foreground
	} else {
		theme.foreground
	}
	trigger_w := if shows_clear { w - icon_w } else { w }
	text_x := math.min(metrics.padding + 2, trigger_w / 2)
	mut trigger_children := [
		label('', if value.len > 0 { value } else { config.placeholder }, rect(text_x, 0,
			math.max(0.0, w - icon_w - text_x), h), TextStyle{
			color: ink
			size:  metrics.font_size
		}),
	]
	if !shows_clear {
		trigger_children << choice_icon('calendar', datetime_center(rect(w - icon_w, 0, icon_w,
			h), icon, icon), if config.enabled {
			theme.muted_foreground
		} else {
			choice_disabled_text(theme)
		})
	}
	description := if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else {
		config.placeholder
	}
	mut children := [
		Element{
			...button_view(component_part_id(config.id, 'trigger'), rect(0, 0, trigger_w, h),
				BoxStyle{ transparent: true }, trigger_children)
			key:                 'trigger'
			enabled:             config.enabled
			accessibility_role:  'combobox'
			accessibility_label: description
			accessibility_value: value
		},
	]
	if shows_clear {
		frame := rect(w - icon_w, 0, icon_w, h)
		children << Element{
			...button_view(component_part_id(config.id, 'clear'), frame, BoxStyle{
				transparent: true
			}, [
				choice_icon('xmark', datetime_center(component_local(frame), icon - 2, icon - 2),
					theme.muted_foreground),
			])
			key:                 'clear'
			tooltip:             'Clear'
			accessibility_label: 'Clear'
		}
	}
	border := if config.invalid {
		theme.danger
	} else if config.open && config.enabled {
		theme.primary
	} else {
		theme.border
	}
	return component_finish(Element{
		...view(config.id, config.frame, component_box(if config.enabled {
			theme.background
		} else {
			theme.muted
		}, border, metrics.radius), children)
		accessibility_role:  'group'
		accessibility_label: description
	})
}

fn date_picker_preset_element(config DatePickerConfig, index int, preset DatePreset, frame Rect) Element {
	metrics := component_metrics(config.size)
	theme := config.theme
	st := config.calendar.state
	mut current := false
	if start := st.start {
		if config.calendar.mode == .single {
			current = start == preset.start
		} else if end := st.end {
			current = start == preset.start && end == (preset.end or { preset.start })
		}
	}
	part := 'preset:${index}'
	return calendar_ghost(component_part_id(config.id, part), part, frame, choice_pressed(theme),
		current, metrics.radius, config.enabled, preset.label, if current {
			'selected'
		} else {
			''
		}, [
			label('', preset.label, rect(metrics.padding, 0, math.max(0.0, frame.width - metrics.padding),
				frame.height), TextStyle{
				color: theme.foreground
				size:  metrics.font_size
			}),
		])
}

// date_picker_overlay is the open popover: a transparent backdrop over the
// whole window (an outside click closes the popover), the popover's surface,
// and the presets, calendar and time field on it. Add it after every other
// element so it draws on top; while the picker is closed it is a hidden,
// empty view. It needs window_width and window_height.
pub fn date_picker_overlay(config DatePickerConfig) !Element {
	component_validate_id(config.id)!
	id := component_part_id(config.id, 'overlay')
	if !config.open || !config.enabled {
		return component_finish(Element{
			...view(id, rect(0, 0, 0, 0), BoxStyle{ transparent: true }, []Element{})
			hidden: true
		})
	}
	if !component_finite(config.window_width) || !component_finite(config.window_height)
		|| config.window_width <= 0 || config.window_height <= 0 {
		return error('an open date picker needs window_width and window_height')
	}
	date_picker_validate(config)!
	metrics := component_metrics(config.size)
	theme := config.theme
	layout := date_picker_popover_layout(config)
	frame := date_picker_popover_frame(date_picker_anchor(config), layout.size.width,
		layout.size.height, config.window_width, config.window_height)
	window := rect(0, 0, config.window_width, config.window_height)
	backdrop := Element{
		...button_view(component_part_id(config.id, 'backdrop'), window, BoxStyle{
			transparent: true
		}, []Element{})
		key:                 'backdrop'
		accessibility_role:  'presentation'
		accessibility_label: 'Close'
	}
	// The surface takes clicks between the controls, which would otherwise
	// reach the backdrop below and close the popover.
	surface := Element{
		...button_view(component_part_id(config.id, 'surface'), frame, BoxStyle{
			bg:            theme.background
			radius:        metrics.radius + 2
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			shadow:        box_shadow(0x000000, 0.16, 16, 6)
		}, []Element{})
		key:                 'surface'
		accessibility_role:  'presentation'
		accessibility_label: ''
	}
	mut content := []Element{}
	for index, preset in config.presets {
		content << date_picker_preset_element(config, index, preset, layout.presets[index])
	}
	if config.presets.len > 0 {
		content << Element{
			...view('', layout.divider, BoxStyle{
				bg: theme.border
			}, []Element{})
			key: 'divider'
		}
	}
	content << calendar(date_picker_calendar(config, layout.calendar))!
	if date_picker_has_time(config) {
		content << Element{
			...view('', layout.time_line, BoxStyle{
				bg: theme.border
			}, []Element{})
			key: 'time-line'
		}
		content << Element{
			...label('', 'Time', layout.time_label, TextStyle{
				color: theme.muted_foreground
				size:  metrics.font_size
			})
			key: 'time-label'
		}
		content << time_field(date_picker_time(config, layout.time))!
	}
	popover_el := Element{
		...view(component_part_id(config.id, 'popover'), frame, BoxStyle{ transparent: true },
			content)
		key:                 'popover'
		accessibility_role:  'dialog'
		accessibility_label: if config.calendar.mode == .range {
			'Choose dates'
		} else {
			'Choose date'
		}
	}
	return component_finish(view(id, window, BoxStyle{ transparent: true }, [
		backdrop,
		surface,
		popover_el,
	]))
}
