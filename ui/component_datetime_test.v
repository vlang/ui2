// SPDX-License-Identifier: Apache-2.0
// Includes month-grid, range-selection and time-segment cases adapted from
// GPUI Kit (Longbridge, copyright 2024 - 2026); the other tests are new. See
// third_party/gpui-kit.
module ui2

import time

fn dt_date(y int, m int, d int) CalendarDate {
	return calendar_date(y, m, d) or { panic(err) }
}

fn dt_hms(h int, m int, s int) TimeOfDay {
	return time_of_day(h, m, s) or { panic(err) }
}

fn dt_key(code KeyCode) KeyEvent {
	return KeyEvent{
		code: code
	}
}

fn dt_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := dt_find(child, id) {
			return found
		}
	}
	return none
}

fn dt_buttons(el Element) []Element {
	mut found := []Element{}
	if el.button_behavior {
		found << el
	}
	for child in el.children {
		found << dt_buttons(child)
	}
	return found
}

fn dt_labels(el Element) []string {
	mut found := []string{}
	if el.kind == .label {
		found << el.text
	}
	for child in el.children {
		found << dt_labels(child)
	}
	return found
}

fn dt_assert_inside(el Element) {
	for child in el.children {
		assert child.frame.x >= -1e-6 && child.frame.y >= -1e-6, '${child.id} starts outside ${el.id}'
		assert child.frame.x + child.frame.width <= el.frame.width + 1e-6, '${child.id} is wider than ${el.id}'
		assert child.frame.y + child.frame.height <= el.frame.height + 1e-6, '${child.id} is taller than ${el.id}'
		dt_assert_inside(child)
	}
}

// ── Dates ───────────────────────────────────────────────────────────

fn test_leap_years_and_month_lengths() {
	for year in [2000, 2024, 2400, 1600, 4] {
		assert calendar_is_leap_year(year), '${year}'
	}
	for year in [1900, 2100, 2023, 2025, 1] {
		assert !calendar_is_leap_year(year), '${year}'
	}
	assert [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map(calendar_days_in_month(2023, it)) == [
		31,
		28,
		31,
		30,
		31,
		30,
		31,
		31,
		30,
		31,
		30,
		31,
	]
	assert calendar_days_in_month(2024, 2) == 29
	assert calendar_days_in_month(1900, 2) == 28
	assert calendar_days_in_month(2000, 2) == 29
	assert calendar_days_in_month(2024, 0) == 0
	assert calendar_days_in_month(2024, 13) == 0
}

fn test_calendar_date_rejects_days_that_do_not_exist() {
	assert dt_date(2024, 2, 29).str() == '2024-02-29'
	for parts in [[2023, 2, 29], [2024, 4, 31], [2024, 1, 0], [2024, 0, 1], [2024, 13, 1], [0,
		1, 1], [10000, 1, 1], [1900, 2, 29]] {
		if _ := calendar_date(parts[0], parts[1], parts[2]) {
			assert false, '${parts} accepted'
		}
	}
	assert dt_date(1, 1, 1).is_valid()
	assert dt_date(9999, 12, 31).is_valid()
	assert !CalendarDate{}.is_valid()
}

fn test_serials_match_known_days_and_v_time() {
	assert dt_date(1970, 1, 1).serial() == 0
	assert dt_date(1969, 12, 31).serial() == -1
	assert dt_date(2000, 3, 1).serial() == 11017
	assert calendar_date_from_serial(0) == dt_date(1970, 1, 1)
	assert calendar_date_from_serial(-1) == dt_date(1969, 12, 31)
	for d in [dt_date(1, 1, 1), dt_date(1600, 2, 29), dt_date(1899, 12, 31), dt_date(2024, 2, 29),
		dt_date(9999, 12, 31)] {
		assert calendar_date_from_serial(d.serial()) == d
		assert d.serial() == time.days_from_unix_epoch(d.year, d.month, d.day), '${d}'
	}
	// Every day of two years around a leap day follows the day before it.
	mut previous := dt_date(2023, 6, 30)
	for _ in 0 .. 731 {
		next := previous.add_days(1)
		assert next.serial() == previous.serial() + 1
		assert next.is_valid()
		if next.day == 1 {
			assert previous.day == calendar_days_in_month(previous.year, previous.month)
		} else {
			assert next.day == previous.day + 1 && next.month == previous.month
		}
		previous = next
	}
}

fn test_weekdays_and_week_bounds() {
	assert dt_date(1970, 1, 1).weekday() == 4
	assert dt_date(2000, 1, 1).weekday() == 6
	assert dt_date(2024, 2, 29).weekday() == 4
	assert dt_date(2026, 10, 17).weekday() == 6
	assert dt_date(1, 1, 1).weekday() == 1
	assert dt_date(1969, 12, 28).weekday() == 0
	sat := dt_date(2026, 10, 17)
	assert sat.week_start(0) == dt_date(2026, 10, 11)
	assert sat.week_end(0) == dt_date(2026, 10, 17)
	assert sat.week_start(1) == dt_date(2026, 10, 12)
	assert sat.week_end(1) == dt_date(2026, 10, 18)
	assert dt_date(2026, 10, 11).week_start(0) == dt_date(2026, 10, 11)
	// A week can straddle a year boundary.
	assert dt_date(2026, 1, 1).week_start(1) == dt_date(2025, 12, 29)
}

fn test_date_arithmetic_across_month_and_year_boundaries() {
	assert dt_date(2024, 2, 28).add_days(1) == dt_date(2024, 2, 29)
	assert dt_date(2024, 2, 28).add_days(2) == dt_date(2024, 3, 1)
	assert dt_date(2023, 2, 28).add_days(1) == dt_date(2023, 3, 1)
	assert dt_date(2025, 12, 31).add_days(1) == dt_date(2026, 1, 1)
	assert dt_date(2026, 1, 1).add_days(-1) == dt_date(2025, 12, 31)
	assert dt_date(2024, 1, 31).add_months(1) == dt_date(2024, 2, 29)
	assert dt_date(2023, 1, 31).add_months(1) == dt_date(2023, 2, 28)
	assert dt_date(2024, 3, 31).add_months(-1) == dt_date(2024, 2, 29)
	assert dt_date(2025, 12, 15).add_months(1) == dt_date(2026, 1, 15)
	assert dt_date(2026, 1, 15).add_months(-1) == dt_date(2025, 12, 15)
	assert dt_date(2026, 1, 15).add_months(13) == dt_date(2027, 2, 15)
	assert dt_date(2026, 1, 15).add_months(-25) == dt_date(2023, 12, 15)
	assert dt_date(2024, 2, 29).add_years(1) == dt_date(2025, 2, 28)
	assert dt_date(2024, 2, 29).add_years(4) == dt_date(2028, 2, 29)
	assert dt_date(2024, 12, 31).day_of_year() == 366
	assert dt_date(2023, 12, 31).day_of_year() == 365
	assert dt_date(2024, 3, 1).day_of_year() == 61
	assert dt_date(2024, 1, 1).days_until(dt_date(2025, 1, 1)) == 366
	assert dt_date(2025, 1, 1).days_until(dt_date(2024, 1, 1)) == -366
}

fn test_dates_and_months_compare_in_time_order() {
	assert dt_date(2024, 2, 29) < dt_date(2024, 3, 1)
	assert dt_date(2023, 12, 31) < dt_date(2024, 1, 1)
	assert dt_date(2024, 3, 1) > dt_date(2024, 2, 29)
	assert dt_date(2024, 3, 1) >= dt_date(2024, 3, 1)
	assert !(dt_date(2024, 3, 1) < dt_date(2024, 3, 1))
	assert calendar_month(2026, 13) == CalendarMonth{2027, 1}
	assert calendar_month(2026, 0) == CalendarMonth{2025, 12}
	assert calendar_month(2026, -11) == CalendarMonth{2025, 1}
	assert calendar_month(2026, -12) == CalendarMonth{2024, 12}
	assert CalendarMonth{2025, 12}.add(1) == CalendarMonth{2026, 1}
	assert CalendarMonth{2026, 1}.add(-1) == CalendarMonth{2025, 12}
	assert CalendarMonth{2025, 12} < CalendarMonth{2026, 1}
	assert CalendarMonth{2024, 2}.last_day() == dt_date(2024, 2, 29)
	assert CalendarMonth{2026, 10}.str() == '2026-10'
}

fn test_iso_parsing_is_strict() {
	assert calendar_parse_iso('2024-02-29') or { panic('rejected') } == dt_date(2024, 2, 29)
	for source in ['2023-02-29', '2024-2-29', '24-02-29', '2024/02/29', '2024-02-2x', '', '+024-02-29',
		'2024-02-290', '0000-01-01', '2024-00-10'] {
		if d := calendar_parse_iso(source) {
			assert false, '${source} parsed as ${d}'
		}
	}
}

fn test_format_directives_and_names() {
	d := dt_date(2024, 2, 9)
	assert calendar_format(d, '%Y/%m/%d') == '2024/02/09'
	assert calendar_format(d, '%-m/%-d/%y') == '2/9/24'
	assert calendar_format(d, '%e|%j|%%') == ' 9|040|%'
	assert calendar_format(d, '%A, %B %-d') == 'Friday, February 9'
	assert calendar_format(d, '%a %b') == 'Fri Feb'
	assert calendar_format(d, 'x %q %') == 'x %q %'
	assert calendar_format(dt_date(5, 1, 1), '%Y') == '0005'
	assert calendar_month_name(13) == ''
	assert calendar_month_short_name(9) == 'Sep'
	assert calendar_weekday_short_name(0) == 'Su'
	assert calendar_weekday_name(7) == ''
	assert calendar_long_label(dt_date(2026, 10, 17)) == 'Saturday, October 17, 2026'
}

fn dt_grid(month CalendarMonth, first int, fixed bool) []string {
	return calendar_month_weeks(month, first, fixed).map(it.map(if it.year_month() == month {
		'${it.day:2}'
	} else {
		'${it.month}-${it.day}'
	}).join('|'))
}

fn test_month_weeks_match_upstream_grids() {
	assert dt_grid(CalendarMonth{2024, 8}, 0, false) == ['7-28|7-29|7-30|7-31| 1| 2| 3',
		' 4| 5| 6| 7| 8| 9|10', '11|12|13|14|15|16|17', '18|19|20|21|22|23|24', '25|26|27|28|29|30|31']
	assert dt_grid(CalendarMonth{2025, 1}, 0, false) == [
		'12-29|12-30|12-31| 1| 2| 3| 4',
		' 5| 6| 7| 8| 9|10|11',
		'12|13|14|15|16|17|18',
		'19|20|21|22|23|24|25',
		'26|27|28|29|30|31|2-1',
	]
	assert dt_grid(CalendarMonth{2024, 2}, 0, false) == ['1-28|1-29|1-30|1-31| 1| 2| 3',
		' 4| 5| 6| 7| 8| 9|10', '11|12|13|14|15|16|17', '18|19|20|21|22|23|24', '25|26|27|28|29|3-1|3-2']
	assert dt_grid(CalendarMonth{2023, 2}, 1, false) == ['1-30|1-31| 1| 2| 3| 4| 5',
		' 6| 7| 8| 9|10|11|12', '13|14|15|16|17|18|19', '20|21|22|23|24|25|26',
		'27|28|3-1|3-2|3-3|3-4|3-5']
	// A month that needs six weeks keeps them all.
	august := calendar_month_weeks(CalendarMonth{2025, 8}, 0, false)
	assert august.len == 6
	assert august[5][0] == dt_date(2025, 8, 31)
	// February 2015 starts on a Sunday and fills exactly four weeks.
	assert calendar_month_weeks(CalendarMonth{2015, 2}, 0, false).len == 4
	assert calendar_month_weeks(CalendarMonth{2015, 2}, 0, true).len == 6
	for first in 0 .. 7 {
		for month in [CalendarMonth{2024, 2}, CalendarMonth{2026, 10}] {
			for week in calendar_month_weeks(month, first, true) {
				assert week[0].weekday() == first
				assert week[0].days_until(week[6]) == 6
			}
		}
	}
}

// ── Calendar state ──────────────────────────────────────────────────

fn dt_cal(mode CalendarMode, st CalendarState) CalendarConfig {
	return CalendarConfig{
		id:    'cal'
		frame: rect(0, 0, 248, 276)
		mode:  mode
		state: st
		today: dt_date(2026, 10, 17)
	}
}

fn dt_cal_month(mode CalendarMode, start ?CalendarDate, end ?CalendarDate) CalendarConfig {
	return dt_cal(mode, CalendarState{
		month: CalendarMonth{2026, 10}
		start: start
		end:   end
	})
}

fn test_matchers_disable_the_days_they_describe() {
	weekend := calendar_disable_weekdays(0, 6)
	assert weekend.matches(dt_date(2026, 10, 17))
	assert weekend.matches(dt_date(2026, 10, 18))
	assert !weekend.matches(dt_date(2026, 10, 19))
	listed := calendar_disable_dates(dt_date(2024, 12, 25), dt_date(2025, 1, 1))
	assert listed.matches(dt_date(2025, 1, 1)) && !listed.matches(dt_date(2025, 1, 2))
	inside := calendar_disable_range(dt_date(2026, 10, 10), dt_date(2026, 10, 12))
	assert inside.matches(dt_date(2026, 10, 10)) && inside.matches(dt_date(2026, 10, 12))
	assert !inside.matches(dt_date(2026, 10, 13)) && !inside.matches(dt_date(2026, 10, 9))
	past := calendar_disable_range(none, dt_date(2026, 10, 16))
	assert past.matches(dt_date(1990, 1, 1)) && !past.matches(dt_date(2026, 10, 17))
	outside := calendar_disable_outside(dt_date(2026, 10, 1), dt_date(2026, 10, 31))
	assert outside.matches(dt_date(2026, 9, 30)) && outside.matches(dt_date(2026, 11, 1))
	assert !outside.matches(dt_date(2026, 10, 15))
	holidays := [dt_date(2026, 12, 25)]
	custom := calendar_disable_if(fn [holidays] (d CalendarDate) bool {
		return d in holidays || d.day <= 2
	})
	assert custom.matches(dt_date(2026, 12, 25)) && custom.matches(dt_date(2026, 11, 2))
	assert !custom.matches(dt_date(2026, 11, 3))
	assert !CalendarMatcher{
		kind: .predicate
	}.matches(dt_date(2026, 1, 1))
	config := CalendarConfig{
		min:      dt_date(2026, 10, 5)
		max:      dt_date(2026, 10, 25)
		disabled: [weekend]
	}
	assert calendar_date_disabled(config, dt_date(2026, 10, 4))
	assert calendar_date_disabled(config, dt_date(2026, 10, 26))
	assert calendar_date_disabled(config, dt_date(2026, 10, 17))
	assert !calendar_date_disabled(config, dt_date(2026, 10, 16))
}

fn test_single_selection_replaces_and_ignores_no_ops() {
	config := dt_cal_month(.single, none, none)
	next := calendar_select(config, dt_date(2026, 10, 9)) or { panic('rejected') }
	assert next.start or { panic('no start') } == dt_date(2026, 10, 9)
	assert next.end == none
	assert next.focused or { panic('no focus') } == dt_date(2026, 10, 9)
	assert next.is_complete(.single)
	if _ := calendar_select(dt_cal_month(.single, dt_date(2026, 10, 9), none), dt_date(2026, 10, 9)) {
		assert false, 'reselecting the selected day is a change'
	}
	if _ := calendar_select(CalendarConfig{
		...config
		disabled: [calendar_disable_weekdays(6)]
	}, dt_date(2026, 10, 17)) {
		assert false, 'disabled day picked'
	}
	if _ := calendar_select(CalendarConfig{
		...config
		enabled: false
	}, dt_date(2026, 10, 9)) {
		assert false, 'disabled calendar picked'
	}
}

fn test_range_selection_restarts_and_completes() {
	a := dt_date(2025, 2, 10)
	b := dt_date(2025, 2, 12)
	mut config := dt_cal(.range, CalendarState{})
	first := calendar_select(config, a) or { panic('start rejected') }
	assert first.start or { panic('') } == a && first.end == none
	assert !first.is_complete(.range)
	config = dt_cal(.range, first)
	second := calendar_select(config, b) or { panic('end rejected') }
	assert second.start or { panic('') } == a && second.end or { panic('') } == b
	assert second.is_complete(.range)
	// A complete range restarts on the next pick.
	again := calendar_select(dt_cal(.range, second), a) or { panic('restart rejected') }
	assert again.start or { panic('') } == a && again.end == none
	// A day before an open range's start starts a new range.
	earlier := calendar_select(dt_cal(.range, first), dt_date(2025, 2, 1)) or { panic('rejected') }
	assert earlier.start or { panic('') } == dt_date(2025, 2, 1) && earlier.end == none
	// The start day again closes a one-day range.
	one_day := calendar_select(dt_cal(.range, first), a) or { panic('rejected') }
	assert one_day.end or { panic('') } == a
}

fn test_picking_a_day_off_screen_turns_the_months() {
	assert calendar_month_showing(CalendarMonth{2026, 10}, 1, dt_date(2026, 11, 1)) == CalendarMonth{2026, 11}
	assert calendar_month_showing(CalendarMonth{2026, 10}, 2, dt_date(2026, 11, 1)) == CalendarMonth{2026, 10}
	assert calendar_month_showing(CalendarMonth{2026, 10}, 2, dt_date(2026, 12, 1)) == CalendarMonth{2026, 11}
	assert calendar_month_showing(CalendarMonth{2026, 10}, 2, dt_date(2026, 9, 27)) == CalendarMonth{2026, 9}
	next := calendar_select(dt_cal_month(.single, none, none), dt_date(2026, 11, 1)) or { panic('') }
	assert next.month == CalendarMonth{2026, 11}
	stay := calendar_select(dt_cal_month(.single, none, none), dt_date(2026, 10, 31)) or { panic('') }
	assert stay.month == CalendarMonth{2026, 10}
}

fn test_unset_month_shows_the_selection_or_today_within_bounds() {
	assert calendar_first_month(dt_cal(.single, CalendarState{})) == CalendarMonth{2026, 10}
	assert calendar_first_month(dt_cal(.single, CalendarState{
		start: dt_date(2025, 3, 4)
	})) == CalendarMonth{2025, 3}
	bounded := CalendarConfig{
		...dt_cal(.single, CalendarState{})
		months: 2
		max:    dt_date(2026, 10, 31)
	}
	assert calendar_first_month(bounded) == CalendarMonth{2026, 9}
	assert calendar_visible_months(bounded) == [CalendarMonth{2026, 9}, CalendarMonth{2026, 10}]
}

fn test_calendar_event_decodes_days_and_rejects_forgeries() {
	config := dt_cal_month(.single, none, none)
	ev := calendar_event(config, calendar_day_action_id('cal', dt_date(2026, 10, 9))) or {
		panic('day rejected')
	}
	assert ev.kind == .select && ev.complete
	assert ev.date == dt_date(2026, 10, 9)
	assert ev.state.start or { panic('') } == dt_date(2026, 10, 9)
	// An outside day of the grid is on screen, and turns the month.
	outside := calendar_event(config, calendar_day_action_id('cal', dt_date(2026, 9, 27))) or {
		panic('outside day rejected')
	}
	assert outside.state.month == CalendarMonth{2026, 9}
	for action in [
		calendar_day_action_id('cal', dt_date(2026, 12, 1)), // not on screen
		calendar_day_action_id('other', dt_date(2026, 10, 9)), // another component
		'cal:component:day:2026-13-01',
		'cal:component:day:2026-10-9',
		'cal:component:day:',
		'cal:component:days:2026-10-09',
		'cal:component:month:3', // the months view is closed
		'cal:component:year:2026',
		'cal:component:',
		'',
	] {
		if got := calendar_event(config, action) {
			assert false, '${action} decoded as ${got.kind}'
		}
	}
	hidden_outside := CalendarConfig{
		...config
		show_outside_days: false
	}
	if _ := calendar_event(hidden_outside, calendar_day_action_id('cal', dt_date(2026, 9, 27))) {
		assert false, 'hidden outside day picked'
	}
	if _ := calendar_event(CalendarConfig{
		...config
		enabled: false
	}, calendar_day_action_id('cal', dt_date(2026, 10, 9))) {
		assert false, 'disabled calendar decoded'
	}
	if _ := calendar_event(CalendarConfig{
		...config
		disabled: [calendar_disable_dates(dt_date(2026, 10, 9))]
	}, calendar_day_action_id('cal', dt_date(2026, 10, 9))) {
		assert false, 'disabled day decoded'
	}
}

fn test_navigation_stops_at_min_and_max() {
	config := CalendarConfig{
		...dt_cal_month(.single, none, none)
		min: dt_date(2026, 10, 5)
		max: dt_date(2026, 12, 20)
	}
	if _ := calendar_event(config, 'cal:component:previous') {
		assert false, 'navigated before min'
	}
	next := calendar_event(config, 'cal:component:next') or { panic('next rejected') }
	assert next.kind == .navigate
	assert next.state.month == CalendarMonth{2026, 11}
	last := calendar_event(CalendarConfig{
		...config
		state: next.state
	}, 'cal:component:next') or { panic('') }
	assert last.state.month == CalendarMonth{2026, 12}
	if _ := calendar_event(CalendarConfig{
		...config
		state: last.state
	}, 'cal:component:next') {
		assert false, 'navigated after max'
	}
	// Two months: next stops once the last visible month holds max.
	two := CalendarConfig{
		...config
		months: 2
	}
	shifted := calendar_event(two, 'cal:component:next') or { panic('') }
	assert shifted.state.month == CalendarMonth{2026, 11}
	if _ := calendar_event(CalendarConfig{
		...two
		state: shifted.state
	}, 'cal:component:next') {
		assert false, 'navigated past max with two months'
	}
	// Year 1 is the earliest month there is.
	if _ := calendar_event(dt_cal(.single, CalendarState{
		month: CalendarMonth{1, 1}
	}), 'cal:component:previous') {
		assert false, 'navigated before year 1'
	}
}

fn test_month_and_year_views() {
	config := dt_cal_month(.single, none, none)
	months := calendar_event(config, 'cal:component:view:months') or { panic('') }
	assert months.kind == .view && months.state.view == .months
	in_months := CalendarConfig{
		...config
		state: months.state
	}
	if _ := calendar_event(in_months, 'cal:component:previous') {
		assert false, 'previous works in the months view'
	}
	if _ := calendar_event(in_months, calendar_day_action_id('cal', dt_date(2026, 10, 9))) {
		assert false, 'day picked from the months view'
	}
	march := calendar_event(in_months, 'cal:component:month:3') or { panic('') }
	assert march.state.view == .days && march.state.month == CalendarMonth{2026, 3}
	for action in ['cal:component:month:0', 'cal:component:month:13', 'cal:component:month:03'] {
		if _ := calendar_event(in_months, action) {
			assert false, '${action} decoded'
		}
	}
	closed := calendar_event(in_months, 'cal:component:view:months') or { panic('') }
	assert closed.state.view == .days
	years := calendar_event(config, 'cal:component:view:years') or { panic('') }
	assert years.state.view == .years
	// Pages are twenty years counted from fifty years before today.
	assert years.state.year_page == 2016
	in_years := CalendarConfig{
		...config
		state: years.state
	}
	later := calendar_event(in_years, 'cal:component:next') or { panic('') }
	assert later.state.year_page == 2036
	earlier := calendar_event(in_years, 'cal:component:previous') or { panic('') }
	assert earlier.state.year_page == 1996
	pick := calendar_event(in_years, 'cal:component:year:2031') or { panic('') }
	assert pick.state.view == .days && pick.state.month == CalendarMonth{2031, 10}
	if _ := calendar_event(in_years, 'cal:component:year:2040') {
		assert false, 'year off the page picked'
	}
	// The last page stops at year_to.
	bounded := CalendarConfig{
		...in_years
		year_from: 2000
		year_to:   2030
	}
	assert calendar_year_page_start(bounded, bounded.state) == 2020
	if _ := calendar_event(bounded, 'cal:component:next') {
		assert false, 'paged past year_to'
	}
	if _ := calendar_event(bounded, 'cal:component:year:2030') {
		assert false, 'year_to is exclusive'
	}
	// Escape leaves a picker view.
	back := calendar_key_event(in_years, dt_key(.escape)) or { panic('') }
	assert back.state.view == .days
}

fn test_hover_events_track_the_day_under_the_pointer() {
	config := dt_cal_month(.range, dt_date(2026, 10, 10), none)
	day := calendar_day_action_id('cal', dt_date(2026, 10, 14))
	enter := calendar_event(config, 'pointer:enter:${day}:10:20') or { panic('enter rejected') }
	assert enter.kind == .hover
	assert enter.state.hovered or { panic('') } == dt_date(2026, 10, 14)
	hovered := CalendarConfig{
		...config
		state: enter.state
	}
	if _ := calendar_event(hovered, 'pointer:enter:${day}:11:21') {
		assert false, 'entering the hovered day again is a change'
	}
	other := calendar_day_action_id('cal', dt_date(2026, 10, 15))
	if _ := calendar_event(hovered, 'pointer:leave:${other}:0:0') {
		assert false, 'leaving another day cleared the hover'
	}
	leave := calendar_event(hovered, 'pointer:leave:${day}:0:0') or { panic('leave rejected') }
	assert leave.state.hovered == none
	if _ := calendar_event(CalendarConfig{
		...config
		hover: false
	}, 'pointer:enter:${day}:10:20') {
		assert false, 'hover reported with hover off'
	}
	if _ := calendar_event(config, 'pointer:down:${day}:10:20') {
		assert false, 'pointer down decoded'
	}
	// The hovered day previews the range from its start.
	span := calendar_span(hovered, calendar_resolved_state(hovered)) or { panic('no preview') }
	assert span.preview && span.from == dt_date(2026, 10, 10) && span.to == dt_date(2026, 10, 14)
	st := calendar_resolved_state(hovered)
	inside := calendar_day_info(hovered, st, span, dt_date(2026, 10, 12), CalendarMonth{2026, 10},
		dt_date(2026, 10, 17))
	assert inside.band == .full && inside.preview
	start := calendar_day_info(hovered, st, span, dt_date(2026, 10, 10), CalendarMonth{2026, 10},
		dt_date(2026, 10, 17))
	assert start.band == .start && start.selected
	end := calendar_day_info(hovered, st, span, dt_date(2026, 10, 14), CalendarMonth{2026, 10},
		dt_date(2026, 10, 17))
	assert end.band == .end && end.hovered && !end.selected
	// No preview before the start, or once the range is complete.
	before := CalendarConfig{
		...config
		state: CalendarState{
			...config.state
			hovered: dt_date(2026, 10, 2)
		}
	}
	assert calendar_span(before, calendar_resolved_state(before)) == none
}

fn test_keyboard_moves_focus_and_picks() {
	config := dt_cal_month(.single, dt_date(2026, 10, 14), none)
	first := calendar_key_event(config, dt_key(.right)) or { panic('first key ignored') }
	// The first key shows the ring on the selected day without moving.
	assert first.kind == .focus && first.date == dt_date(2026, 10, 14)
	focused := CalendarConfig{
		...config
		state: first.state
	}
	cases := {
		KeyCode.right: dt_date(2026, 10, 15)
		.left:         dt_date(2026, 10, 13)
		.down:         dt_date(2026, 10, 21)
		.up:           dt_date(2026, 10, 7)
		.page_down:    dt_date(2026, 11, 14)
		.page_up:      dt_date(2026, 9, 14)
		.home:         dt_date(2026, 10, 11)
		.end:          dt_date(2026, 10, 17)
	}
	for code, want in cases {
		ev := calendar_key_event(focused, dt_key(code)) or { panic('${code} ignored') }
		assert ev.date == want, '${code}'
		assert ev.state.focused or { panic('') } == want
		assert ev.state.month == want.year_month()
	}
	year := calendar_key_event(focused, KeyEvent{
		code:  .page_down
		shift: true
	}) or { panic('') }
	assert year.date == dt_date(2027, 10, 14)
	monday := calendar_key_event(CalendarConfig{
		...focused
		first_day_of_week: 1
	}, dt_key(.home)) or { panic('') }
	assert monday.date == dt_date(2026, 10, 12)
	for event in [KeyEvent{
		code: .right
		cmd:  true
	}, KeyEvent{
		code:  .right
		shift: true
	}, dt_key(.a), dt_key(.tab)] {
		if _ := calendar_key_event(focused, event) {
			assert false, '${event} handled'
		}
	}
	// Enter picks the focused day.
	moved := calendar_key_event(focused, dt_key(.right)) or { panic('') }
	pick := calendar_key_event(CalendarConfig{
		...focused
		state: moved.state
	}, dt_key(.enter)) or { panic('enter ignored') }
	assert pick.kind == .select && pick.state.start or { panic('') } == dt_date(2026, 10, 15)
	// Without a focused day Enter does nothing.
	if _ := calendar_key_event(config, dt_key(.enter)) {
		assert false, 'enter picked without focus'
	}
}

fn test_keyboard_focus_stays_within_bounds() {
	config := CalendarConfig{
		...dt_cal(.single, CalendarState{
			month:   CalendarMonth{2026, 10}
			focused: dt_date(2026, 10, 3)
		})
		min: dt_date(2026, 10, 1)
		max: dt_date(2026, 10, 30)
	}
	up := calendar_key_event(config, dt_key(.up)) or { panic('') }
	assert up.date == dt_date(2026, 10, 1)
	at_min := CalendarConfig{
		...config
		state: up.state
	}
	if _ := calendar_key_event(at_min, dt_key(.left)) {
		assert false, 'moved before min'
	}
	end := calendar_key_event(at_min, dt_key(.page_down)) or { panic('') }
	assert end.date == dt_date(2026, 10, 30)
	// Focus can rest on a disabled day, but Enter does not pick it.
	weekend := CalendarConfig{
		...config
		disabled: [calendar_disable_weekdays(0, 6)]
		state:    CalendarState{
			...config.state
			focused: dt_date(2026, 10, 17)
		}
	}
	if _ := calendar_key_event(weekend, dt_key(.space)) {
		assert false, 'picked a disabled day'
	}
}

// ── Calendar elements ───────────────────────────────────────────────

fn test_calendar_size_matches_upstream_widths() {
	w, h := calendar_size(.medium, 1)
	assert w == 248 && h == 276
	small_w, _ := calendar_size(.small, 1)
	large_w, _ := calendar_size(.large, 1)
	assert small_w == 220 && large_w == 304
	two, _ := calendar_size(.medium, 2)
	assert two == 488
}

fn test_calendar_validates_its_configuration() {
	for config in [
		CalendarConfig{
			...dt_cal(.single, CalendarState{})
			months: 0
		},
		CalendarConfig{
			...dt_cal(.single, CalendarState{})
			months: 13
		},
		CalendarConfig{
			...dt_cal(.single, CalendarState{})
			first_day_of_week: 7
		},
		CalendarConfig{
			...dt_cal(.single, CalendarState{})
			month_names: ['a']
		},
		CalendarConfig{
			...dt_cal(.single, CalendarState{})
			min: dt_date(2026, 2, 1)
			max: dt_date(2026, 1, 1)
		},
		CalendarConfig{
			...dt_cal(.single, CalendarState{})
			id: ''
		},
	] {
		if _ := calendar(config) {
			assert false, 'invalid calendar accepted'
		}
	}
}

fn test_calendar_draws_days_with_their_state() {
	config := CalendarConfig{
		...dt_cal_month(.single, dt_date(2026, 10, 9), none)
		disabled:    [calendar_disable_weekdays(0)]
		fixed_weeks: true
	}
	el := calendar(config) or { panic(err) }
	validate_element_tree(el) or { panic(err) }
	dt_assert_inside(el)
	assert el.accessibility_value == 'October 2026'
	days := dt_buttons(el).filter(it.action_id.contains(':day:'))
	assert days.len == 42
	selected := dt_find(el, 'cal:component:day:0:2026-10-09') or { panic('no selected day') }
	assert selected.action_id == calendar_day_action_id('cal', dt_date(2026, 10, 9))
	assert selected.accessibility_value == 'selected'
	assert selected.accessibility_label == 'Friday, October 9, 2026'
	assert selected.enabled && selected.hoverable
	today := dt_find(el, 'cal:component:day:0:2026-10-17') or { panic('') }
	assert today.accessibility_value == 'today'
	sunday := dt_find(el, 'cal:component:day:0:2026-10-11') or { panic('') }
	assert !sunday.enabled && !sunday.hoverable
	assert sunday.accessibility_value == 'unavailable'
	labels := dt_labels(el)
	assert 'October' in labels && '2026' in labels && 'Su' in labels
	// Outside days can be left out.
	trimmed := calendar(CalendarConfig{
		...config
		show_outside_days: false
	}) or { panic(err) }
	assert dt_buttons(trimmed).filter(it.action_id.contains(':day:')).len == 31
	// Two months, Monday first, with titles over each month.
	pair := calendar(CalendarConfig{
		...config
		months:            2
		first_day_of_week: 1
		frame:             rect(0, 0, 488, 276)
	}) or { panic(err) }
	validate_element_tree(pair) or { panic(err) }
	pair_labels := dt_labels(pair)
	assert 'October 2026' in pair_labels && 'November 2026' in pair_labels
	assert pair_labels.filter(it == 'Mo').len == 2
}

fn test_calendar_draws_the_range_band_and_picker_views() {
	config := dt_cal_month(.range, dt_date(2026, 10, 12), dt_date(2026, 10, 15))
	el := calendar(config) or { panic(err) }
	start := dt_find(el, 'cal:component:day:0:2026-10-12') or { panic('') }
	assert start.accessibility_value == 'range start'
	inside := dt_find(el, 'cal:component:day:0:2026-10-13') or { panic('') }
	assert inside.accessibility_value == 'in range'
	end := dt_find(el, 'cal:component:day:0:2026-10-15') or { panic('') }
	assert end.accessibility_value == 'range end'
	months := calendar(CalendarConfig{
		...config
		state: CalendarState{
			...config.state
			view: .months
		}
	}) or { panic(err) }
	dt_assert_inside(months)
	month_cells := dt_buttons(months).filter(it.id.contains(':month:'))
	assert month_cells.len == 12
	assert month_cells[9].accessibility_value == 'selected'
	years := calendar(CalendarConfig{
		...config
		state: CalendarState{
			...config.state
			view: .years
		}
	}) or { panic(err) }
	dt_assert_inside(years)
	assert dt_buttons(years).filter(it.id.contains(':year:')).len == 20
	// Shrunk and stretched frames keep every part inside.
	for frame in [rect(0, 0, 120, 140), rect(0, 0, 600, 500), rect(0, 0, 0, 0)] {
		squeezed := calendar(CalendarConfig{
			...config
			frame: frame
		}) or { panic(err) }
		dt_assert_inside(squeezed)
	}
}

// ── Time field ──────────────────────────────────────────────────────

fn dt_tf(st TimeFieldState) TimeFieldConfig {
	return TimeFieldConfig{
		id:    'tf'
		frame: rect(0, 0, 120, 32)
		state: st
	}
}

fn dt_tf_at(precision TimePrecision, hour_cycle HourCycle, t TimeOfDay) TimeFieldConfig {
	return TimeFieldConfig{
		...dt_tf(TimeFieldState{
			time:    t
			focused: true
		})
		precision:  precision
		hour_cycle: hour_cycle
	}
}

fn dt_tf_type(config TimeFieldConfig, keys string) TimeFieldConfig {
	mut current := config
	for ch in keys {
		code := match ch {
			`a` { KeyCode.a }
			`p` { KeyCode.p }
			else { unsafe { KeyCode(int(KeyCode._0) + int(ch - `0`)) } }
		}
		if ev := time_field_key_event(current, dt_key(code)) {
			current = TimeFieldConfig{
				...current
				state: ev.state
			}
		}
	}
	return current
}

fn dt_tf_select(config TimeFieldConfig, segment TimeSegment) TimeFieldConfig {
	return TimeFieldConfig{
		...config
		state: TimeFieldState{
			...config.state
			segment: segment
			pending: -1
		}
	}
}

fn test_time_values_wrap_and_validate() {
	assert dt_hms(23, 59, 59).seconds() == 86399
	assert time_of_day_from_seconds(-1) == dt_hms(23, 59, 59)
	assert time_of_day_from_seconds(86400) == dt_hms(0, 0, 0)
	assert time_of_day_from_seconds(3661) == dt_hms(1, 1, 1)
	for parts in [[24, 0, 0], [0, 60, 0], [0, 0, 60], [-1, 0, 0]] {
		if _ := time_of_day(parts[0], parts[1], parts[2]) {
			assert false, '${parts} accepted'
		}
	}
	assert dt_hms(9, 30, 0) < dt_hms(9, 30, 1)
	assert dt_hms(9, 30, 15).str() == '09:30:15'
}

fn test_time_format_and_parse() {
	assert time_format(dt_hms(9, 5, 0), .minute, .h23) == '09:05'
	assert time_format(dt_hms(21, 5, 7), .second, .h23) == '21:05:07'
	assert time_format(dt_hms(0, 0, 0), .minute, .h12) == '12:00 AM'
	assert time_format(dt_hms(12, 0, 0), .minute, .h12) == '12:00 PM'
	assert time_format(dt_hms(23, 59, 59), .second, .h12) == '11:59:59 PM'
	cases := {
		'9:30':       dt_hms(9, 30, 0)
		' 09:30:15 ': dt_hms(9, 30, 15)
		'9:30 pm':    dt_hms(21, 30, 0)
		'9:30PM':     dt_hms(21, 30, 0)
		'12:00 am':   dt_hms(0, 0, 0)
		'12 pm':      dt_hms(12, 0, 0)
		'9p':         dt_hms(21, 0, 0)
		'23:59':      dt_hms(23, 59, 0)
	}
	for source, want in cases {
		got := time_parse(source) or { panic('${source} rejected') }
		assert got == want, source
	}
	for source in ['', '9', '24:00', '13:00 pm', '0:30 am', '9:5', '09:60', '9:30:1', 'a', '9:30x',
		'1:2:3:4', '-1:00'] {
		if got := time_parse(source) {
			assert false, '${source} parsed as ${got}'
		}
	}
}

fn test_time_segments_and_twelve_hour_labels() {
	assert time_segments(.minute, .h23) == [TimeSegment.hour, .minute]
	assert time_segments(.second, .h12) == [TimeSegment.hour, .minute, .second, .period]
	for hour, want in {
		0:  '12 AM'
		9:  '09 AM'
		12: '12 PM'
		23: '11 PM'
	} {
		t := dt_hms(hour, 0, 0)
		assert '${time_segment_text(t, .hour, .h12)} ${time_segment_text(t, .period, .h12)}' == want
	}
	// The hour keeps its period, and the period keeps the hour.
	assert time_with_segment(dt_hms(21, 0, 0), .hour, .h12, 12) == dt_hms(12, 0, 0)
	assert time_with_segment(dt_hms(9, 0, 0), .hour, .h12, 12) == dt_hms(0, 0, 0)
	assert time_with_segment(dt_hms(9, 0, 0), .period, .h12, 1) == dt_hms(21, 0, 0)
	assert time_with_segment(dt_hms(9, 0, 0), .minute, .h23, 60) == dt_hms(9, 0, 0)
}

fn test_typing_fills_segments_and_advances() {
	typed := dt_tf_type(dt_tf_at(.second, .h23, dt_hms(0, 0, 0)), '093015')
	assert typed.state.time == dt_hms(9, 30, 15)
	assert typed.state.segment == .second
	seven := dt_tf_type(dt_tf_at(.minute, .h23, dt_hms(0, 0, 0)), '7')
	assert seven.state.time == dt_hms(7, 0, 0) && seven.state.segment == .minute
	assert dt_tf_type(seven, '8').state.time == dt_hms(7, 8, 0)
	// 2 then 5 cannot form 25 hours, so 5 starts over and completes the hour.
	restart := dt_tf_type(dt_tf_at(.minute, .h23, dt_hms(0, 0, 0)), '25')
	assert restart.state.time == dt_hms(5, 0, 0) && restart.state.segment == .minute
	// A first digit that may start two waits for the second.
	pending := dt_tf_type(dt_tf_at(.minute, .h23, dt_hms(0, 0, 0)), '1')
	assert pending.state.pending == 1 && pending.state.segment == .hour
}

fn test_twelve_hour_typing_keeps_the_period_until_it_is_typed() {
	mut config := dt_tf_type(dt_tf_at(.minute, .h12, dt_hms(0, 0, 0)), '12')
	assert config.state.time == dt_hms(0, 0, 0)
	config = dt_tf_type(config, '30p')
	assert config.state.time == dt_hms(12, 30, 0)
	assert config.state.segment == .period
	config = dt_tf_type(dt_tf_select(config, .hour), '9')
	assert config.state.time == dt_hms(21, 30, 0)
	zeros := dt_tf_type(dt_tf_select(config, .hour), '00')
	assert zeros.state.segment == .hour
	// Digits do not edit the period, and a/p only edit the period.
	if _ := time_field_key_event(dt_tf_select(config, .period), dt_key(._1)) {
		assert false, 'a digit edited the period'
	}
	if _ := time_field_key_event(dt_tf_select(config, .minute), dt_key(.a)) {
		assert false, 'a edited the minutes'
	}
}

fn dt_tf_step(config TimeFieldConfig, segment TimeSegment, direction int) TimeOfDay {
	return time_field_step(dt_tf_select(config, segment), segment, direction) or {
		panic('step of ${segment} rejected')
	}
}

fn test_stepping_wraps_without_carry_and_follows_steps() {
	late := dt_tf_at(.minute, .h23, dt_hms(23, 59, 0))
	assert dt_tf_step(late, .hour, 1) == dt_hms(0, 59, 0)
	assert dt_tf_step(late, .minute, 1) == dt_hms(23, 0, 0)
	assert dt_tf_step(dt_tf_at(.minute, .h23, dt_hms(23, 0, 0)), .minute, -1) == dt_hms(23, 59, 0)
	eleven := dt_tf_at(.minute, .h12, dt_hms(11, 0, 0))
	assert dt_tf_step(eleven, .hour, 1) == dt_hms(0, 0, 0)
	assert dt_tf_step(eleven, .period, 1) == dt_hms(23, 0, 0)
	assert dt_tf_step(dt_tf_at(.minute, .h12, dt_hms(12, 0, 0)), .period, 1) == dt_hms(0, 0, 0)
	quarter := TimeFieldConfig{
		...dt_tf_at(.minute, .h23, dt_hms(10, 7, 0))
		minute_step: 15
	}
	assert dt_tf_step(quarter, .minute, 1) == dt_hms(10, 15, 0)
	assert dt_tf_step(quarter, .minute, -1) == dt_hms(10, 0, 0)
	on_hour := TimeFieldConfig{
		...quarter
		state: TimeFieldState{
			time: dt_hms(10, 0, 0)
		}
	}
	assert dt_tf_step(on_hour, .minute, -1) == dt_hms(10, 45, 0)
	assert time_step_value(45, 0, 59, 15, 1) == 0
	assert time_step_value(56, 0, 59, 7, 1) == 0
	assert time_step_value(0, 0, 59, 7, -1) == 56
	assert time_step_value(12, 1, 12, 1, 1) == 1
}

fn test_stepping_stops_at_min_and_max() {
	config := TimeFieldConfig{
		...dt_tf_at(.minute, .h23, dt_hms(17, 0, 0))
		min: dt_hms(9, 0, 0)
		max: dt_hms(17, 0, 0)
	}
	if _ := time_field_step(config, .hour, 1) {
		assert false, 'stepped past max'
	}
	assert dt_tf_step(config, .hour, -1) == dt_hms(16, 0, 0)
	at_min := TimeFieldConfig{
		...config
		state: TimeFieldState{
			time: dt_hms(9, 0, 0)
		}
	}
	if _ := time_field_step(at_min, .hour, -1) {
		assert false, 'stepped before min'
	}
	// A step out of range lands on the bound.
	near := TimeFieldConfig{
		...config
		state: TimeFieldState{
			time: dt_hms(16, 30, 0)
		}
	}
	assert dt_tf_step(near, .hour, 1) == dt_hms(17, 0, 0)
	assert time_in_range(config, dt_hms(12, 0, 0))
	assert !time_in_range(config, dt_hms(17, 0, 1))
	// Typed times are kept even when out of range, and drawn as invalid.
	typed := dt_tf_type(dt_tf_select(config, .hour), '20')
	assert typed.state.time == dt_hms(20, 0, 0)
	el := time_field(typed) or { panic(err) }
	assert el.box.border_color == typed.theme.danger
}

fn test_time_field_keys_move_between_segments_and_reset() {
	config := dt_tf_at(.second, .h12, dt_hms(21, 30, 15))
	right := time_field_key_event(config, dt_key(.right)) or { panic('') }
	assert right.kind == .select && right.state.segment == .minute
	if _ := time_field_key_event(config, dt_key(.left)) {
		assert false, 'moved before the first segment'
	}
	last := dt_tf_select(config, .period)
	if _ := time_field_key_event(last, dt_key(.tab)) {
		assert false, 'tab past the last segment was taken'
	}
	back := time_field_key_event(last, KeyEvent{
		code:  .tab
		shift: true
	}) or { panic('') }
	assert back.state.segment == .second
	up := time_field_key_event(config, dt_key(.up)) or { panic('') }
	assert up.kind == .change && up.state.time == dt_hms(22, 30, 15)
	cleared := time_field_key_event(dt_tf_select(config, .minute), dt_key(.backspace)) or { panic('') }
	assert cleared.state.time == dt_hms(21, 0, 15)
	hour_reset := time_field_key_event(config, dt_key(.delete)) or { panic('') }
	assert hour_reset.state.time == dt_hms(12, 30, 15)
	am := time_field_key_event(last, dt_key(.a)) or { panic('') }
	assert am.state.time == dt_hms(9, 30, 15)
	numpad := time_field_key_event(dt_tf_at(.minute, .h23, dt_hms(0, 0, 0)), dt_key(.kp_7)) or { panic('') }
	assert numpad.state.time == dt_hms(7, 0, 0)
	for event in [KeyEvent{
		code: .up
		cmd:  true
	}, dt_key(.escape), dt_key(.b)] {
		if _ := time_field_key_event(config, event) {
			assert false, '${event} handled'
		}
	}
	if _ := time_field_key_event(TimeFieldConfig{
		...config
		enabled: false
	}, dt_key(.up)) {
		assert false, 'disabled field stepped'
	}
}

fn test_time_field_event_decodes_segments_and_steppers() {
	config := dt_tf(TimeFieldState{
		time: dt_hms(9, 30, 0)
	})
	pick := time_field_event(config, time_field_segment_action_id('tf', .minute)) or { panic('') }
	assert pick.kind == .select && pick.state.segment == .minute && pick.state.focused
	if _ := time_field_event(TimeFieldConfig{
		...config
		state: pick.state
	}, time_field_segment_action_id('tf', .minute)) {
		assert false, 'selecting the selected segment is a change'
	}
	up := time_field_event(config, 'tf:component:increment') or { panic('') }
	assert up.kind == .change && up.state.time == dt_hms(10, 30, 0) && up.state.focused
	down := time_field_event(config, 'tf:component:decrement') or { panic('') }
	assert down.state.time == dt_hms(8, 30, 0)
	for action in [time_field_segment_action_id('tf', .second), time_field_segment_action_id('tf',
		.period), 'tf:component:segment:', 'other:component:increment', 'tf:component:step', ''] {
		if _ := time_field_event(config, action) {
			assert false, '${action} decoded'
		}
	}
}

fn test_time_field_element_and_width() {
	config := TimeFieldConfig{
		...dt_tf_at(.second, .h12, dt_hms(15, 5, 30))
		frame: rect(10, 10, 200, 32)
	}
	el := time_field(config) or { panic(err) }
	validate_element_tree(el) or { panic(err) }
	dt_assert_inside(el)
	assert el.accessibility_value == '03:05:30 PM'
	segments := dt_buttons(el).filter(it.accessibility_role == 'spinbutton')
	assert segments.map(it.accessibility_value) == ['03', '05', '30', 'PM']
	assert dt_labels(el).filter(it == ':').len == 2
	assert el.box.border_color == config.theme.primary
	stepped_out := time_field(TimeFieldConfig{
		...config
		max: dt_hms(15, 5, 30)
	}) or { panic(err) }
	increment := dt_find(stepped_out, 'tf:component:increment') or { panic('') }
	assert !increment.enabled
	minute_w := time_field_width(dt_tf_at(.minute, .h23, dt_hms(0, 0, 0)))
	second_w := time_field_width(dt_tf_at(.second, .h23, dt_hms(0, 0, 0)))
	twelve_w := time_field_width(dt_tf_at(.minute, .h12, dt_hms(0, 0, 0)))
	bare_w := time_field_width(TimeFieldConfig{
		...dt_tf_at(.minute, .h23, dt_hms(0, 0, 0))
		steppers: false
	})
	assert second_w > minute_w && twelve_w > minute_w && bare_w < minute_w
	for bad in [TimeFieldConfig{
		...config
		minute_step: 0
	}, TimeFieldConfig{
		...config
		min: dt_hms(10, 0, 0)
		max: dt_hms(9, 0, 0)
	}, TimeFieldConfig{
		...config
		state: TimeFieldState{
			time: TimeOfDay{25, 0, 0}
		}
	}] {
		if _ := time_field(bad) {
			assert false, 'invalid time field accepted'
		}
	}
}

// ── Date picker ─────────────────────────────────────────────────────

fn dt_picker(mode CalendarMode, st CalendarState, open bool) DatePickerConfig {
	return DatePickerConfig{
		id:            'dp'
		frame:         rect(20, 40, 240, 32)
		calendar:      CalendarConfig{
			mode:  mode
			state: st
			today: dt_date(2026, 10, 17)
		}
		open:          open
		window_width:  800
		window_height: 600
	}
}

fn dt_dp_day(d CalendarDate) string {
	return calendar_day_action_id(component_part_id('dp', 'calendar'), d)
}

fn test_popover_frame_flips_and_stays_in_the_window() {
	below := date_picker_popover_frame(rect(20, 40, 240, 32), 300, 280, 800, 600)
	assert below == rect(20, 76, 300, 280)
	above := date_picker_popover_frame(rect(20, 500, 240, 32), 300, 280, 800, 600)
	assert above == rect(20, 216, 300, 280)
	right := date_picker_popover_frame(rect(700, 40, 80, 32), 300, 280, 800, 600)
	assert right.x == 492
	// Room on neither side: the side with more room, pushed into the window.
	tall := date_picker_popover_frame(rect(20, 100, 240, 32), 300, 500, 800, 520)
	assert tall.y == 12
	low := date_picker_popover_frame(rect(20, 300, 240, 32), 300, 500, 800, 520)
	assert low.y == 8
	wide := date_picker_popover_frame(rect(20, 40, 240, 32), 900, 100, 800, 600)
	assert wide.x == 8
}

fn test_picker_text_formats_the_selection() {
	assert date_picker_text(dt_picker(.single, CalendarState{}, false)) == ''
	assert date_picker_text(dt_picker(.single, CalendarState{
		start: dt_date(2026, 10, 9)
	}, false)) == '2026/10/09'
	open_range := dt_picker(.range, CalendarState{
		start: dt_date(2026, 10, 9)
	}, false)
	assert date_picker_text(open_range) == '2026/10/09 – …'
	assert date_picker_text(DatePickerConfig{
		...dt_picker(.range, CalendarState{
			start: dt_date(2026, 10, 9)
			end:   dt_date(2026, 10, 12)
		}, false)
		format: '%b %-d'
	}) == 'Oct 9 – Oct 12'
	assert date_picker_text(DatePickerConfig{
		...dt_picker(.single, CalendarState{
			start: dt_date(2026, 10, 9)
		}, false)
		with_time: true
		time:      TimeFieldConfig{
			state:      TimeFieldState{
				time: dt_hms(14, 30, 0)
			}
			hour_cycle: .h12
		}
	}) == '2026/10/09 02:30 PM'
}

fn test_picker_opens_closes_and_picks() {
	closed := dt_picker(.single, CalendarState{
		month:   CalendarMonth{2025, 1}
		start:   dt_date(2026, 10, 9)
		focused: dt_date(2026, 10, 2)
	}, false)
	opened := date_picker_event(closed, 'dp:component:trigger') or { panic('trigger ignored') }
	assert opened.kind == .open && opened.open
	assert calendar_first_month(CalendarConfig{
		...closed.calendar
		state: opened.state
	}) == CalendarMonth{2026, 10}
	assert opened.state.focused == none
	for action in ['dp:component:backdrop', dt_dp_day(dt_date(2026, 10, 12)), 'dp:component:preset:0',
		'dp:component:surface'] {
		if _ := date_picker_event(closed, action) {
			assert false, '${action} decoded while closed'
		}
	}
	open := dt_picker(.single, opened.state, true)
	dismiss := date_picker_event(open, 'dp:component:backdrop') or { panic('') }
	assert dismiss.kind == .close && !dismiss.open
	if _ := date_picker_event(open, 'dp:component:surface') {
		assert false, 'a click on the surface did something'
	}
	pick := date_picker_event(open, dt_dp_day(dt_date(2026, 10, 12))) or { panic('day ignored') }
	assert pick.kind == .select && !pick.open
	assert pick.state.start or { panic('') } == dt_date(2026, 10, 12)
	again := date_picker_event(open, dt_dp_day(dt_date(2026, 10, 9))) or { panic('reselect ignored') }
	assert again.kind == .close && !again.open
	nav := date_picker_event(open, 'dp:component:calendar:component:next') or { panic('') }
	assert nav.kind == .calendar && nav.open && nav.state.month == CalendarMonth{2026, 11}
	for action in ['dp:component:nothing', 'xx:component:trigger', dt_dp_day(dt_date(2027, 1, 1)),
		''] {
		if _ := date_picker_event(open, action) {
			assert false, '${action} decoded'
		}
	}
	if _ := date_picker_event(DatePickerConfig{
		...open
		enabled: false
	}, 'dp:component:backdrop') {
		assert false, 'disabled picker decoded'
	}
}

fn test_range_picker_stays_open_for_the_second_day() {
	open := dt_picker(.range, CalendarState{
		month: CalendarMonth{2026, 10}
	}, true)
	first := date_picker_event(open, dt_dp_day(dt_date(2026, 10, 5))) or { panic('') }
	assert first.kind == .calendar && first.open
	second := date_picker_event(dt_picker(.range, first.state, true), dt_dp_day(dt_date(2026, 10, 8))) or {
		panic('')
	}
	assert second.kind == .select && !second.open
	assert second.state.end or { panic('') } == dt_date(2026, 10, 8)
}

fn test_picker_clear_and_presets() {
	set := DatePickerConfig{
		...dt_picker(.range, CalendarState{
			start: dt_date(2026, 10, 1)
			end:   dt_date(2026, 10, 3)
		}, true)
		clearable: true
		presets:   date_range_presets_recent(dt_date(2026, 10, 17))
	}
	cleared := date_picker_event(set, 'dp:component:clear') or { panic('clear ignored') }
	assert cleared.kind == .clear && cleared.state.start == none && cleared.state.end == none
	empty := dt_picker(.range, cleared.state, true)
	if _ := date_picker_event(DatePickerConfig{
		...empty
		clearable: true
	}, 'dp:component:clear') {
		assert false, 'cleared an empty picker'
	}
	if _ := date_picker_event(DatePickerConfig{
		...set
		clearable: false
	}, 'dp:component:clear') {
		assert false, 'cleared without a clear button'
	}
	week := date_picker_event(set, 'dp:component:preset:1') or { panic('preset ignored') }
	assert week.kind == .select && !week.open
	assert week.state.start or { panic('') } == dt_date(2026, 10, 11)
	assert week.state.end or { panic('') } == dt_date(2026, 10, 17)
	for action in ['dp:component:preset:5', 'dp:component:preset:01', 'dp:component:preset:-1'] {
		if _ := date_picker_event(set, action) {
			assert false, '${action} decoded'
		}
	}
	// A preset on a disabled day is refused.
	if _ := date_picker_event(DatePickerConfig{
		...set
		calendar: CalendarConfig{
			...set.calendar
			max: dt_date(2026, 10, 16)
		}
	}, 'dp:component:preset:0') {
		assert false, 'preset past max applied'
	}
	recent := date_range_presets_recent(dt_date(2026, 3, 31))
	assert recent.map(it.label) == ['Today', 'Last 7 days', 'Last 30 days', 'This month', 'Last month']
	assert recent[4].start == dt_date(2026, 2, 1) && recent[4].end or { panic('') } == dt_date(2026, 2, 28)
	assert date_presets_recent(dt_date(2026, 3, 1))[1].start == dt_date(2026, 2, 28)
}

fn test_picker_with_time_keeps_the_popover_open() {
	config := DatePickerConfig{
		...dt_picker(.single, CalendarState{
			month: CalendarMonth{2026, 10}
		}, true)
		with_time: true
		time:      TimeFieldConfig{
			state: TimeFieldState{
				time: dt_hms(9, 0, 0)
			}
		}
	}
	pick := date_picker_event(config, dt_dp_day(dt_date(2026, 10, 20))) or { panic('') }
	assert pick.kind == .select && pick.open
	step := date_picker_event(config, 'dp:component:time:component:increment') or { panic('') }
	assert step.kind == .time && step.time.time == dt_hms(10, 0, 0) && step.open
	focused := DatePickerConfig{
		...config
		time: TimeFieldConfig{
			...config.time
			state: step.time
		}
	}
	typed := date_picker_key_event(focused, dt_key(.down)) or { panic('') }
	assert typed.kind == .time && typed.time.time == dt_hms(9, 0, 0)
	escape := date_picker_key_event(focused, dt_key(.escape)) or { panic('') }
	assert escape.kind == .close && !escape.open && !escape.time.focused
	tab := date_picker_key_event(config, dt_key(.tab)) or { panic('') }
	assert tab.kind == .time && tab.time.focused
}

fn test_picker_keys() {
	closed := dt_picker(.single, CalendarState{
		start: dt_date(2026, 10, 9)
	}, false)
	opened := date_picker_key_event(closed, dt_key(.enter)) or { panic('') }
	assert opened.kind == .open && opened.open
	if _ := date_picker_key_event(closed, dt_key(.escape)) {
		assert false, 'escape taken while closed'
	}
	open := dt_picker(.single, opened.state, true)
	focus := date_picker_key_event(open, dt_key(.right)) or { panic('') }
	assert focus.kind == .calendar && focus.state.focused or { panic('') } == dt_date(2026, 10, 9)
	moved := date_picker_key_event(dt_picker(.single, focus.state, true), dt_key(.right)) or { panic('') }
	pick := date_picker_key_event(dt_picker(.single, moved.state, true), dt_key(.enter)) or { panic('') }
	assert pick.kind == .select && !pick.open
	assert pick.state.start or { panic('') } == dt_date(2026, 10, 10)
	close := date_picker_key_event(open, dt_key(.escape)) or { panic('') }
	assert close.kind == .close && !close.open
	// Backspace and Delete clear a clearable picker.
	if _ := date_picker_key_event(closed, dt_key(.backspace)) {
		assert false, 'cleared a picker without a clear button'
	}
	clearable := DatePickerConfig{
		...closed
		clearable: true
	}
	cleared := date_picker_key_event(clearable, dt_key(.delete)) or { panic('') }
	assert cleared.kind == .clear && cleared.state.start == none && !cleared.open
	// While the time field has focus, Backspace resets its segment instead.
	timed := DatePickerConfig{
		...clearable
		open:      true
		with_time: true
		time:      TimeFieldConfig{
			state: TimeFieldState{
				time:    dt_hms(9, 30, 0)
				focused: true
			}
		}
	}
	reset := date_picker_key_event(timed, dt_key(.backspace)) or { panic('') }
	assert reset.kind == .time && reset.time.time == dt_hms(0, 30, 0)
	assert reset.state.start or { panic('') } == dt_date(2026, 10, 9)
}

fn test_picker_elements() {
	config := DatePickerConfig{
		...dt_picker(.single, CalendarState{
			start: dt_date(2026, 10, 9)
		}, false)
		clearable:           true
		accessibility_label: 'Due date'
		presets:             date_presets_recent(dt_date(2026, 10, 17))
	}
	trigger := date_picker(config) or { panic(err) }
	validate_element_tree(trigger) or { panic(err) }
	dt_assert_inside(trigger)
	button := dt_find(trigger, 'dp:component:trigger') or { panic('') }
	assert button.accessibility_role == 'combobox'
	assert button.accessibility_value == '2026/10/09'
	assert dt_find(trigger, 'dp:component:clear') != none
	empty := date_picker(dt_picker(.single, CalendarState{}, false)) or { panic(err) }
	assert 'Select a date' in dt_labels(empty)
	assert dt_find(empty, 'dp:component:clear') == none
	hidden_overlay := date_picker_overlay(config) or { panic(err) }
	assert hidden_overlay.hidden && hidden_overlay.children.len == 0
	open := DatePickerConfig{
		...config
		open: true
	}
	overlay := date_picker_overlay(open) or { panic(err) }
	validate_element_tree(overlay) or { panic(err) }
	assert !overlay.hidden
	assert overlay.frame == rect(0, 0, 800, 600)
	backdrop := dt_find(overlay, 'dp:component:backdrop') or { panic('') }
	assert backdrop.frame == overlay.frame && backdrop.button_behavior
	popover := dt_find(overlay, 'dp:component:popover') or { panic('') }
	assert popover.accessibility_role == 'dialog'
	assert popover.frame.y == 40 + 32 + date_picker_popover_gap
	dt_assert_inside(popover)
	assert dt_find(popover, 'dp:component:calendar') != none
	assert dt_find(popover, 'dp:component:preset:2') != none
	w, h := date_picker_popover_size(open)
	bare_w, _ := date_picker_popover_size(dt_picker(.single, CalendarState{}, true))
	assert w > bare_w
	_, timed_h := date_picker_popover_size(DatePickerConfig{
		...open
		with_time: true
	})
	assert timed_h > h
	timed := date_picker_overlay(DatePickerConfig{
		...open
		with_time: true
	}) or { panic(err) }
	assert dt_find(timed, 'dp:component:time') != none
	if _ := date_picker_overlay(DatePickerConfig{
		...open
		window_width: 0
	}) {
		assert false, 'open overlay without a window size'
	}
	if _ := date_picker(DatePickerConfig{
		...config
		presets: [date_preset(' ', dt_date(2026, 1, 1))]
	}) {
		assert false, 'preset without a label accepted'
	}
}
