// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// The range-selection rule in calendar_select (a day before the start of an
// open range starts a new range, any other day closes it) and the four kinds
// of disabled-day matcher (weekdays, inside a range, outside an interval, a
// predicate) follow gpui-kit crates/base/src/calendar.rs, as does the
// days/months/years view model with twenty-year pages. Date arithmetic,
// layout, rendering, keyboard movement, hover preview and action decoding are
// new UI2 implementations. See third_party/gpui-kit.
module ui2

import math

pub const calendar_year_page_size = 20
pub const calendar_max_months = 12

pub enum CalendarMode {
	single // One date, in state.start.
	range  // state.start to state.end; end stays none until it is picked.
}

pub enum CalendarView {
	days   // The month grid.
	months // The twelve months of the visible year.
	years  // A page of twenty years.
}

// CalendarState is everything a calendar shows that changes while it is used.
// The application owns it: store the state an event returns and rebuild.
pub struct CalendarState {
pub:
	month     CalendarMonth // First visible month. The zero value shows start's month, or today's.
	view      CalendarView
	year_page int           // First year of the years view's page; 0 shows the page holding the visible year.
	start     ?CalendarDate // The selected date, or the first day of a range.
	end       ?CalendarDate // Range mode: the last day of the range.
	focused   ?CalendarDate // The day keyboard navigation is on, drawn with a ring.
	hovered   ?CalendarDate // The day under the pointer: a hover fill, and the preview of a range.
}

// blurred drops the keyboard ring and the hover state, for when the
// application moves its notion of focus elsewhere.
pub fn (s CalendarState) blurred() CalendarState {
	return CalendarState{
		...s
		focused: none
		hovered: none
	}
}

// is_complete reports whether a selection is finished: a date in single mode,
// both ends in range mode.
pub fn (s CalendarState) is_complete(mode CalendarMode) bool {
	if mode == .single {
		return s.start != none
	}
	return s.start != none && s.end != none
}

pub type CalendarPredicate = fn (CalendarDate) bool

pub enum CalendarMatcherKind {
	weekdays  // Every date on one of the listed weekdays (0 is Sunday).
	dates     // The listed dates.
	range     // Dates from `from` to `to`, both included; an open end is unbounded.
	outside   // Dates before `from` or after `to`.
	predicate // Dates the predicate returns true for.
}

// CalendarMatcher describes disabled days. Build one with
// calendar_disable_weekdays, calendar_disable_dates, calendar_disable_range,
// calendar_disable_outside or calendar_disable_if, and list as many as needed
// in CalendarConfig.disabled.
pub struct CalendarMatcher {
pub:
	kind      CalendarMatcherKind
	weekdays  []int
	dates     []CalendarDate
	from      ?CalendarDate
	to        ?CalendarDate
	predicate CalendarPredicate = unsafe { nil }
}

pub fn calendar_disable_weekdays(weekdays ...int) CalendarMatcher {
	return CalendarMatcher{
		kind:     .weekdays
		weekdays: weekdays
	}
}

pub fn calendar_disable_dates(dates ...CalendarDate) CalendarMatcher {
	return CalendarMatcher{
		kind:  .dates
		dates: dates
	}
}

// calendar_disable_range disables from..to, both included. Pass none for an
// open end: calendar_disable_range(none, yesterday) disables the past.
pub fn calendar_disable_range(from ?CalendarDate, to ?CalendarDate) CalendarMatcher {
	return CalendarMatcher{
		kind: .range
		from: from
		to:   to
	}
}

// calendar_disable_outside disables everything before from and after to, so
// only the interval between them stays selectable.
pub fn calendar_disable_outside(from ?CalendarDate, to ?CalendarDate) CalendarMatcher {
	return CalendarMatcher{
		kind: .outside
		from: from
		to:   to
	}
}

// calendar_disable_if disables the dates predicate returns true for. A closure
// can capture what it needs: `fn [holidays] (d ui2.CalendarDate) bool { return d in holidays }`.
pub fn calendar_disable_if(predicate CalendarPredicate) CalendarMatcher {
	return CalendarMatcher{
		kind:      .predicate
		predicate: predicate
	}
}

// matches reports whether the matcher disables date.
pub fn (m CalendarMatcher) matches(date CalendarDate) bool {
	match m.kind {
		.weekdays {
			return date.weekday() in m.weekdays
		}
		.dates {
			return date in m.dates
		}
		.range {
			if from := m.from {
				if date < from {
					return false
				}
			}
			if to := m.to {
				if to < date {
					return false
				}
			}
			return true
		}
		.outside {
			if from := m.from {
				if date < from {
					return true
				}
			}
			if to := m.to {
				if to < date {
					return true
				}
			}
			return false
		}
		.predicate {
			if voidptr(m.predicate) == unsafe { nil } {
				return false
			}
			return m.predicate(date)
		}
	}
}

pub struct CalendarConfig {
pub:
	id                  string
	frame               Rect
	state               CalendarState
	mode                CalendarMode
	months              int = 1 // Months side by side, 1 to 12.
	first_day_of_week   int           // 0 for Sunday (the default), 1 for Monday, ... 6.
	today               ?CalendarDate // The day marked as today; none reads the system date.
	min                 ?CalendarDate // Earliest selectable day; also stops navigation.
	max                 ?CalendarDate // Latest selectable day; also stops navigation.
	disabled            []CalendarMatcher
	year_from           int // First year of the years view; 0 is fifty years before today.
	year_to             int // Year after the last one in the years view; 0 is fifty years after today.
	show_outside_days   bool = true // Fill the grid with the days of the months around.
	fixed_weeks         bool // Always six weeks, so grids of different months line up.
	hover               bool = true // Report the hovered day: a hover fill and a range preview.
	bordered            bool = true // Draw the calendar's own border and background.
	month_names         []string // Twelve names to show instead of the English ones.
	weekday_names       []string // Seven column headings, Sunday first, instead of Su..Sa.
	enabled             bool = true
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub enum CalendarEventKind {
	select   // A day was picked; the state holds the new selection.
	navigate // The visible month or year page changed.
	view     // The calendar switched between its days, months and years views.
	focus    // Keyboard navigation moved to another day.
	hover    // The pointer moved onto a day or off it.
}

// CalendarEvent is a decoded request. Store `state` and rebuild; the other
// fields say what happened.
pub struct CalendarEvent {
pub:
	kind     CalendarEventKind
	date     CalendarDate // The day picked, focused or hovered; zero for navigation.
	complete bool         // select: the selection is finished (see CalendarState.is_complete).
	state    CalendarState
}

pub fn calendar_day_action_id(id string, date CalendarDate) string {
	return component_part_id(id, 'day:' + date.str())
}

fn calendar_month_count(months int) int {
	return int(math.max(1, math.min(months, calendar_max_months)))
}

fn calendar_validate(config CalendarConfig) ! {
	if config.months < 1 || config.months > calendar_max_months {
		return error('calendar months must be 1 to ${calendar_max_months}')
	}
	if config.first_day_of_week < 0 || config.first_day_of_week > 6 {
		return error('calendar first_day_of_week must be 0 (Sunday) to 6 (Saturday)')
	}
	if config.month_names.len != 0 && config.month_names.len != 12 {
		return error('calendar month_names must list twelve names')
	}
	if config.weekday_names.len != 0 && config.weekday_names.len != 7 {
		return error('calendar weekday_names must list seven names, Sunday first')
	}
	if lo := config.min {
		if !lo.is_valid() {
			return error('calendar min ${lo} is not a valid date')
		}
		if hi := config.max {
			if hi < lo {
				return error('calendar min must not be after max')
			}
		}
	}
	if hi := config.max {
		if !hi.is_valid() {
			return error('calendar max ${hi} is not a valid date')
		}
	}
}

fn calendar_today_of(config CalendarConfig) CalendarDate {
	return config.today or { calendar_today() }
}

// calendar_bounds is the first and last selectable day: min and max, kept
// within the years 1 to 9999.
fn calendar_bounds(config CalendarConfig) (CalendarDate, CalendarDate) {
	mut lo := CalendarDate{calendar_min_year, 1, 1}
	mut hi := CalendarDate{calendar_max_year, 12, 31}
	if m := config.min {
		if lo < m {
			lo = m
		}
	}
	if m := config.max {
		if m < hi {
			hi = m
		}
	}
	return lo, hi
}

fn calendar_clamp(config CalendarConfig, date CalendarDate) CalendarDate {
	lo, hi := calendar_bounds(config)
	return if date < lo {
		lo
	} else if hi < date {
		hi
	} else {
		date
	}
}

// calendar_date_disabled reports whether a day cannot be picked: before min,
// after max, or matched by one of the disabled matchers.
pub fn calendar_date_disabled(config CalendarConfig, date CalendarDate) bool {
	lo, hi := calendar_bounds(config)
	if date < lo || hi < date {
		return true
	}
	for matcher in config.disabled {
		if matcher.matches(date) {
			return true
		}
	}
	return false
}

// calendar_month_showing is the first visible month after making date
// visible: unchanged when it already is, otherwise moved just far enough.
fn calendar_month_showing(first CalendarMonth, count int, date CalendarDate) CalendarMonth {
	target := date.year_month()
	if target < first {
		return target
	}
	last := first.add(count - 1)
	if last < target {
		return target.add(1 - count)
	}
	return first
}

// calendar_first_month is the first visible month: the state's, or else the
// month of the selection or of today, kept within min and max.
fn calendar_first_month(config CalendarConfig) CalendarMonth {
	if config.state.month.is_valid() {
		return config.state.month
	}
	count := calendar_month_count(config.months)
	anchor := config.state.start or { calendar_today_of(config) }
	mut first := anchor.year_month()
	lo, hi := calendar_bounds(config)
	if hi.year_month() < first.add(count - 1) {
		first = hi.year_month().add(1 - count)
	}
	if first < lo.year_month() {
		first = lo.year_month()
	}
	return first
}

// calendar_resolved_state is the state with its first visible month filled in.
fn calendar_resolved_state(config CalendarConfig) CalendarState {
	return CalendarState{
		...config.state
		month: calendar_first_month(config)
	}
}

// calendar_visible_months lists the months a calendar shows, left to right.
pub fn calendar_visible_months(config CalendarConfig) []CalendarMonth {
	first := calendar_first_month(config)
	return []CalendarMonth{len: calendar_month_count(config.months), init: first.add(index)}
}

// calendar_shift_allowed reports whether the view can move by delta months:
// the month it would reveal must not lie wholly before min or after max.
fn calendar_shift_allowed(config CalendarConfig, first CalendarMonth, delta int) bool {
	if delta == 0 {
		return false
	}
	count := calendar_month_count(config.months)
	lo, hi := calendar_bounds(config)
	moved := first.add(delta)
	if delta < 0 {
		return !(moved < lo.year_month())
	}
	return !(hi.year_month() < moved.add(count - 1))
}

// calendar_year_range is the years the years view offers, [from, to).
fn calendar_year_range(config CalendarConfig) (int, int) {
	today := calendar_today_of(config)
	mut from := if config.year_from > 0 { config.year_from } else { today.year - 50 }
	mut to := if config.year_to > 0 { config.year_to } else { today.year + 50 }
	lo, hi := calendar_bounds(config)
	from = int(math.max(from, lo.year))
	to = int(math.min(to, hi.year + 1))
	if to <= from {
		to = from + 1
	}
	return from, to
}

// calendar_year_page_start is the first year of the years view's page: the
// state's when it is a page of the range, else the page holding year.
fn calendar_year_page_start(config CalendarConfig, st CalendarState) int {
	from, to := calendar_year_range(config)
	if st.year_page >= from && st.year_page < to
		&& (st.year_page - from) % calendar_year_page_size == 0 {
		return st.year_page
	}
	pages := (to - from + calendar_year_page_size - 1) / calendar_year_page_size
	page := int(math.max(0, math.min((st.month.year - from) / calendar_year_page_size, pages - 1)))
	return from + page * calendar_year_page_size
}

// calendar_date_visible reports whether the days view shows date, as a day of
// a visible month or, when outside days are shown, in one of their grids.
fn calendar_date_visible(config CalendarConfig, st CalendarState, date CalendarDate) bool {
	if st.view != .days || !date.is_valid() {
		return false
	}
	count := calendar_month_count(config.months)
	first := st.month
	last := first.add(count - 1)
	if !config.show_outside_days {
		target := date.year_month()
		return !(target < first) && !(last < target)
	}
	first_weeks := calendar_month_weeks(first, config.first_day_of_week, config.fixed_weeks)
	last_weeks := calendar_month_weeks(last, config.first_day_of_week, config.fixed_weeks)
	grid_start := first_weeks[0][0]
	grid_end := last_weeks[last_weeks.len - 1][6]
	return !(date < grid_start) && !(grid_end < date)
}

// calendar_select applies a pick of date to the selection and returns the
// state to store, or none when date cannot be picked or nothing would change.
// Single mode replaces the date. Range mode starts a range, or closes the open
// one when date is not before its start; a date before the start, or any date
// once both ends are set, starts a new range. The view moves only when date is
// not on screen.
pub fn calendar_select(config CalendarConfig, date CalendarDate) ?CalendarState {
	if !config.enabled || !date.is_valid() || calendar_date_disabled(config, date) {
		return none
	}
	st := calendar_resolved_state(config)
	mut start := st.start
	mut end := st.end
	if config.mode == .single {
		if s := st.start {
			if s == date {
				return none
			}
		}
		start = date
		end = none
	} else {
		mut closes := false
		if s := st.start {
			closes = st.end == none && !(date < s)
		}
		if closes {
			end = date
		} else {
			start = date
			end = none
		}
	}
	return CalendarState{
		...st
		month:   calendar_month_showing(st.month, calendar_month_count(config.months), date)
		view:    .days
		start:   start
		end:     end
		focused: date
	}
}

fn calendar_select_event(config CalendarConfig, date CalendarDate) ?CalendarEvent {
	next := calendar_select(config, date) or { return none }
	return CalendarEvent{
		kind:     .select
		date:     date
		complete: next.is_complete(config.mode)
		state:    next
	}
}

fn calendar_day_from_part(part string) ?CalendarDate {
	if !part.starts_with('day:') {
		return none
	}
	return calendar_parse_iso(part['day:'.len..])
}

// calendar_event decodes an action the calendar emitted against the config it
// was built with. It returns none for foreign, malformed and forged actions,
// everything while disabled, days that are disabled or not on screen, and
// actions that change nothing (picking the selected day in single mode,
// navigating past min or max).
pub fn calendar_event(config CalendarConfig, action string) ?CalendarEvent {
	if !config.enabled || config.id.len == 0 {
		return none
	}
	if pointer := parse_pointer_event(action) {
		return calendar_pointer_event(config, pointer)
	}
	part := component_action_part(config.id, action) or { return none }
	st := calendar_resolved_state(config)
	if part == 'previous' || part == 'next' {
		delta := if part == 'next' { 1 } else { -1 }
		if st.view == .days {
			if !calendar_shift_allowed(config, st.month, delta) {
				return none
			}
			return CalendarEvent{
				kind:  .navigate
				state: CalendarState{
					...st
					month:   st.month.add(delta)
					hovered: none
				}
			}
		}
		if st.view == .years {
			from, to := calendar_year_range(config)
			page := calendar_year_page_start(config, st) + delta * calendar_year_page_size
			if page < from || page >= to {
				return none
			}
			return CalendarEvent{
				kind:  .navigate
				state: CalendarState{
					...st
					year_page: page
				}
			}
		}
		return none
	}
	if part == 'view:months' || part == 'view:years' {
		target := if part == 'view:months' { CalendarView.months } else { CalendarView.years }
		next_view := if st.view == target { CalendarView.days } else { target }
		return CalendarEvent{
			kind:  .view
			state: CalendarState{
				...st
				view:      next_view
				year_page: if next_view == .years {
					calendar_year_page_start(config, CalendarState{
						...st
						year_page: 0
					})
				} else {
					st.year_page
				}
				hovered:   none
			}
		}
	}
	if date := calendar_day_from_part(part) {
		if !calendar_date_visible(config, st, date) {
			return none
		}
		return calendar_select_event(config, date)
	}
	if part.starts_with('month:') {
		month_number := component_parse_index(part['month:'.len..], 12) or { return none }
		if st.view != .months || month_number < 1 || !calendar_month_enabled(config,
			CalendarMonth{st.month.year, month_number}) {
			return none
		}
		return CalendarEvent{
			kind:  .navigate
			state: CalendarState{
				...st
				month: CalendarMonth{st.month.year, month_number}
				view:  .days
			}
		}
	}
	if part.starts_with('year:') {
		year := component_parse_index(part['year:'.len..], calendar_max_year) or { return none }
		page := calendar_year_page_start(config, st)
		from, to := calendar_year_range(config)
		if st.view != .years || year < page || year >= page + calendar_year_page_size
			|| year < from || year >= to {
			return none
		}
		return CalendarEvent{
			kind:  .navigate
			state: CalendarState{
				...st
				month: calendar_month_within(config, CalendarMonth{year, st.month.month})
				view:  .days
			}
		}
	}
	return none
}

// calendar_month_enabled reports whether any day of month can be picked
// under min and max.
fn calendar_month_enabled(config CalendarConfig, month CalendarMonth) bool {
	lo, hi := calendar_bounds(config)
	return !(month < lo.year_month()) && !(hi.year_month() < month)
}

// calendar_month_within moves month into the months min and max allow.
fn calendar_month_within(config CalendarConfig, month CalendarMonth) CalendarMonth {
	lo, hi := calendar_bounds(config)
	if month < lo.year_month() {
		return lo.year_month()
	}
	if hi.year_month() < month {
		return hi.year_month()
	}
	return month
}

fn calendar_pointer_event(config CalendarConfig, pointer PointerEvent) ?CalendarEvent {
	if pointer.phase != 'enter' && pointer.phase != 'leave' {
		return none
	}
	part := component_action_part(config.id, pointer.action) or { return none }
	date := calendar_day_from_part(part) or { return none }
	st := calendar_resolved_state(config)
	if pointer.phase == 'leave' {
		hovered := st.hovered or { return none }
		if hovered != date {
			return none
		}
		return CalendarEvent{
			kind:  .hover
			date:  date
			state: CalendarState{
				...st
				hovered: none
			}
		}
	}
	if !config.hover || !calendar_date_visible(config, st, date)
		|| calendar_date_disabled(config, date) {
		return none
	}
	if hovered := st.hovered {
		if hovered == date {
			return none
		}
	}
	return CalendarEvent{
		kind:  .hover
		date:  date
		state: CalendarState{
			...st
			hovered: date
		}
	}
}

fn datetime_plain_key(event KeyEvent) bool {
	return !event.ctrl && !event.alt && !event.cmd
}

// calendar_key_target is the day a navigation key moves to from date: the
// arrows by a day or a week, Page Up and Page Down by a month (a year with
// Shift), Home and End to the start and end of the week. Other keys, and
// arrows with modifiers, return none.
pub fn calendar_key_target(date CalendarDate, event KeyEvent, first_day_of_week int) ?CalendarDate {
	if !datetime_plain_key(event) {
		return none
	}
	if event.shift && event.code != .page_up && event.code != .page_down {
		return none
	}
	return match event.code {
		.left { date.add_days(-1) }
		.right { date.add_days(1) }
		.up { date.add_days(-7) }
		.down { date.add_days(7) }
		.page_up {
			if event.shift { date.add_years(-1) } else { date.add_months(-1) }
		}
		.page_down {
			if event.shift { date.add_years(1) } else { date.add_months(1) }
		}
		.home { date.week_start(first_day_of_week) }
		.end { date.week_end(first_day_of_week) }
		else { none }
	}
}

// calendar_focus_origin is where keyboard navigation starts: the selection if
// it is on screen, else today if it is, else the first day of the first month.
fn calendar_focus_origin(config CalendarConfig, st CalendarState) CalendarDate {
	if start := st.start {
		if calendar_date_visible(config, st, start) {
			return start
		}
	}
	today := calendar_today_of(config)
	if calendar_date_visible(config, st, today) {
		return today
	}
	return calendar_clamp(config, st.month.first_day())
}

// calendar_key_event decodes a key for a calendar the application treats as
// focused; call it from on_key_event and consume the key when it returns an
// event. In the days view the first navigation key shows the focus ring on
// the selected day (or today); later ones move it (see calendar_key_target),
// within min and max, turning the months to follow. Enter and Space pick the
// focused day. Escape returns from the months and years views. Everything else
// returns none, so the application can handle it.
pub fn calendar_key_event(config CalendarConfig, event KeyEvent) ?CalendarEvent {
	if !config.enabled || !datetime_plain_key(event) {
		return none
	}
	st := calendar_resolved_state(config)
	if st.view != .days {
		if event.code == .escape {
			return CalendarEvent{
				kind:  .view
				state: CalendarState{
					...st
					view: .days
				}
			}
		}
		return none
	}
	if event.code in [.enter, .kp_enter, .space] {
		focused := st.focused or { return none }
		return calendar_select_event(config, focused)
	}
	origin := calendar_focus_origin(config, st)
	mut target := origin
	if focused := st.focused {
		moved := calendar_key_target(focused, event, config.first_day_of_week) or { return none }
		target = calendar_clamp(config, moved)
		if target == focused {
			return none
		}
	} else {
		calendar_key_target(origin, event, config.first_day_of_week) or { return none }
	}
	return CalendarEvent{
		kind:  .focus
		date:  target
		state: CalendarState{
			...st
			month:   calendar_month_showing(st.month, calendar_month_count(config.months),
				target)
			focused: target
		}
	}
}

// ── Layout ──────────────────────────────────────────────────────────

struct CalendarMetrics {
	cell       f64 // Side of a day cell at the natural size.
	font       f64
	small      f64 // Weekday headings.
	pad        f64
	gap        f64 // Between months.
	header_gap f64
	weekday    f64 // Height of the weekday row.
	radius     f64
}

fn calendar_metrics(size ComponentSize) CalendarMetrics {
	metrics := component_metrics(size)
	cell := match size {
		.small { 28.0 }
		.medium { 32.0 }
		.large { 40.0 }
	}
	return CalendarMetrics{
		cell:       cell
		font:       metrics.font_size
		small:      math.max(11.0, metrics.font_size - 2)
		pad:        12
		gap:        16
		header_gap: 4
		weekday:    math.round(cell * 0.75)
		radius:     metrics.radius
	}
}

// calendar_size is the natural width and height of a calendar showing months
// months side by side at size: room for six weeks, so every month fits.
// Bigger frames spread the cells out; smaller ones shrink them.
pub fn calendar_size(size ComponentSize, months int) (f64, f64) {
	cm := calendar_metrics(size)
	count := calendar_month_count(months)
	width := 2 * cm.pad + f64(count) * 7 * cm.cell + f64(count - 1) * cm.gap
	height := 2 * cm.pad + cm.cell + cm.header_gap + cm.weekday + 6 * cm.cell
	return width, height
}

struct CalendarLayout {
	header  Rect   // The navigation row.
	body    Rect   // Everything below the header: the months and years grids.
	columns []Rect // One per visible month, from the weekday row down.
	weekday f64    // Height of the weekday row.
	cell_w  f64
	row_h   f64
	pill    f64 // Side of the rounded square a day is drawn in.
}

fn calendar_layout(config CalendarConfig) CalendarLayout {
	cm := calendar_metrics(config.size)
	count := calendar_month_count(config.months)
	w := config.frame.width
	h := config.frame.height
	pad := math.min(cm.pad, math.min(w, h) / 8)
	inner := rect(pad, pad, math.max(0.0, w - 2 * pad), math.max(0.0, h - 2 * pad))
	natural_w, natural_h := calendar_size(config.size, count)
	sx := math.min(1.0, inner.width / math.max(1.0, natural_w - 2 * cm.pad))
	sy := math.min(1.0, inner.height / math.max(1.0, natural_h - 2 * cm.pad))
	header_h := cm.cell * sy
	gap_y := cm.header_gap * sy
	weekday_h := cm.weekday * sy
	row_h := math.max(0.0, (inner.height - header_h - gap_y - weekday_h) / 6)
	gap_x := cm.gap * sx
	month_w := math.max(0.0, (inner.width - gap_x * f64(count - 1)) / f64(count))
	cell_w := month_w / 7
	top := inner.y + header_h + gap_y
	mut columns := []Rect{cap: count}
	for i in 0 .. count {
		columns << rect(inner.x + f64(i) * (month_w + gap_x), top, month_w, inner.y +
			inner.height - top)
	}
	return CalendarLayout{
		header:  rect(inner.x, inner.y, inner.width, header_h)
		body:    rect(inner.x, top, inner.width, math.max(0.0, inner.y + inner.height - top))
		columns: columns
		weekday: weekday_h
		cell_w:  cell_w
		row_h:   row_h
		pill:    math.max(0.0, math.min(math.min(cell_w, row_h) - 2, cm.cell * 1.5))
	}
}

// ── Day classification ──────────────────────────────────────────────

enum CalendarBand {
	none
	full  // Inside a range: the band crosses the whole cell.
	start // First day of a range: the band leaves to the right.
	end   // Last day of a range: the band comes in from the left.
}

// CalendarDayInfo is how one day cell is drawn.
struct CalendarDayInfo {
	date     CalendarDate
	outside  bool // Belongs to a neighbouring month.
	disabled bool
	selected bool // The single date, or an end of the range.
	today    bool
	focused  bool
	hovered  bool
	band     CalendarBand
	preview  bool // The band shows where the range would end if the hovered day were picked.
}

struct CalendarSpan {
	from    CalendarDate
	to      CalendarDate
	preview bool
}

// calendar_span is the range to draw: the selected one, or while only its
// start is picked, the one ending at the hovered day.
fn calendar_span(config CalendarConfig, st CalendarState) ?CalendarSpan {
	if config.mode != .range {
		return none
	}
	start := st.start or { return none }
	if end := st.end {
		return CalendarSpan{start, end, false}
	}
	hovered := st.hovered or { return none }
	if !config.hover || !(start < hovered) {
		return none
	}
	return CalendarSpan{start, hovered, true}
}

fn calendar_day_info(config CalendarConfig, st CalendarState, span ?CalendarSpan, date CalendarDate, month CalendarMonth, today CalendarDate) CalendarDayInfo {
	mut selected := false
	if start := st.start {
		selected = start == date
	}
	if end := st.end {
		selected = selected || end == date
	}
	mut band := CalendarBand.none
	mut preview := false
	if s := span {
		if s.from < s.to {
			preview = s.preview
			band = if date == s.from {
				CalendarBand.start
			} else if date == s.to {
				CalendarBand.end
			} else if s.from < date && date < s.to {
				CalendarBand.full
			} else {
				CalendarBand.none
			}
		}
	}
	mut focused := false
	if f := st.focused {
		focused = f == date
	}
	mut hovered := false
	if hv := st.hovered {
		hovered = hv == date
	}
	return CalendarDayInfo{
		date:     date
		outside:  date.year_month() != month
		disabled: calendar_date_disabled(config, date)
		selected: selected
		today:    date == today
		focused:  focused
		hovered:  hovered
		band:     band
		preview:  preview
	}
}

fn calendar_day_value(info CalendarDayInfo, mode CalendarMode) string {
	mut parts := []string{}
	if info.selected {
		parts << if mode == .range && info.band == .start {
			'range start'
		} else if mode == .range && info.band == .end {
			'range end'
		} else {
			'selected'
		}
	} else if info.band == .full && !info.preview {
		parts << 'in range'
	}
	if info.today {
		parts << 'today'
	}
	if info.disabled {
		parts << 'unavailable'
	}
	return parts.join(', ')
}

// ── Colors ──────────────────────────────────────────────────────────

fn calendar_band_color(theme ComponentTheme, preview bool) u32 {
	return choice_mix(theme.primary, theme.background, if preview { 0.9 } else { 0.8 })
}

fn calendar_hover_color(theme ComponentTheme) u32 {
	return choice_mix(theme.muted, theme.border, 0.45)
}

struct CalendarDayColors {
	fill      u32
	filled    bool
	ink       u32
	ring      u32
	ring_size f64
	bold      bool
}

fn calendar_day_colors(theme ComponentTheme, info CalendarDayInfo, enabled bool) CalendarDayColors {
	mut fill := u32(0)
	mut filled := false
	mut ink := if info.disabled || !enabled {
		choice_disabled_text(theme)
	} else if info.outside {
		theme.muted_foreground
	} else {
		theme.foreground
	}
	if info.selected {
		fill = if enabled {
			theme.primary
		} else {
			choice_mix(theme.primary, theme.background, 0.5)
		}
		filled = true
		ink = theme.primary_foreground
	} else if info.hovered && !info.disabled && enabled {
		fill = calendar_hover_color(theme)
		filled = true
	} else if info.today && info.band == .none {
		fill = theme.muted
		filled = true
	}
	return CalendarDayColors{
		fill:      fill
		filled:    filled
		ink:       ink
		ring:      if info.selected {
			choice_mix(theme.primary, theme.foreground, 0.45)
		} else {
			theme.primary
		}
		ring_size: if info.focused && enabled { 2.0 } else { 0.0 }
		bold:      info.selected || info.today
	}
}

// ── Elements ────────────────────────────────────────────────────────

fn calendar_month_title(config CalendarConfig, month int) string {
	return if config.month_names.len == 12 && month >= 1 && month <= 12 {
		config.month_names[month - 1]
	} else {
		calendar_month_name(month)
	}
}

fn calendar_month_short(config CalendarConfig, month int) string {
	return if config.month_names.len == 12 && month >= 1 && month <= 12 {
		config.month_names[month - 1]
	} else {
		calendar_month_short_name(month)
	}
}

fn calendar_weekday_title(config CalendarConfig, weekday int) string {
	return if config.weekday_names.len == 7 {
		config.weekday_names[weekday]
	} else {
		calendar_weekday_short_name(weekday)
	}
}

// calendar_ghost is a borderless clickable part: a rounded fill when filled,
// then the content on top.
fn calendar_ghost(id string, key string, frame Rect, fill u32, filled bool, radius f64, enabled bool, description string, value string, content []Element) Element {
	mut children := []Element{}
	if filled {
		children << view('', component_local(frame), BoxStyle{
			bg:     fill
			radius: radius
		}, []Element{})
	}
	children << content
	return Element{
		...button_view(id, frame, BoxStyle{ transparent: true }, children)
		key:                 key
		enabled:             enabled
		accessibility_label: description
		accessibility_value: value
	}
}

fn calendar_nav_button(config CalendarConfig, part string, symbol string, frame Rect, enabled bool, description string) Element {
	cm := calendar_metrics(config.size)
	theme := config.theme
	live := enabled && config.enabled
	color := if live { theme.foreground } else { choice_disabled_text(theme) }
	local := component_local(frame)
	icon := math.round(cm.font * 1.1)
	return Element{
		...button_view(component_part_id(config.id, part), frame, component_box(theme.background,
			if live { theme.border } else { choice_mix(theme.border, theme.background, 0.5) },
			cm.radius), [choice_icon(symbol, datetime_center(local, icon, icon), color)])
		key:                 part
		enabled:             live
		accessibility_label: description
	}
}

fn calendar_header(config CalendarConfig, st CalendarState, layout CalendarLayout) []Element {
	cm := calendar_metrics(config.size)
	theme := config.theme
	header := layout.header
	side := math.min(header.height, header.width / 4)
	y := header.y + (header.height - side) / 2
	mut prev_ok := false
	mut next_ok := false
	mut prev_label := 'Previous month'
	mut next_label := 'Next month'
	if st.view == .days {
		prev_ok = calendar_shift_allowed(config, st.month, -1)
		next_ok = calendar_shift_allowed(config, st.month, 1)
	} else if st.view == .years {
		from, to := calendar_year_range(config)
		page := calendar_year_page_start(config, st)
		prev_ok = page - calendar_year_page_size >= from
		next_ok = page + calendar_year_page_size < to
		prev_label = 'Previous years'
		next_label = 'Next years'
	}
	mut children := [
		calendar_nav_button(config, 'previous', 'chevron.left', rect(header.x, y, side,
			side), prev_ok, prev_label),
		calendar_nav_button(config, 'next', 'chevron.right', rect(header.x + header.width - side,
			y, side, side), next_ok, next_label),
	]
	count := calendar_month_count(config.months)
	if count > 1 && st.view == .days {
		for i, column in layout.columns {
			month := st.month.add(i)
			children << Element{
				...label('', '${calendar_month_title(config, month.month)} ${month.year}',
					rect(column.x + side, header.y, math.max(0.0, column.width - 2 * side),
						header.height), TextStyle{
						color: theme.foreground
						size:  cm.font
						bold:  true
						align: .center
					})
				key: 'title:${i}'
			}
		}
		return children
	}
	// One month, or a picker view: month and year toggles, side by side.
	month_text := calendar_month_title(config, st.month.month)
	year_text := st.month.year.str()
	pad := cm.font * 0.35
	month_w := component_text_width_estimate(month_text, cm.font) * 1.08 + 2 * pad
	year_w := component_text_width_estimate(year_text, cm.font) * 1.08 + 2 * pad
	room := math.max(0.0, header.width - 2 * side - 8)
	scale := if month_w + year_w > room && month_w + year_w > 0 {
		room / (month_w + year_w)
	} else {
		1.0
	}
	total := (month_w + year_w) * scale
	mut x := header.x + (header.width - total) / 2
	toggle_h := math.min(header.height, cm.cell)
	ty := header.y + (header.height - toggle_h) / 2
	pressed := choice_pressed(theme)
	for part in ['view:months', 'view:years'] {
		is_month := part == 'view:months'
		caption := if is_month { month_text } else { year_text }
		width := (if is_month { month_w } else { year_w }) * scale
		active := st.view == (if is_month { CalendarView.months } else { CalendarView.years })
		frame := rect(x, ty, width, toggle_h)
		children << calendar_ghost(component_part_id(config.id, part), part, frame, pressed,
			active, cm.radius, config.enabled, if is_month {
				'Choose month'
			} else {
				'Choose year'
			}, caption, [
				label('', caption, component_local(frame), TextStyle{
					color: if config.enabled {
						theme.foreground
					} else {
						choice_disabled_text(theme)
					}
					size:  cm.font
					bold:  true
					align: .center
				}),
			])
		x += width
	}
	return children
}

fn calendar_day_element(config CalendarConfig, info CalendarDayInfo, frame Rect, layout CalendarLayout, column int) Element {
	cm := calendar_metrics(config.size)
	theme := config.theme
	local := component_local(frame)
	pill := datetime_center(local, layout.pill, layout.pill)
	mut children := []Element{}
	band := calendar_band_color(theme, info.preview)
	half := local.width / 2
	match info.band {
		.full {
			children << view('', rect(0, pill.y, local.width, pill.height), BoxStyle{
				bg: band
			}, []Element{})
		}
		.start {
			children << view('', rect(half, pill.y, local.width - half, pill.height), BoxStyle{
				bg: band
			}, []Element{})
		}
		.end {
			children << view('', rect(0, pill.y, half, pill.height), BoxStyle{
				bg: band
			}, []Element{})
		}
		.none {}
	}
	colors := calendar_day_colors(theme, info, config.enabled)
	if colors.filled || colors.ring_size > 0 {
		radius := math.min(cm.radius, pill.width / 2)
		children << view('', pill, BoxStyle{
			bg:            colors.fill
			transparent:   !colors.filled
			radius:        radius
			border_color:  colors.ring
			border_left:   colors.ring_size
			border_top:    colors.ring_size
			border_right:  colors.ring_size
			border_bottom: colors.ring_size
		}, []Element{})
	}
	children << label('', info.date.day.str(), pill, TextStyle{
		color: colors.ink
		size:  cm.font
		bold:  colors.bold
		align: .center
	})
	part := 'day:${column}:${info.date}'
	enabled := config.enabled && !info.disabled
	return Element{
		...button_view(component_part_id(config.id, part), frame, BoxStyle{ transparent: true },
			children)
		key:                 part
		action_id:           calendar_day_action_id(config.id, info.date)
		enabled:             enabled
		hoverable:           enabled && config.hover
		accessibility_label: calendar_long_label(info.date)
		accessibility_value: calendar_day_value(info, config.mode)
	}
}

fn calendar_days_view(config CalendarConfig, st CalendarState, layout CalendarLayout) []Element {
	cm := calendar_metrics(config.size)
	theme := config.theme
	today := calendar_today_of(config)
	span := calendar_span(config, st)
	mut children := []Element{}
	for i, column in layout.columns {
		month := st.month.add(i)
		for c in 0 .. 7 {
			weekday := (config.first_day_of_week + c) % 7
			children << Element{
				...label('', calendar_weekday_title(config, weekday), rect(column.x +
					f64(c) * layout.cell_w, column.y, layout.cell_w, layout.weekday), TextStyle{
					color: theme.muted_foreground
					size:  cm.small
					align: .center
				})
				key:                 'weekday:${i}:${c}'
				accessibility_label: calendar_weekday_name(weekday)
			}
		}
		weeks := calendar_month_weeks(month, config.first_day_of_week, config.fixed_weeks)
		for r, week in weeks {
			for c, date in week {
				outside := date.year_month() != month
				if outside && !config.show_outside_days {
					continue
				}
				frame := rect(column.x + f64(c) * layout.cell_w, column.y + layout.weekday +
					f64(r) * layout.row_h, layout.cell_w, layout.row_h)
				info := calendar_day_info(config, st, span, date, month, today)
				children << calendar_day_element(config, info, frame, layout, i)
			}
		}
	}
	return children
}

// calendar_picker_grid lays out the months or years view: columns by rows of
// cells over the body, each a rounded button with its caption.
fn calendar_picker_grid(config CalendarConfig, layout CalendarLayout, columns int, rows int, captions []string, parts []string, selected int, enabled []bool, descriptions []string) []Element {
	cm := calendar_metrics(config.size)
	theme := config.theme
	body := layout.body
	cell_w := body.width / f64(columns)
	cell_h := body.height / f64(rows)
	mut children := []Element{}
	for index, caption in captions {
		cell := rect(body.x + f64(index % columns) * cell_w, body.y + f64(index / columns) * cell_h,
			cell_w, cell_h)
		frame := datetime_center(cell, cell_w - 2, math.min(cell_h - 6, cm.cell))
		is_selected := index == selected
		live := config.enabled && enabled[index]
		children << calendar_ghost(component_part_id(config.id, parts[index]), parts[index],
			frame, theme.primary, is_selected, cm.radius, live, descriptions[index], if is_selected {
				'selected'
			} else {
				''
			}, [
				label('', caption, component_local(frame), TextStyle{
					color: if is_selected {
						theme.primary_foreground
					} else if live {
						theme.foreground
					} else {
						choice_disabled_text(theme)
					}
					size:  cm.small
					bold:  is_selected
					align: .center
				}),
			])
	}
	return children
}

fn calendar_months_view(config CalendarConfig, st CalendarState, layout CalendarLayout) []Element {
	mut captions := []string{}
	mut parts := []string{}
	mut enabled := []bool{}
	mut descriptions := []string{}
	for m in 1 .. 13 {
		captions << calendar_month_short(config, m)
		parts << 'month:${m}'
		enabled << calendar_month_enabled(config, CalendarMonth{st.month.year, m})
		descriptions << '${calendar_month_title(config, m)} ${st.month.year}'
	}
	return calendar_picker_grid(config, layout, 3, 4, captions, parts, st.month.month - 1,
		enabled, descriptions)
}

fn calendar_years_view(config CalendarConfig, st CalendarState, layout CalendarLayout) []Element {
	from, to := calendar_year_range(config)
	page := calendar_year_page_start(config, st)
	mut captions := []string{}
	mut parts := []string{}
	mut enabled := []bool{}
	mut selected := -1
	for year in page .. page + calendar_year_page_size {
		if year < from || year >= to {
			continue
		}
		if year == st.month.year {
			selected = captions.len
		}
		captions << year.str()
		parts << 'year:${year}'
		enabled << true
	}
	return calendar_picker_grid(config, layout, 5, 4, captions, parts, selected, enabled,
		captions)
}

// calendar draws a month grid (or several side by side) with weekday headings,
// navigation, the selection, today and disabled days, plus the months and
// years views the header toggles open. It is controlled: decode its actions
// with calendar_event, keys with calendar_key_event, store the state they
// return and rebuild.
pub fn calendar(config CalendarConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	calendar_validate(config)!
	cm := calendar_metrics(config.size)
	theme := config.theme
	st := calendar_resolved_state(config)
	layout := calendar_layout(config)
	mut children := calendar_header(config, st, layout)
	children << match st.view {
		.days { calendar_days_view(config, st, layout) }
		.months { calendar_months_view(config, st, layout) }
		.years { calendar_years_view(config, st, layout) }
	}
	count := calendar_month_count(config.months)
	last := st.month.add(count - 1)
	shown := if count == 1 {
		'${calendar_month_title(config, st.month.month)} ${st.month.year}'
	} else {
		'${calendar_month_title(config, st.month.month)} ${st.month.year} to ${calendar_month_title(config, last.month)} ${last.year}'
	}
	box := if config.bordered {
		component_box(theme.background, theme.border, cm.radius + 2)
	} else {
		BoxStyle{
			transparent: true
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, box, children)
		accessibility_role:  'group'
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else {
			'Calendar'
		}
		accessibility_value: shown
	})
}
