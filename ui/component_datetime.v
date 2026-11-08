module ui2

import math
import time

// Date and time components: calendar (component_datetime_calendar.v), date
// picker (component_datetime_picker.v) and time field
// (component_datetime_time.v). This file holds the value types they share and
// the date arithmetic, which is plain proleptic Gregorian arithmetic on year,
// month and day, so no time zone or clock is involved anywhere but
// calendar_today and time_of_day_now.

pub const calendar_min_year = 1
pub const calendar_max_year = 9999

// CalendarDate is a day of the proleptic Gregorian calendar, without a time or
// a time zone. Build checked values with calendar_date; the struct literal is
// accepted as is. The comparison operators order dates in time.
pub struct CalendarDate {
pub:
	year  int
	month int // 1 to 12
	day   int // 1 to the number of days in the month
}

// CalendarMonth is a year and a month, such as the month a calendar shows.
pub struct CalendarMonth {
pub:
	year  int
	month int // 1 to 12
}

pub fn calendar_is_leap_year(year int) bool {
	return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

// calendar_days_in_month is 28 to 31, or 0 for a month outside 1..12.
pub fn calendar_days_in_month(year int, month int) int {
	return match month {
		1, 3, 5, 7, 8, 10, 12 { 31 }
		4, 6, 9, 11 { 30 }
		2 {
			if calendar_is_leap_year(year) { 29 } else { 28 }
		}
		else { 0 }
	}
}

// calendar_date_valid reports whether the parts name a real day between the
// years 1 and 9999.
pub fn calendar_date_valid(year int, month int, day int) bool {
	return year >= calendar_min_year && year <= calendar_max_year && month >= 1 && month <= 12
		&& day >= 1 && day <= calendar_days_in_month(year, month)
}

// calendar_date returns the date, or an error for a day that does not exist
// (2023-02-29) or a year outside 1..9999.
pub fn calendar_date(year int, month int, day int) !CalendarDate {
	if !calendar_date_valid(year, month, day) {
		return error('${year}-${month}-${day} is not a valid date')
	}
	return CalendarDate{year, month, day}
}

// is_valid reports whether the date names a real day between the years 1 and 9999.
pub fn (d CalendarDate) is_valid() bool {
	return calendar_date_valid(d.year, d.month, d.day)
}

fn datetime_floor_div(a int, b int) int {
	q := a / b
	return if (a % b != 0) && ((a < 0) != (b < 0)) { q - 1 } else { q }
}

fn datetime_floor_mod(a int, b int) int {
	return a - datetime_floor_div(a, b) * b
}

// serial is the number of days since 1970-01-01, negative before it. Two dates
// are n days apart when their serials differ by n.
pub fn (d CalendarDate) serial() int {
	// Days from civil, after Howard Hinnant's public-domain date algorithms.
	y := if d.month <= 2 { d.year - 1 } else { d.year }
	era := datetime_floor_div(y, 400)
	yoe := y - era * 400
	mp := (d.month + 9) % 12
	doy := (153 * mp + 2) / 5 + d.day - 1
	doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468
}

// calendar_date_from_serial is the date a serial (days since 1970-01-01) names.
pub fn calendar_date_from_serial(serial int) CalendarDate {
	z := serial + 719468
	era := datetime_floor_div(z, 146097)
	doe := z - era * 146097
	yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	mp := (5 * doy + 2) / 153
	day := doy - (153 * mp + 2) / 5 + 1
	month := if mp < 10 { mp + 3 } else { mp - 9 }
	year := yoe + era * 400 + if month <= 2 { 1 } else { 0 }
	return CalendarDate{year, month, day}
}

pub fn (d CalendarDate) add_days(days int) CalendarDate {
	return calendar_date_from_serial(d.serial() + days)
}

// add_months moves by whole months and keeps the day when the target month has
// it, else takes the target month's last day: 2024-01-31 plus one month is
// 2024-02-29.
pub fn (d CalendarDate) add_months(months int) CalendarDate {
	target := d.year_month().add(months)
	return CalendarDate{target.year, target.month, math.min(d.day, target.days())}
}

// add_years is add_months(12 * years): 2024-02-29 plus a year is 2025-02-28.
pub fn (d CalendarDate) add_years(years int) CalendarDate {
	return d.add_months(12 * years)
}

// weekday is 0 for Sunday through 6 for Saturday.
pub fn (d CalendarDate) weekday() int {
	// 1970-01-01 was a Thursday.
	return datetime_floor_mod(d.serial() + 4, 7)
}

// day_of_year is 1 for January 1st through 365 or 366.
pub fn (d CalendarDate) day_of_year() int {
	return d.serial() - CalendarDate{d.year, 1, 1}.serial() + 1
}

// days_until is how many days later other is: negative when it is earlier.
pub fn (d CalendarDate) days_until(other CalendarDate) int {
	return other.serial() - d.serial()
}

// week_start is the first day of the week the date is in, for weeks that start
// on first_day_of_week (0 for Sunday, 1 for Monday, ...).
pub fn (d CalendarDate) week_start(first_day_of_week int) CalendarDate {
	return d.add_days(-datetime_floor_mod(d.weekday() - first_day_of_week, 7))
}

// week_end is the last day of the week the date is in.
pub fn (d CalendarDate) week_end(first_day_of_week int) CalendarDate {
	return d.week_start(first_day_of_week).add_days(6)
}

pub fn (d CalendarDate) year_month() CalendarMonth {
	return CalendarMonth{d.year, d.month}
}

pub fn (a CalendarDate) < (b CalendarDate) bool {
	if a.year != b.year {
		return a.year < b.year
	}
	if a.month != b.month {
		return a.month < b.month
	}
	return a.day < b.day
}

// str is the ISO 8601 form, `2026-10-17`.
pub fn (d CalendarDate) str() string {
	return '${d.year:04}-${d.month:02}-${d.day:02}'
}

// calendar_parse_iso reads `YYYY-MM-DD` exactly (four-digit year, two-digit
// month and day) and returns none for anything else, including days that do not
// exist.
pub fn calendar_parse_iso(source string) ?CalendarDate {
	if source.len != 10 || source[4] != `-` || source[7] != `-` {
		return none
	}
	year := datetime_parse_digits(source[0..4]) or { return none }
	month := datetime_parse_digits(source[5..7]) or { return none }
	day := datetime_parse_digits(source[8..10]) or { return none }
	if !calendar_date_valid(year, month, day) {
		return none
	}
	return CalendarDate{year, month, day}
}

// datetime_parse_digits reads a run of ASCII digits, at most nine of them.
fn datetime_parse_digits(digits string) ?int {
	if digits.len == 0 || digits.len > 9 {
		return none
	}
	mut value := 0
	for ch in digits.bytes() {
		if ch < `0` || ch > `9` {
			return none
		}
		value = value * 10 + int(ch - `0`)
	}
	return value
}

// calendar_today is the current date on the system clock, in local time.
pub fn calendar_today() CalendarDate {
	now := time.now()
	return CalendarDate{now.year, now.month, now.day}
}

// calendar_month normalizes month into 1..12, carrying whole years: month 13
// of 2026 is January 2027 and month 0 is December 2025.
pub fn calendar_month(year int, month int) CalendarMonth {
	total := year * 12 + month - 1
	return CalendarMonth{datetime_floor_div(total, 12), datetime_floor_mod(total, 12) + 1}
}

pub fn (m CalendarMonth) add(months int) CalendarMonth {
	return calendar_month(m.year, m.month + months)
}

// index counts months from January of year 0, so two months are n apart when
// their indices differ by n.
pub fn (m CalendarMonth) index() int {
	return m.year * 12 + m.month - 1
}

pub fn (m CalendarMonth) days() int {
	return calendar_days_in_month(m.year, m.month)
}

pub fn (m CalendarMonth) first_day() CalendarDate {
	return CalendarDate{m.year, m.month, 1}
}

pub fn (m CalendarMonth) last_day() CalendarDate {
	return CalendarDate{m.year, m.month, m.days()}
}

pub fn (m CalendarMonth) is_valid() bool {
	return m.month >= 1 && m.month <= 12 && m.year >= calendar_min_year
		&& m.year <= calendar_max_year
}

pub fn (a CalendarMonth) < (b CalendarMonth) bool {
	return a.index() < b.index()
}

// str is `2026-10`.
pub fn (m CalendarMonth) str() string {
	return '${m.year:04}-${m.month:02}'
}

// calendar_month_weeks lists the weeks a month grid shows, each seven dates
// starting on first_day_of_week (0 for Sunday). The first week holds the
// month's first day and the last week its last day, so dates of the months
// around it fill the ends. With fixed_weeks there are always six weeks, the
// extra ones taken from the next month, so grids of different months line up.
pub fn calendar_month_weeks(month CalendarMonth, first_day_of_week int, fixed_weeks bool) [][]CalendarDate {
	first := month.first_day()
	start := first.week_start(first_day_of_week)
	lead := start.days_until(first)
	count := if fixed_weeks { 6 } else { (lead + month.days() + 6) / 7 }
	mut weeks := [][]CalendarDate{cap: count}
	for w in 0 .. count {
		mut week := []CalendarDate{cap: 7}
		for d in 0 .. 7 {
			week << start.add_days(w * 7 + d)
		}
		weeks << week
	}
	return weeks
}

const calendar_month_names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
	'September', 'October', 'November', 'December']

const calendar_weekday_names = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
	'Saturday']

// calendar_month_name is the English name of month 1..12, or ''.
pub fn calendar_month_name(month int) string {
	return if month >= 1 && month <= 12 { calendar_month_names[month - 1] } else { '' }
}

// calendar_month_short_name is the three-letter English abbreviation, `Jan`.
pub fn calendar_month_short_name(month int) string {
	return calendar_month_name(month)#[..3]
}

// calendar_weekday_name is the English name of weekday 0 (Sunday) to 6, or ''.
pub fn calendar_weekday_name(weekday int) string {
	return if weekday >= 0 && weekday <= 6 { calendar_weekday_names[weekday] } else { '' }
}

// calendar_weekday_short_name is the two-letter abbreviation a calendar grid
// heads its columns with, `Su` to `Sa`.
pub fn calendar_weekday_short_name(weekday int) string {
	return calendar_weekday_name(weekday)#[..2]
}

// calendar_format writes a date with strftime-style directives: %Y (2026),
// %y (26), %m (01), %-m (1), %d (07), %-d (7), %e (` 7`), %B (January),
// %b (Jan), %A (Monday), %a (Mon), %j (day of year, 007) and %% (%). Anything
// else is copied as written. Names are English.
pub fn calendar_format(d CalendarDate, format string) string {
	mut out := []u8{cap: format.len + 8}
	mut i := 0
	for i < format.len {
		ch := format[i]
		if ch != `%` || i + 1 >= format.len {
			out << ch
			i++
			continue
		}
		mut directive := format[i + 1]
		mut used := 2
		unpadded := directive == `-` && i + 2 < format.len
		if unpadded {
			directive = format[i + 2]
			used = 3
		}
		piece := match directive {
			`Y` { '${d.year:04}' }
			`y` { '${datetime_floor_mod(d.year, 100):02}' }
			`m` {
				if unpadded { d.month.str() } else { '${d.month:02}' }
			}
			`d` {
				if unpadded { d.day.str() } else { '${d.day:02}' }
			}
			`e` { '${d.day:2}' }
			`B` { calendar_month_name(d.month) }
			`b` { calendar_month_short_name(d.month) }
			`A` { calendar_weekday_name(d.weekday()) }
			`a` { calendar_weekday_name(d.weekday())#[..3] }
			`j` { '${d.day_of_year():03}' }
			`%` { '%' }
			else { format[i..i + used] }
		}
		out << piece.bytes()
		i += used
	}
	return out.bytestr()
}

// calendar_long_label is how a day is announced: `Saturday, October 17, 2026`.
fn calendar_long_label(d CalendarDate) string {
	return calendar_format(d, '%A, %B %-d, %Y')
}

// datetime_inset shrinks a frame by dx and dy on each side, never below zero.
fn datetime_inset(frame Rect, dx f64, dy f64) Rect {
	x := math.min(dx, frame.width / 2)
	y := math.min(dy, frame.height / 2)
	return rect(frame.x + x, frame.y + y, frame.width - 2 * x, frame.height - 2 * y)
}

// datetime_center places a w by h box in the middle of frame.
fn datetime_center(frame Rect, w f64, h f64) Rect {
	width := math.max(0.0, math.min(w, frame.width))
	height := math.max(0.0, math.min(h, frame.height))
	return rect(frame.x + (frame.width - width) / 2, frame.y + (frame.height - height) / 2,
		width, height)
}
