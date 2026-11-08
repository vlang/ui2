# Date and time components

Ports of GPUI Kit's
[calendar](https://github.com/longbridge/gpui-kit/blob/main/website/component/calendar.md),
[date picker](https://github.com/longbridge/gpui-kit/blob/main/website/component/date-picker.md)
and [time field](https://github.com/longbridge/gpui-kit/blob/main/website/component/time-field.md).
The implementation is in `ui/component_datetime.v` (the date and time value
types and their arithmetic), `ui/component_datetime_calendar.v`,
`ui/component_datetime_picker.v` and `ui/component_datetime_time.v`;
`examples/gpui_datetime/main.v` shows every component with working state and
keyboard handling, and `ui/component_datetime_test.v` covers the logic.

## Conventions

- Every builder takes a config struct and returns `!Element`. The frame must be
  finite and non-negative, child frames are parent-local, and every one of
  these components needs a non-empty `id`.
- State is controlled. Each component has a state struct the application
  stores (`CalendarState`, `TimeFieldState`; a date picker adds an `open`
  flag). A decoder turns an action into an event that carries **the next
  state**: store it and rebuild. Decoders take the config the component was
  built with, so build the config from the model in one function and use it in
  both places. They return `none` for foreign, malformed and forged actions,
  for anything while the component is disabled, for disabled days and for
  actions that change nothing.
- Components cannot capture keys. Each has a key decoder
  (`calendar_key_event`, `date_picker_key_event`, `time_field_key_event`) to
  call from `on_key_event` while the application treats the component as
  focused; call `ui2.consume_key()` when it returns an event. None of these
  components contains a native text field. While no text field elsewhere in
  the window holds focus, the custom renderer delivers every key to
  `on_key_event`, and AppKit every key its window receives.
- Focus is the application's notion: ui2 reports no focus changes and these
  parts are not native focus targets. The gallery keeps the name of the last
  component used and sends keys there; `CalendarState.blurred()` and
  `TimeFieldState.blurred()` drop the focus ring and segment highlight when it
  moves on.
- `size` is `ComponentSize` and colors come from `ComponentTheme`. Clickable
  parts are views with button behavior (README, "Custom buttons"), so every
  color, including selected and disabled ones, is the component's own.

## Dates and times

`CalendarDate{year, month, day}` is a proleptic Gregorian day with no time zone,
`CalendarMonth{year, month}` a month and `TimeOfDay{hour, minute, second}` a
wall-clock time. The comparison operators order them. Missing values are `none`
(`?CalendarDate`), never a sentinel. The arithmetic is plain integer arithmetic
on year, month and day, so it needs no clock and no time zone; only
`calendar_today()` and `time_of_day_now()` read the system clock (local time).

| Function | Purpose |
| --- | --- |
| `calendar_date(y, m, d) !CalendarDate`, `.is_valid()`, `calendar_date_valid` | A checked date between the years 1 and 9999. |
| `calendar_is_leap_year`, `calendar_days_in_month` | Gregorian rules: 2000 is a leap year, 1900 is not. |
| `.add_days(n)`, `.add_months(n)`, `.add_years(n)` | `add_months` keeps the day or takes the month's last: Jan 31 + 1 month is Feb 28 or 29. |
| `.serial()`, `calendar_date_from_serial(n)`, `.days_until(other)` | Days since 1970-01-01. |
| `.weekday()` (0 is Sunday), `.week_start(first)`, `.week_end(first)`, `.day_of_year()` | Weeks start on any weekday. |
| `.str()`, `calendar_parse_iso(text) ?CalendarDate` | `2026-10-17`, parsed strictly. |
| `calendar_format(date, format)` | strftime-style `%Y %y %m %-m %d %-d %e %B %b %A %a %j %%`; English names. |
| `calendar_month(y, m)`, `.add(n)`, `.first_day()`, `.last_day()`, `.days()` | `calendar_month(2026, 13)` is January 2027. |
| `calendar_month_weeks(month, first_day_of_week, fixed_weeks)` | The weeks a month grid shows. |
| `calendar_month_name`, `calendar_month_short_name`, `calendar_weekday_name`, `calendar_weekday_short_name` | English names. |
| `time_of_day(h, m, s) !TimeOfDay`, `.seconds()`, `time_of_day_from_seconds(n)` | Seconds since midnight; the latter wraps around the day. |
| `time_format(t, precision, hour_cycle)`, `time_parse(text) ?TimeOfDay` | `09:30`, `09:30:15`, `09:30 PM`; parsing also takes `9:30pm` and `9p`. |

## Calendar

```v
fn trip_config(m &Model) ui2.CalendarConfig {
	w, h := ui2.calendar_size(.medium, 2)
	return ui2.CalendarConfig{
		id:       'trip'
		frame:    ui2.rect(24, 24, w, h)
		state:    m.trip // ui2.CalendarState
		mode:     .range
		months:   2
		min:      m.today
		disabled: [ui2.calendar_disable_weekdays(0, 6)]
	}
}

// build:
ui2.calendar(trip_config(m)) or { panic(err) }

// on_event:
if ev := ui2.calendar_event(trip_config(m), action) {
	m.trip = ev.state
	if ev.kind == .select && ev.complete {
		// m.trip.start and m.trip.end hold the range
	}
}

// on_key_event, while the application treats the calendar as focused:
if ev := ui2.calendar_key_event(trip_config(m), event) {
	ui2.consume_key()
	m.trip = ev.state
}
```

`CalendarConfig`: `id`, `frame`, `state`, `mode` (`.single` or `.range`),
`months` (side by side, 1 to 12), `first_day_of_week` (0 for Sunday, the
default, to 6), `today` (none reads the system date; pass it to keep tests and
screenshots stable, and rebuild after midnight), `min` and `max` (bounds for
picking, navigation and keyboard focus), `disabled` (a list of matchers),
`year_from` and `year_to` (the years view, `[from, to)`; 0 is fifty years either
side of today), `show_outside_days` (default true), `fixed_weeks` (always six
rows), `hover` (default true), `bordered` (default true), `month_names` and
`weekday_names` (localized labels, January and Sunday first), `enabled`,
`accessibility_label`, `size`, `theme`.

`CalendarState`: `month` (first visible month; the zero value shows the
selection's month, or today's, within min and max), `view` (`.days`, `.months`,
`.years`), `year_page` (first year of the years view's page; 0 picks the page
holding the visible year), `start`, `end`, `focused`, `hovered`.

| Function | Purpose |
| --- | --- |
| `calendar(config) !Element` | The calendar. |
| `calendar_size(size, months) (f64, f64)` | Its natural size, with room for six weeks: one medium month is 248 × 276, as wide as upstream's. Larger frames spread the cells, smaller ones shrink them. |
| `calendar_event(config, action) ?CalendarEvent` | Decodes days, previous/next, the month and year toggles, the months and years grids, and hover. |
| `calendar_key_event(config, event) ?CalendarEvent` | The keyboard (below). |
| `calendar_select(config, date) ?CalendarState` | The selection rule on its own, for picking a date from code. |
| `calendar_key_target(date, event, first_day_of_week) ?CalendarDate` | Where a navigation key moves. |
| `calendar_date_disabled(config, date)` | min, max and the matchers. |
| `calendar_visible_months(config)`, `calendar_day_action_id(id, date)` | What is on screen; a day's action. |
| `calendar_disable_weekdays(0, 6)`, `calendar_disable_dates(...)`, `calendar_disable_range(from, to)`, `calendar_disable_outside(from, to)`, `calendar_disable_if(fn)` | Matchers. Range and outside take `none` for an open end; a predicate can be a closure (`fn [holidays] (d ui2.CalendarDate) bool { return d in holidays }`). |

`CalendarEvent` has a `kind` (`.select`, `.navigate`, `.view`, `.focus`,
`.hover`), the `date` involved, `complete` (a select that finished the
selection) and the next `state`.

Selection follows GPUI Kit. Single mode replaces the date; picking the selected
date again changes nothing. Range mode takes a start, then an end on or after
it; a day before the start, or any day once both ends are set, starts a new
range. While only the start is picked, the hovered day previews the range in a
lighter band. Picking a day in the grid of a neighbouring month (an outside
day) turns the view only as far as needed to show it.

The header has previous and next buttons, which stop at the months that hold
`min` and `max`. With one month, the month name and year are toggles that open
a 3 × 4 months grid and a 5 × 4 years grid paged by twenty years, as upstream;
picking one returns to the days. With several months each month is titled
instead.

| Key (days view) | Action |
| --- | --- |
| ←, → | Previous or next day |
| ↑, ↓ | Same weekday a week earlier or later |
| Page Up, Page Down | A month earlier or later; with Shift, a year |
| Home, End | First or last day of the week, following `first_day_of_week` |
| Enter, Space | Pick the focused day |
| Escape | In the months and years views: back to the days |

The first navigation key only shows the focus ring, on the selected day if it
is on screen, else on today, else on the first day of the month. Focus stays
within `min` and `max` and the months turn to follow it. It may rest on a
disabled day, which Enter then does not pick (the WAI-ARIA date grid pattern).

| GPUI Kit | ui2 |
| --- | --- |
| Single date and range (`Date::Single`, `Date::Range`), initial date | `mode`, `state.start`/`state.end` |
| `number_of_months` | `months`, 1 to 12 |
| Sizes | `size` |
| `first_day_of_week` | Implemented |
| `disabled_matcher`: weekdays, range, interval, custom | `disabled`, a list (upstream takes one matcher), plus a list of dates, `min` and `max` |
| Previous/next month, month picker, year picker with twenty-year pages, `year_range` | Implemented; `year_from`/`year_to` |
| Outside-month days (muted) | Implemented; `show_outside_days: false` hides them, which suits several months |
| Today marker, hover highlight | Implemented; hover through pointer events and `state.hovered` |
| `CalendarEvent::Selected` | `.select` events with `complete` |
| — | Added: range hover preview, keyboard navigation, `fixed_weeks`, localized labels |
| Item and label slots (`Calendar::item`, `Calendar::label`) | Labels through `month_names` and `weekday_names`. Arbitrary cell content is omitted: build a custom grid from `calendar_month_weeks`, `calendar_day_action_id` and `calendar_event`. |
| Style refinements (`.p_4()`, `.bg()`, `.border_2()`, `.rounded()`, `.w()`, `.h()`) | The frame sizes it and the theme colors it; `bordered: false` drops the border. ui2 components take no style refinements. |
| i18n through `rust_i18n` | `month_names`, `weekday_names`; `calendar_format` and the accessibility labels are English. |

## Date picker

A date picker is two elements: `date_picker(config)`, the trigger field, which
goes wherever the form puts it, and `date_picker_overlay(config)`, which the
application adds **after every other element** so the open popover draws on top.
The overlay is a hidden, empty view while the picker is closed.

```v
fn due_config(m &Model) ui2.DatePickerConfig {
	b := ui2.bounds()
	return ui2.DatePickerConfig{
		id:            'due'
		frame:         ui2.rect(24, 24, 260, 32)
		calendar:      ui2.CalendarConfig{
			state:       m.due // ui2.CalendarState
			fixed_weeks: true
		}
		open:          m.due_open
		window_width:  b.width
		window_height: b.height
		format:        '%B %-d, %Y'
		clearable:     true
		presets:       ui2.date_presets_recent(ui2.calendar_today())
	}
}

// build:
c << ui2.date_picker(due_config(m)) or { panic(err) }
// ... every other element ...
c << ui2.date_picker_overlay(due_config(m)) or { panic(err) }

// on_event:
if ev := ui2.date_picker_event(due_config(m), action) {
	m.due = ev.state
	m.due_open = ev.open
	m.due_time = ev.time // only with with_time
}

// on_key_event, while the application treats the picker as focused:
if ev := ui2.date_picker_key_event(due_config(m), event) {
	ui2.consume_key()
	// store ev.state, ev.open and ev.time as above
}
```

`DatePickerConfig`: `id`, `frame` (the trigger), `calendar` (a
`CalendarConfig` for the mode, the state with the selection, months, bounds,
disabled days, today and labels; the picker sets its id, frame, size, theme,
`enabled` and border), `open`, `window_width` and `window_height` (required
while open), `anchor` (the trigger in window coordinates, when `frame` is
relative to a nested parent), `format` (`calendar_format` directives, default
`%Y/%m/%d` as upstream), `placeholder`, `clearable`, `presets`, `with_time` and
`time` (below), `enabled`, `invalid`, `accessibility_label`, `size`, `theme`.

`DatePickerEvent` has a `kind` (`.open`, `.close`, `.select`, `.clear`,
`.calendar`, `.time`) and the three things to store: `open`, `state` and
`time`. Opening shows the selection's month (or today's) in the days view.
Picking a date closes the popover; in range mode the first day keeps it open
and the second closes it. Picking the selected date again closes it too, as
does a click anywhere outside the popover, Escape and Enter. A preset applies
its date or range and closes. The clear button (shown instead of the calendar
icon while a clearable picker has a value), Backspace and Delete empty the
selection.

| Function | Purpose |
| --- | --- |
| `date_picker(config) !Element` | The trigger: the formatted value or the placeholder, and a calendar icon or a clear button. Its role is `combobox`. |
| `date_picker_overlay(config) !Element` | The backdrop, the popover surface (border, radius, shadow) and the presets, calendar and time field on it. |
| `date_picker_event(config, action)`, `date_picker_key_event(config, event)` | Decoders. Closed, Enter, Space and ↓ open the popover; open, keys go to the calendar or the focused time field, and Tab moves between them. |
| `date_picker_text(config)` | What the trigger shows: `2026/10/09`, a range as `start – end` (`start – …` while its end is open), with the time when there is one. |
| `date_picker_popover_frame(anchor, width, height, window_width, window_height) Rect` | Where the popover goes (below). |
| `date_picker_popover_size(config) (f64, f64)` | The popover's size. |
| `date_preset(label, date)`, `date_range_preset(label, start, end)` | Presets. |
| `date_presets_recent(today)`, `date_range_presets_recent(today)` | Today / Yesterday / A week ago, and Today / Last 7 days / Last 30 days / This month / Last month. |

### Placing the popover

`date_picker_popover_frame` is the only placement logic the picker has, a pure
function of the anchor, the popover's size and the window size. The popover
goes below the trigger, left edges aligned, 4 points apart; above it when it
does not fit below but fits above; and when it fits on neither side, on the
side with more room, pushed into the window. It moves left as far as needed to
stay 8 points inside the window's right edge. When ui2 gains a shared popover,
`date_picker_overlay` can hand the popover's content to it and drop this
function and the backdrop without changing the rest of the API.

The backdrop is a transparent view with button behavior covering the window,
so a click outside the popover closes it instead of reaching the control under
it. The popover's surface takes clicks between the controls, which would
otherwise fall through to the backdrop.

### Date and time

With `with_time: true` (single mode; a range picker edits dates only, as
upstream) the popover shows a time field below the calendar, configured by
`time` (a `TimeFieldConfig`: its state, precision, hour cycle, steps and
bounds; the picker sets its id, frame, size and theme). Picking a date keeps
the popover open so the time can be set next; picking the selected date again,
Enter, Escape or an outside click close it. The trigger shows the date followed
by the time (`2026/10/21 02:30 PM`).

| GPUI Kit | ui2 |
| --- | --- |
| Single and range pickers, initial value | `calendar.mode`, `calendar.state` |
| `number_of_months`, `first_day_of_week`, `disabled_matcher`, `set_year_range` | Through `calendar` |
| `date_format` (chrono) | `format`, a strftime subset |
| `placeholder`, `cleanable`, sizes, `disabled` | `placeholder`, `clearable`, `size`, `enabled` |
| Presets: single and range | Implemented, with ready-made recent presets |
| `DateRangePreset::date_time` (a preset with times) | Omitted: presets set dates; the time keeps its value. |
| `time_precision`, `hour_cycle`, `default_time`, `date_time()`, `set_date_time()` | `with_time` and `time`; the application owns the time state, so a default time is its initial value |
| Keep open after a pick, close on reselect, Enter, Escape, outside click | Implemented |
| Delete and Backspace clear | Implemented for clearable pickers |
| `DatePickerEvent::Change` | `.select` and `.clear` events |
| `appearance(false)` | Omitted: the trigger's frame and border are part of the component. |
| Focus ring | The trigger's border takes the primary color while the popover is open. |
| Popover positioning | `date_picker_popover_frame`, flipping above when there is no room below |
| — | Added: `invalid`, `anchor` for nested layouts |

## Time field

```v
fn alarm_config(m &Model) ui2.TimeFieldConfig {
	config := ui2.TimeFieldConfig{
		id:          'alarm'
		state:       m.alarm // ui2.TimeFieldState
		hour_cycle:  .h12
		minute_step: 5
		min:         ui2.TimeOfDay{6, 0, 0}
	}
	return ui2.TimeFieldConfig{
		...config
		frame: ui2.rect(24, 24, ui2.time_field_width(config), 32)
	}
}

// build:
ui2.time_field(alarm_config(m)) or { panic(err) }

// on_event: a click on a segment or a stepper.
if ev := ui2.time_field_event(alarm_config(m), action) {
	m.alarm = ev.state // ev.kind == .change when the time changed
}

// on_key_event, while m.alarm.focused:
if ev := ui2.time_field_key_event(alarm_config(m), event) {
	ui2.consume_key()
	m.alarm = ev.state
}
```

`TimeFieldConfig`: `id`, `frame`, `state`, `precision` (`.minute` or
`.second`), `hour_cycle` (`.h23` or `.h12`, with an AM/PM segment),
`minute_step` and `second_step` (1 to 59), `min` and `max`, `steppers`
(default true), `enabled`, `invalid`, `accessibility_label`, `size`, `theme`.
`TimeFieldState`: `time`, `segment` (the one keys edit), `pending` (a first
digit waiting for a second, -1 for none) and `focused`.

| Function | Purpose |
| --- | --- |
| `time_field(config) !Element` | The field. |
| `time_field_width(config)` | Its natural width, for the frame. |
| `time_field_event(config, action) ?TimeFieldEvent` | A click on a segment selects it and focuses the field; a stepper steps the selected segment. |
| `time_field_key_event(config, event) ?TimeFieldEvent` | The keyboard (below). |
| `time_field_step(config, segment, direction) ?TimeOfDay` | One step, for stepping from code. |
| `time_in_range(config, t)` | Whether a time lies within `min` and `max`. |
| `time_segments`, `time_segment_value`, `time_segment_text`, `time_with_segment` | Segment helpers: on a 12-hour clock 12 AM is midnight and 12 PM noon. |
| `time_field_segment_action_id(id, segment)` | A segment's action. |

| Key | Action |
| --- | --- |
| ↑, ↓ | Step the selected segment; it wraps without changing the next one (59 minutes steps to 00 in the same hour), as upstream |
| ←, → | Move between segments |
| Tab, Shift-Tab | Move between segments; at either end `none`, so the application moves focus on |
| 0–9 (also the keypad) | Type the segment: a first digit that could start two digits waits for the second, a pair that does not fit starts over from the second digit, and a complete value moves to the next segment |
| A, P | Set AM or PM in the period segment |
| Backspace, Delete | Reset the segment to its first value (00, or 12 on a 12-hour clock) |

Steps move minutes and seconds to multiples of `minute_step` and
`second_step` (with 15: 07 steps up to 15 and down to 00). A step that would
leave `min`..`max` lands on the bound, and one that cannot move returns `none`;
the steppers are disabled then. Typed times are kept even outside the bounds,
like typed numbers in a number input, and the field draws the danger border
until the time is back in range (`invalid` forces it).

Digits are read from the physical key, with or without Shift, so they work on
layouts such as AZERTY that need Shift for the digit row. A and P are physical
keys too (`KeyCode` follows US key positions), so on layouts that move them
the period is set with ↑ and ↓ instead.

### Why segments

The field edits one segment at a time, as GPUI Kit's does, rather than parsing
the text of a native field:

- A native field reports only its whole text. ui2 does not expose the caret,
  so the arrow keys could not tell which part to step, and every keystroke
  would have to be parsed back into a time while the user is halfway through
  typing one.
- Segments keep the value valid at every step and make the 12-hour clock,
  steps and bounds easy to follow, which is where free-form time entry goes
  wrong.
- The cost is that typing needs the keyboard path through `on_key_event`, and
  a native text field elsewhere in the window that holds focus receives the
  keys instead. The stepper buttons (an addition to upstream) make the field
  usable with a pointer or touch alone, which also covers iOS, where there is
  no hardware keyboard to type segments with. For free-form entry, put a text
  field next to it and convert with `time_parse` and `time_format`.

| GPUI Kit | ui2 |
| --- | --- |
| Hours and minutes, optional seconds (`TimePrecision`) | `precision` |
| 24-hour and 12-hour clocks (`HourCycle`) | `hour_cycle` |
| `set_time` without an event, `Change` on edits | The application owns `state.time`; `.change` events |
| Keyboard model (↑/↓, ←/→, Tab, digits, a/p, Backspace/Delete) | Implemented as upstream |
| Click a segment to select it | Implemented |
| Sizes, `disabled`, `invalid` | Implemented; times outside `min`/`max` are drawn as invalid too |
| — | Added: `minute_step`, `second_step`, `min`, `max`, stepper buttons, `time_parse` |
| Tabular figures (constant width while typing) | Each segment has a fixed width, so the field keeps its width without them. |

## Accessibility

The calendar is a `group` labelled `Calendar` (or `accessibility_label`) whose
value names the visible month. Each day is a button labelled with the full
date (`Saturday, October 17, 2026`) and a value listing `selected`,
`range start`, `range end`, `in range`, `today` and `unavailable` as they
apply; disabled days are not enabled. The navigation buttons, toggles and
picker cells are labelled buttons. The date picker trigger has the `combobox`
role with the formatted value, and the popover is a `dialog`. Time segments
use the `spinbutton` role with labels Hour, Minute, Second and AM/PM; AppKit
does not map `spinbutton` yet, so they keep their native role there.
