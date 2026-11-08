module main

import ui2

// A gallery of the date and time components: calendar, date picker and time
// field. The application owns every state. Each component emits actions that
// its decoder turns into the next state, and on_key_event sends keys to the
// component the gallery treats as focused (the last one used): arrows, Page
// Up/Down, Home/End and Enter in a calendar, digits, arrows and Tab in a time
// field, Enter, Escape and the calendar keys in an open date picker.

const window_width = 1000
const window_height = 780
const col_a = 24.0
const col_b = 560.0

@[heap]
struct DatetimeDemo {
mut:
	today     ui2.CalendarDate
	focus     string = 'pick'
	single    ui2.CalendarState
	small     ui2.CalendarState
	range     ui2.CalendarState
	pick      ui2.CalendarState
	pick_open bool = true
	span      ui2.CalendarState
	span_open bool
	when      ui2.CalendarState
	when_open bool
	when_time ui2.TimeFieldState
	alarm     ui2.TimeFieldState
	meeting   ui2.TimeFieldState
	slot      ui2.TimeFieldState
	message   string = 'Click a component, then use the keyboard as well.'
}

const demo = &DatetimeDemo{}

const theme = ui2.component_theme(false)

fn app() &DatetimeDemo {
	return unsafe { demo }
}

fn window_size() (f64, f64) {
	b := ui2.bounds()
	if b.width > 0 && b.height > 0 {
		return b.width, b.height
	}
	return window_width, window_height
}

// ── Configurations, shared by the build and the event handlers ──────

fn single_config(a &DatetimeDemo) ui2.CalendarConfig {
	w, h := ui2.calendar_size(.medium, 1)
	return ui2.CalendarConfig{
		id:                  'single'
		frame:               ui2.rect(col_a, 140, w, h)
		state:               a.single
		today:               a.today
		disabled:            [ui2.calendar_disable_weekdays(0, 6)]
		accessibility_label: 'Delivery date'
		theme:               theme
	}
}

fn small_config(a &DatetimeDemo) ui2.CalendarConfig {
	w, h := ui2.calendar_size(.small, 1)
	return ui2.CalendarConfig{
		id:                'small'
		frame:             ui2.rect(296, 140, w, h)
		state:             a.small
		today:             a.today
		first_day_of_week: 1
		min:               a.today.add_days(-10)
		max:               a.today.add_months(2)
		size:              .small
		theme:             theme
	}
}

fn range_config(a &DatetimeDemo) ui2.CalendarConfig {
	w, h := ui2.calendar_size(.medium, 2)
	booked := [a.today.add_days(9), a.today.add_days(10)]
	return ui2.CalendarConfig{
		id:                  'range'
		frame:               ui2.rect(col_a, 458, w, h)
		state:               a.range
		mode:                .range
		months:              2
		today:               a.today
		show_outside_days:   false
		disabled:            [
			ui2.calendar_disable_if(fn [booked] (d ui2.CalendarDate) bool {
				return d in booked
			}),
		]
		accessibility_label: 'Stay'
		theme:               theme
	}
}

fn pick_config(a &DatetimeDemo) ui2.DatePickerConfig {
	ww, wh := window_size()
	return ui2.DatePickerConfig{
		id:                  'pick'
		frame:               ui2.rect(col_b, 272, 260, 32)
		calendar:            ui2.CalendarConfig{
			state:       a.pick
			today:       a.today
			fixed_weeks: true
		}
		open:                a.pick_open
		window_width:        ww
		window_height:       wh
		format:              '%B %-d, %Y'
		clearable:           true
		presets:             ui2.date_presets_recent(a.today)
		accessibility_label: 'Due date'
		theme:               theme
	}
}

fn span_config(a &DatetimeDemo) ui2.DatePickerConfig {
	ww, wh := window_size()
	return ui2.DatePickerConfig{
		id:                  'span'
		frame:               ui2.rect(col_b, 140, 300, 32)
		calendar:            ui2.CalendarConfig{
			state:             a.span
			mode:              .range
			months:            2
			today:             a.today
			show_outside_days: false
			fixed_weeks:       true
		}
		open:                a.span_open
		window_width:        ww
		window_height:       wh
		placeholder:         'Select a period'
		clearable:           true
		presets:             ui2.date_range_presets_recent(a.today)
		accessibility_label: 'Report period'
		theme:               theme
	}
}

fn when_config(a &DatetimeDemo) ui2.DatePickerConfig {
	ww, wh := window_size()
	return ui2.DatePickerConfig{
		id:                  'when'
		frame:               ui2.rect(col_b, 206, 260, 32)
		calendar:            ui2.CalendarConfig{
			state:       a.when
			today:       a.today
			fixed_weeks: true
			min:         a.today
		}
		open:                a.when_open
		window_width:        ww
		window_height:       wh
		placeholder:         'Pick a date and time'
		with_time:           true
		time:                ui2.TimeFieldConfig{
			state:       a.when_time
			hour_cycle:  .h12
			minute_step: 5
		}
		accessibility_label: 'Meeting start'
		theme:               theme
	}
}

fn disabled_picker_config(a &DatetimeDemo) ui2.DatePickerConfig {
	return ui2.DatePickerConfig{
		id:       'locked'
		frame:    ui2.rect(836, 206, 140, 32)
		calendar: ui2.CalendarConfig{
			state: ui2.CalendarState{
				start: a.today
			}
		}
		format:   '%Y-%m-%d'
		enabled:  false
		theme:    theme
	}
}

fn alarm_config(a &DatetimeDemo) ui2.TimeFieldConfig {
	cfg := ui2.TimeFieldConfig{
		id:                  'alarm'
		state:               a.alarm
		accessibility_label: 'Alarm'
		theme:               theme
	}
	return ui2.TimeFieldConfig{
		...cfg
		frame: ui2.rect(col_b, 652, ui2.time_field_width(cfg), 32)
	}
}

fn meeting_config(a &DatetimeDemo) ui2.TimeFieldConfig {
	cfg := ui2.TimeFieldConfig{
		id:                  'meeting'
		state:               a.meeting
		precision:           .second
		hour_cycle:          .h12
		accessibility_label: 'Meeting'
		theme:               theme
	}
	return ui2.TimeFieldConfig{
		...cfg
		frame: ui2.rect(740, 652, ui2.time_field_width(cfg), 32)
	}
}

fn slot_config(a &DatetimeDemo) ui2.TimeFieldConfig {
	cfg := ui2.TimeFieldConfig{
		id:                  'slot'
		state:               a.slot
		minute_step:         15
		min:                 ui2.TimeOfDay{9, 0, 0}
		max:                 ui2.TimeOfDay{17, 0, 0}
		accessibility_label: 'Appointment'
		theme:               theme
	}
	return ui2.TimeFieldConfig{
		...cfg
		frame: ui2.rect(col_b, 722, ui2.time_field_width(cfg), 32)
	}
}

fn locked_time_config() ui2.TimeFieldConfig {
	cfg := ui2.TimeFieldConfig{
		id:       'locked_time'
		state:    ui2.TimeFieldState{
			time: ui2.TimeOfDay{12, 30, 0}
		}
		steppers: false
		enabled:  false
		size:     .small
		theme:    theme
	}
	return ui2.TimeFieldConfig{
		...cfg
		frame: ui2.rect(740, 726, ui2.time_field_width(cfg), 24)
	}
}

// ── Build ───────────────────────────────────────────────────────────

fn heading(title string, x f64, y f64) ui2.Element {
	return ui2.label('', title, ui2.rect(x, y, 400, 24), ui2.TextStyle{
		color: theme.foreground
		size:  16
		bold:  true
	})
}

fn caption(content string, x f64, y f64, width f64) ui2.Element {
	return ui2.label('', content, ui2.rect(x, y, width, 18), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn date_text(d ?ui2.CalendarDate) string {
	if value := d {
		return ui2.calendar_format(value, '%a, %b %-d')
	}
	return 'none'
}

fn build() ui2.Element {
	a := app()
	mut c := []ui2.Element{}
	c << ui2.label('', 'Date and time', ui2.rect(col_a, 16, 600, 32), ui2.TextStyle{
		color: theme.foreground
		size:  22
		bold:  true
	})
	c << caption('Calendar, date picker and time field. The application owns every state.',
		col_a, 52, 500)

	c << heading('Calendar', col_a, 88)
	c << caption('Weekends disabled', col_a, 118, 248)
	c << caption('Small, Monday first, bounded', 296, 118, 240)
	c << ui2.calendar(single_config(a)) or { panic(err) }
	c << ui2.calendar(small_config(a)) or { panic(err) }
	c << caption('Range over two months: hover after the first day to preview', col_a, 436, 500)
	c << ui2.calendar(range_config(a)) or { panic(err) }
	c << caption('Delivery ${date_text(a.single.start)}. Stay ${date_text(a.range.start)} to ${date_text(a.range.end)}.',
		col_a, 744, 500)

	c << heading('Date picker', col_b, 88)
	c << caption('Range with presets', col_b, 118, 300)
	c << ui2.date_picker(span_config(a)) or { panic(err) }
	c << caption('Date and time, from today', col_b, 184, 260)
	c << caption('Disabled', 836, 184, 140)
	c << ui2.date_picker(when_config(a)) or { panic(err) }
	c << ui2.date_picker(disabled_picker_config(a)) or { panic(err) }
	c << caption('Single date with presets and a clear button', col_b, 250, 400)
	c << ui2.date_picker(pick_config(a)) or { panic(err) }

	c << heading('Time field', col_b, 600)
	c << caption('24-hour', col_b, 630, 160)
	c << caption('12-hour with seconds', 740, 630, 220)
	c << ui2.time_field(alarm_config(a)) or { panic(err) }
	c << ui2.time_field(meeting_config(a)) or { panic(err) }
	c << caption('15-minute steps, 9 to 5', col_b, 700, 170)
	c << caption('Disabled', 740, 704, 160)
	c << ui2.time_field(slot_config(a)) or { panic(err) }
	c << ui2.time_field(locked_time_config()) or { panic(err) }
	c << ui2.label('', a.message, ui2.rect(col_b, 52, 416, 20), ui2.TextStyle{
		color: theme.primary
		size:  13
	})

	// The overlays go last so an open popover draws over everything else.
	c << ui2.date_picker_overlay(span_config(a)) or { panic(err) }
	c << ui2.date_picker_overlay(when_config(a)) or { panic(err) }
	c << ui2.date_picker_overlay(pick_config(a)) or { panic(err) }
	return ui2.screen(theme.background, c)
}

// ── Events ──────────────────────────────────────────────────────────

// focus_on moves the gallery's keyboard focus to a component, dropping the
// focus ring or segment highlight of the one that had it.
fn focus_on(mut a DatetimeDemo, name string) {
	if a.focus == name {
		return
	}
	match a.focus {
		'single' { a.single = a.single.blurred() }
		'small' { a.small = a.small.blurred() }
		'range' { a.range = a.range.blurred() }
		'alarm' { a.alarm = a.alarm.blurred() }
		'meeting' { a.meeting = a.meeting.blurred() }
		'slot' { a.slot = a.slot.blurred() }
		else {}
	}
	a.focus = name
}

fn describe(ev ui2.CalendarEvent, what string) string {
	return match ev.kind {
		.select {
			if ev.complete {
				'${what}: picked ${ui2.calendar_format(ev.date, '%A, %B %-d, %Y')}.'
			} else {
				'${what}: range starts ${ui2.calendar_format(ev.date, '%b %-d')}; pick its last day.'
			}
		}
		.navigate {
			'${what}: showing ${ui2.calendar_month_name(ev.state.month.month)} ${ev.state.month.year}.'
		}
		else {
			''
		}
	}
}

fn apply_calendar(mut a DatetimeDemo, name string, ev ui2.CalendarEvent) {
	// The pointer passing over a calendar does not take the keyboard focus.
	if ev.kind != .hover {
		focus_on(mut a, name)
	}
	match name {
		'single' { a.single = ev.state }
		'small' { a.small = ev.state }
		else { a.range = ev.state }
	}
	text := describe(ev, name)
	if text.len > 0 {
		a.message = text
	}
}

fn apply_picker(mut a DatetimeDemo, name string, ev ui2.DatePickerEvent) {
	focus_on(mut a, name)
	match name {
		'pick' {
			a.pick = ev.state
			a.pick_open = ev.open
		}
		'span' {
			a.span = ev.state
			a.span_open = ev.open
		}
		else {
			a.when = ev.state
			a.when_open = ev.open
			a.when_time = ev.time
		}
	}
	if ev.kind == .select {
		cfg := match name {
			'pick' { pick_config(a) }
			'span' { span_config(a) }
			else { when_config(a) }
		}
		a.message = 'Picked ${ui2.date_picker_text(cfg)}.'
	} else if ev.kind == .clear {
		a.message = 'Cleared.'
	}
}

fn apply_time(mut a DatetimeDemo, name string, ev ui2.TimeFieldEvent) {
	focus_on(mut a, name)
	match name {
		'alarm' { a.alarm = ev.state }
		'meeting' { a.meeting = ev.state }
		else { a.slot = ev.state }
	}
	if ev.kind == .change {
		a.message = '${name} set to ${ev.state.time}.'
	}
}

fn handle_event(action string) {
	mut a := app()
	if ev := ui2.date_picker_event(pick_config(a), action) {
		apply_picker(mut a, 'pick', ev)
	} else if ev := ui2.date_picker_event(span_config(a), action) {
		apply_picker(mut a, 'span', ev)
	} else if ev := ui2.date_picker_event(when_config(a), action) {
		apply_picker(mut a, 'when', ev)
	} else if ev := ui2.calendar_event(single_config(a), action) {
		apply_calendar(mut a, 'single', ev)
	} else if ev := ui2.calendar_event(small_config(a), action) {
		apply_calendar(mut a, 'small', ev)
	} else if ev := ui2.calendar_event(range_config(a), action) {
		apply_calendar(mut a, 'range', ev)
	} else if ev := ui2.time_field_event(alarm_config(a), action) {
		apply_time(mut a, 'alarm', ev)
	} else if ev := ui2.time_field_event(meeting_config(a), action) {
		apply_time(mut a, 'meeting', ev)
	} else if ev := ui2.time_field_event(slot_config(a), action) {
		apply_time(mut a, 'slot', ev)
	} else {
		return
	}
	ui2.refresh()
}

// time_order is the order Tab moves through the time fields in.
const time_order = ['alarm', 'meeting', 'slot']

fn handle_key(event ui2.KeyEvent) {
	mut a := app()
	name := a.focus
	match name {
		'single', 'small', 'range' {
			cfg := match name {
				'single' { single_config(a) }
				'small' { small_config(a) }
				else { range_config(a) }
			}
			ev := ui2.calendar_key_event(cfg, event) or { return }
			apply_calendar(mut a, name, ev)
		}
		'pick', 'span', 'when' {
			cfg := match name {
				'pick' { pick_config(a) }
				'span' { span_config(a) }
				else { when_config(a) }
			}
			ev := ui2.date_picker_key_event(cfg, event) or { return }
			apply_picker(mut a, name, ev)
		}
		'alarm', 'meeting', 'slot' {
			cfg := match name {
				'alarm' { alarm_config(a) }
				'meeting' { meeting_config(a) }
				else { slot_config(a) }
			}
			if ev := ui2.time_field_key_event(cfg, event) {
				apply_time(mut a, name, ev)
			} else if event.code == .tab {
				// Tab past the last segment moves on to the next field.
				index := time_order.index(name) + if event.shift { -1 } else { 1 }
				if index < 0 || index >= time_order.len {
					return
				}
				next := time_order[index]
				focus_on(mut a, next)
				match next {
					'alarm' {
						a.alarm = ui2.TimeFieldState{
							...a.alarm
							focused: true
						}
					}
					'meeting' {
						a.meeting = ui2.TimeFieldState{
							...a.meeting
							focused: true
						}
					}
					else {
						a.slot = ui2.TimeFieldState{
							...a.slot
							focused: true
						}
					}
				}
			} else {
				return
			}
		}
		else {
			return
		}
	}
	ui2.consume_key()
	ui2.refresh()
}

fn main() {
	mut a := app()
	today := ui2.calendar_today()
	a.today = today
	a.single = ui2.CalendarState{
		start: today.add_days(2)
	}
	a.range = ui2.CalendarState{
		start: today.add_days(3)
		end:   today.add_days(7)
	}
	a.pick = ui2.CalendarState{
		start: today.add_days(5)
	}
	a.span = ui2.CalendarState{
		start: today.add_days(-6)
		end:   today
	}
	a.when_time = ui2.TimeFieldState{
		time: ui2.TimeOfDay{14, 30, 0}
	}
	a.alarm = ui2.TimeFieldState{
		time: ui2.TimeOfDay{7, 45, 0}
	}
	a.meeting = ui2.TimeFieldState{
		time: ui2.TimeOfDay{15, 5, 30}
	}
	a.slot = ui2.TimeFieldState{
		time: ui2.TimeOfDay{10, 30, 0}
	}
	ui2.on_key_event(handle_key)
	ui2.run_window('GPUI Kit date and time', window_width, window_height, build, handle_event)
}
