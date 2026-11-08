module main

import math
import ui2

// A chat channel on a message scroller: three thousand messages of different
// heights, of which only the ones in view are built. It opens at the first
// message that arrived since the last visit, with the rest counted as new.
// New messages, a streamed reply and earlier history can be added from the
// panel on the right; scrolling near the top loads earlier history by itself.
// The application owns the messages and their heights and keeps the
// scroller's state next to them; every scroll the state asks for goes to
// scroll_to_offset through flush().

const feed_id = 'feed'
const composer_id = 'composer'
const window_width = 1180
const window_height = 780

// The channel's history runs from message 0; the window opens with 2,000 to
// 4,999 loaded, and 4,986 is the first one the reader has not seen.
const history_first = 0
const opened_first = 2000
const opened_last = 4999
const opened_unread = 4986
const earlier_batch = 50
const earlier_threshold = 8

const margin = 20.0
const side_width = 290.0
const content_top = 84.0
const card_header = 60.0
const composer_height = 64.0
const row_inset = 16.0

// Row metrics. Text is laid out by the backend, so a row's height comes from
// an estimate of how its text wraps; the estimate errs wide, leaving a little
// room rather than cutting a line off.
const body_size = 14.0
const avatar_size = 36.0
const text_x = 50.0

// pt converts a text extent given in points for macOS into the window's
// units: Linux and Windows draw a point at 4/3 of a pixel.
fn pt(value f64) f64 {
	$if linux || windows {
		return math.round(value * 96.0 / 72.0)
	} $else {
		return value
	}
}

fn body_line() f64 {
	return pt(20)
}

fn code_line() f64 {
	return pt(18)
}

// rune_em is about how wide a character is, in ems of the system font; Roboto,
// which the custom renderer draws with, runs some 8% narrower.
fn rune_em(r rune) f64 {
	return match r {
		` ` { 0.27 }
		`i`, `l`, `j`, `I`, `'`, `.`, `,`, `:`, `;`, `!`, `|` { 0.26 }
		`f`, `t`, `r`, `(`, `)`, `-`, `/` { 0.37 }
		`m`, `w` { 0.85 }
		`M`, `W` { 0.95 }
		else {
			if r >= `A` && r <= `Z` {
				0.7
			} else if r >= `0` && r <= `9` {
				0.6
			} else if r >= 0x2e80 {
				1.0
			} else {
				0.56
			}
		}
	}
}

fn text_width(text string, size f64, bold bool) f64 {
	mut ems := 0.0
	for r in text.runes() {
		ems += rune_em(r)
	}
	face := $if ui2_custom_rendering ? { 0.94 } $else { 1.0 }
	return ems * pt(size) * face * if bold { 1.1 } else { 1.0 }
}

struct Author {
	name  string
	color u32
}

const authors = [
	Author{'Ada Lovelace', 0x7c3aed},
	Author{'Grace Hopper', 0x0369a1},
	Author{'Linus Torvalds', 0xc2410c},
	Author{'Margaret Hamilton', 0x047857},
	Author{'You', 0xbe185d},
]
const you = 4
const streamer = 0

const sentences = [
	'The scroller only builds the rows near the viewport, so three thousand messages cost about as much as twenty.',
	'Can someone check the dark theme on the jump pill?',
	'I pushed the anchoring fix: prepending history keeps the row you are reading exactly where it was.',
	'Looks good on my side.',
	'Streaming replies grow the last row, and the view sticks to the bottom only when you were already there.',
	'Agreed, let us not yank people back down while they are reading older messages.',
	'The unread count drops as rows come into view, like a read marker.',
	'Did anyone try it with a trackpad? Momentum scrolling feels right on AppKit.',
	'Row heights come from the application, so the estimate has to err on the generous side.',
	'Shipping the release notes this afternoon.',
	'One question: what happens when the window gets narrower and every message reflows?',
	'The row at the top stays put and everything below it moves, which is what you want.',
	'Nice.',
	'I will review the docs after lunch.',
	'Load-earlier triggers a few rows before the top, so the history usually arrives before you get there.',
	'We should keep the composer outside the list, as upstream recommends.',
	'Thanks for the quick turnaround on this one!',
	'The custom renderer and AppKit agree on every pixel I compared so far.',
	'Let us pair on the accessibility labels tomorrow morning.',
	'Pinned the design spec in the channel details.',
]

const code_snippets = [
	['state = state.append(layout)!', 'state = state.prepend(layout)!',
		'state = state.remeasure(layout)!'],
	['if request := app.feed.take_scroll_request(feed_id) {',
		'    ui2.scroll_to_offset(request.id, request.offset)', '}'],
	['fn on_scroll(id string) {',
		'    step := ui2.message_scroller_scroll(config, id, ui2.scroll_offset(id)) or { return }',
		'    app.feed = step.state', '    if step.rebuild { ui2.request_refresh() }', '}'],
	['v test ui/component_messages_test.v',
		'v -d ui2_custom_rendering test ui/component_messages_test.v'],
]

const files = [
	['message-scroller-spec.pdf', '2.4 MB'],
	['jump-pill-dark.png', '312 KB'],
	['anchoring-notes.md', '9 KB'],
	['release-checklist.xlsx', '48 KB'],
]

const stream_text = 'Here is how the scroller decides what to do. While you are at the bottom it follows the tail: a new message, or this reply growing word by word, keeps the latest line in view. Scroll up a little and it stops following, so the text you are reading stays where it is while this message keeps growing below. The rows that arrive in the meantime are counted, and the pill at the bottom takes you back to the latest one. Loading earlier history works the other way round: the rows go in above you, and the row at the top of the view stays exactly where it was.'

struct Message {
mut:
	serial    int
	author    int
	body      string
	code      []string
	file      int = -1
	streaming bool
}

@[heap]
struct App {
mut:
	dark      bool
	messages  []Message
	heights   []f64
	row_width f64
	feed      ui2.MessageScrollerState
	built     ui2.VirtualListRange
	top_row   int
	loading   bool
	stream    int = -1 // The serial of the message being streamed.
	words     []string
	word      int
	sent      bool // The composer's text was sent and has to be cleared.
}

const app_state = &App{}

fn app() &App {
	return unsafe { app_state }
}

// ── Generated history ───────────────────────────────────────────────

fn mix(seed int, salt int) u32 {
	mut x := u32(seed) * u32(2654435761) + u32(salt) * u32(0x9e3779b9)
	x ^= x >> 16
	x *= u32(0x85ebca6b)
	x ^= x >> 13
	x *= u32(0xc2b2ae35)
	x ^= x >> 16
	return x
}

fn pick(seed int, salt int, n int) int {
	return int(mix(seed, salt) % u32(n))
}

fn author_of(serial int) int {
	if serial > opened_last {
		return pick(serial, 1, 4)
	}
	// Runs of two or three messages by one person.
	return pick(serial / 3 + pick(serial / 7, 2, 2), 1, 4)
}

fn generated(serial int) Message {
	count := 1 + pick(serial, 3, 3)
	mut parts := []string{cap: count}
	for i in 0 .. count {
		parts << sentences[pick(serial, 10 + i, sentences.len)]
	}
	return Message{
		serial: serial
		author: author_of(serial)
		body:   if pick(serial, 4, 5) == 0 { parts[0] } else { parts.join(' ') }
		code:   if pick(serial, 5, 9) == 0 {
			code_snippets[pick(serial, 6, code_snippets.len)]
		} else {
			[]string{}
		}
		file:   if pick(serial, 7, 11) == 0 { pick(serial, 8, files.len) } else { -1 }
	}
}

// minute_of is when a message was sent, in minutes from the start of today:
// nine minutes apart, give or take, up to the last one before the window
// opened at 14:32, and a minute apart after that.
fn minute_of(serial int) int {
	last := 14 * 60 + 32
	if serial > opened_last {
		return last + serial - opened_last
	}
	return last - (opened_last - serial) * 9 + pick(serial, 9, 5)
}

fn day_of(serial int) int {
	minute := minute_of(serial)
	return if minute >= 0 { minute / 1440 } else { -((-minute + 1439) / 1440) }
}

fn clock(serial int) string {
	minute := minute_of(serial) - day_of(serial) * 1440
	return '${minute / 60:02}:${minute % 60:02}'
}

fn day_label(day int) string {
	if day == 0 {
		return 'Today'
	}
	if day == -1 {
		return 'Yesterday'
	}
	date := ui2.calendar_today().add_days(day)
	return '${ui2.calendar_weekday_name(date.weekday())}, ${ui2.calendar_month_name(date.month)} ${date.day}'
}

fn starts_day(serial int) bool {
	return serial == history_first || day_of(serial) != day_of(serial - 1)
}

fn starts_unread(serial int) bool {
	return serial == opened_unread
}

// continues is whether a message goes under the previous one's name.
fn continues(m Message, previous_author int) bool {
	return m.serial > history_first && !starts_day(m.serial) && !starts_unread(m.serial)
		&& m.author == previous_author && m.serial <= opened_last
}

fn group_digits(value int) string {
	digits := value.str()
	mut out := ''
	for index, ch in digits {
		if index > 0 && (digits.len - index) % 3 == 0 {
			out += ','
		}
		out += ch.ascii_str()
	}
	return out
}

// ── Row geometry ────────────────────────────────────────────────────

// text_lines estimates how many lines body wraps onto in width, breaking
// between words as the backends do.
fn text_lines(body string, width f64) int {
	room := width * 0.98
	space := text_width(' ', body_size, false)
	mut lines := 1
	mut used := 0.0
	for word in body.split(' ') {
		w := text_width(word, body_size, false)
		if used > 0 && used + space + w > room {
			lines++
			used = 0
		}
		if w > room {
			lines += int(w / room)
			used = math.fmod(w, room)
		} else {
			used += if used > 0 { space + w } else { w }
		}
	}
	return lines
}

struct RowParts {
	beginning bool
	day       bool
	unread    bool
	header    bool // The author's name and the time.
	lines     int
}

fn (a &App) previous_author(m Message) int {
	first := if a.messages.len > 0 { a.messages[0].serial } else { m.serial }
	if m.serial - 1 >= first && m.serial - 1 - first < a.messages.len {
		return a.messages[m.serial - 1 - first].author
	}
	return author_of(m.serial - 1)
}

fn (a &App) parts_of(m Message, width f64) RowParts {
	return RowParts{
		beginning: m.serial == history_first
		day:       starts_day(m.serial)
		unread:    starts_unread(m.serial)
		header:    !continues(m, a.previous_author(m))
		lines:     text_lines(if m.body.len > 0 { m.body } else { '…' }, width - text_x)
	}
}

const beginning_height = 88.0
const day_height = 44.0
const unread_height = 28.0
const file_height = 52.0

fn (a &App) row_height(m Message, width f64) f64 {
	p := a.parts_of(m, width)
	mut h := 0.0
	if p.beginning {
		h += beginning_height
	}
	if p.day {
		h += day_height
	}
	if p.unread {
		h += unread_height
	}
	h += if p.header { 8.0 + pt(22) } else { 2.0 }
	h += f64(p.lines) * body_line()
	if m.code.len > 0 {
		h += 8 + f64(m.code.len) * code_line() + 16
	}
	if m.file >= 0 {
		h += 8 + file_height
	}
	return h + 6
}

fn (a &App) layout() ui2.VirtualListLayout {
	return ui2.message_scroller_layout(a.heights, 0, 8) or { panic(err) }
}

fn (mut a App) measure_all() {
	a.heights = a.messages.map(a.row_height(it, a.row_width))
}

// ── Building rows ───────────────────────────────────────────────────

fn style(theme ui2.ComponentTheme, size f64, bold bool, muted bool) ui2.TextStyle {
	return ui2.TextStyle{
		color: if muted { theme.muted_foreground } else { theme.foreground }
		size:  size
		bold:  bold
	}
}

fn symbol(name string, frame ui2.Rect, color u32) ui2.Element {
	return ui2.Element{
		...ui2.image('', 'symbol:' + name, frame)
		text_style: ui2.TextStyle{
			color: color
		}
	}
}

fn mix_color(a u32, b u32, t f64) u32 {
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		ca := f64((a >> shift) & 0xff)
		cb := f64((b >> shift) & 0xff)
		out |= u32(math.round(ca + (cb - ca) * t)) << shift
	}
	return out
}

fn initials(name string) string {
	words := name.fields()
	if words.len == 1 {
		return words[0][..1].to_upper()
	}
	return (words[0][..1] + words[words.len - 1][..1]).to_upper()
}

fn (a &App) row_element(theme ui2.ComponentTheme, index int, frame ui2.Rect) ui2.Element {
	m := a.messages[index]
	p := a.parts_of(m, frame.width)
	w := frame.width
	mut children := []ui2.Element{}
	mut y := 0.0
	if p.beginning {
		children << ui2.view('', ui2.rect(0, 16, 52, 52), ui2.BoxStyle{
			bg:     theme.muted
			radius: 12
		}, [
			symbol('number', ui2.rect(14, 14, 24, 24), theme.muted_foreground),
		])
		children << ui2.label('', 'This is the very beginning of #design-review', ui2.rect(68,
			18, w - 68, 26), style(theme, 18, true, false))
		children << ui2.label('', 'Ada Lovelace created this channel for the scroller work. Everything said here since is below.',
			ui2.rect(68, 46, w - 68, 20), style(theme, 13, false, true))
		y += beginning_height
	}
	if p.day {
		caption := day_label(day_of(m.serial))
		pill := math.round(text_width(caption, 12, true) + 28)
		children << ui2.view('', ui2.rect(0, y + 22, w, 1), ui2.BoxStyle{ bg: theme.border },
			[]ui2.Element{})
		children << ui2.view('', ui2.rect(math.round((w - pill) / 2), y + 10, pill, 24),
			ui2.BoxStyle{
				bg:            theme.background
				radius:        12
				border_color:  theme.border
				border_left:   1
				border_top:    1
				border_right:  1
				border_bottom: 1
			}, [
				ui2.label('', caption, ui2.rect(0, 0, pill, 24), ui2.TextStyle{
					...style(theme, 12, true, false)
					align: .center
				}),
			])
		y += day_height
	}
	if p.unread {
		children << ui2.view('', ui2.rect(0, y + 14, w - 52, 1), ui2.BoxStyle{ bg: theme.danger },
			[]ui2.Element{})
		children << ui2.view('', ui2.rect(w - 44, y + 5, 44, 18), ui2.BoxStyle{
			bg:     theme.danger
			radius: 9
		}, [
			ui2.label('', 'New', ui2.rect(0, 0, 44, 18), ui2.TextStyle{
				color: theme.danger_foreground
				size:  11
				bold:  true
				align: .center
			}),
		])
		y += unread_height
	}
	author := authors[m.author]
	if p.header {
		y += 8
		children << ui2.view('', ui2.rect(0, y + 2, avatar_size, avatar_size), ui2.BoxStyle{
			bg:     if a.dark { mix_color(author.color, 0xffffff, 0.12) } else { author.color }
			radius: avatar_size / 2
		}, [
			ui2.label('', initials(author.name), ui2.rect(0, 0, avatar_size, avatar_size),
				ui2.TextStyle{
					color: 0xffffff
					size:  13
					bold:  true
					align: .center
				}),
		])
		name_width := math.ceil(text_width(author.name, 14, true)) + 2
		children << ui2.label('', author.name, ui2.rect(text_x, y, name_width, pt(20)), style(theme,
			14, true, false))
		stamp := if m.streaming { 'writing…' } else { clock(m.serial) }
		children << ui2.label('', stamp, ui2.rect(text_x + name_width + 8, y + 1, 120, pt(20)),
			ui2.TextStyle{
				...style(theme, 12, false, true)
				italic: m.streaming
			})
		y += pt(22)
	} else {
		y += 2
	}
	body_height := f64(p.lines) * body_line()
	children << ui2.label('', if m.body.len > 0 { m.body } else { '…' }, ui2.rect(text_x,
		y, w - text_x, body_height), ui2.TextStyle{
		...style(theme, body_size, false, false)
		lines:  0
		valign: .top
	})
	y += body_height
	if m.code.len > 0 {
		box_width := math.min(w - text_x, 620)
		box_height := f64(m.code.len) * code_line() + 16
		mut code := []ui2.Element{}
		for i, line in m.code {
			code << ui2.label('', line, ui2.rect(12, 8 + f64(i) * code_line(), box_width - 24,
				code_line()), ui2.TextStyle{
				color:       theme.foreground
				size:        12.5
				font_family: 'monospace'
			})
		}
		children << ui2.view('', ui2.rect(text_x, y + 8, box_width, box_height), ui2.BoxStyle{
			bg:            theme.muted
			radius:        8
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, code)
		y += 8 + box_height
	}
	if m.file >= 0 {
		file := files[m.file]
		card_width := math.min(w - text_x, 340)
		children << ui2.view('', ui2.rect(text_x, y + 8, card_width, file_height), ui2.BoxStyle{
			bg:            theme.background
			radius:        10
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, [
			ui2.view('', ui2.rect(8, 8, 36, 36), ui2.BoxStyle{
				bg:     mix_color(theme.primary, theme.background, 0.85)
				radius: 8
			}, [
				symbol('doc.fill', ui2.rect(9, 9, 18, 18), theme.primary),
			]),
			ui2.label('', file[0], ui2.rect(54, 8, card_width - 64, 18), style(theme, 13, true,
				false)),
			ui2.label('', file[1], ui2.rect(54, 27, card_width - 64, 16), style(theme, 12, false,
				true)),
		])
	}
	return ui2.Element{
		...ui2.view('', frame, ui2.BoxStyle{ transparent: true }, children)
		// Keyed by message, so rows keep their views when history goes in above.
		key:                 'm${m.serial}'
		accessibility_role:  'listitem'
		accessibility_label: '${author.name}, ${clock(m.serial)}: ${m.body}'
	}
}

// ── Layout ──────────────────────────────────────────────────────────

struct Frames {
	width    f64
	height   f64
	card     ui2.Rect
	scroller ui2.Rect // In the card.
	side     ui2.Rect
}

fn frames_for(width f64, height f64) Frames {
	card_width := math.max(width - 3 * margin - side_width, 320)
	card := ui2.rect(margin, content_top, card_width, math.max(height - content_top - margin,
		240))
	return Frames{
		width:    width
		height:   height
		card:     card
		scroller: ui2.rect(1, card_header + 1, card.width - 2, card.height - card_header - 2 - composer_height)
		side:     ui2.rect(card.x + card.width + margin, content_top, side_width, card.height)
	}
}

fn frames() Frames {
	win := ui2.bounds()
	return frames_for(win.width, win.height)
}

fn (a &App) feed_config(theme ui2.ComponentTheme, frame ui2.Rect) ui2.MessageScrollerConfig {
	return ui2.MessageScrollerConfig{
		id:                     feed_id
		frame:                  frame
		state:                  a.feed
		item:                   fn [a, theme] (index int, slot ui2.Rect) ui2.Element {
			return a.row_element(theme, index, slot)
		}
		inset:                  row_inset
		load_earlier_threshold: earlier_threshold
		bottom_fade:            true
		empty_title:            'No messages yet'
		empty_description:      'Say hello to start the conversation.'
		accessibility_label:    '#design-review'
		theme:                  theme
	}
}

// ── Building ────────────────────────────────────────────────────────

fn side_button(id string, caption string, icon string, y f64, theme ui2.ComponentTheme, enabled bool) ui2.Element {
	return ui2.styled_button(
		id:      id
		label:   caption
		icon:    icon
		frame:   ui2.rect(0, y, side_width, 34)
		variant: .secondary
		outline: true
		enabled: enabled
		theme:   theme
	) or { panic(err) }
}

fn fact(theme ui2.ComponentTheme, name string, value string, y f64) []ui2.Element {
	return [
		ui2.label('', name, ui2.rect(0, y, 118, 22), style(theme, 13, false, true)),
		ui2.label('', value, ui2.rect(118, y, side_width - 118, 22), style(theme, 13, false,
			false)),
	]
}

fn (a &App) unread_index() int {
	if a.messages.len == 0 {
		return -1
	}
	index := opened_unread - a.messages[0].serial
	return if index >= 0 && index < a.messages.len { index } else { -1 }
}

fn (a &App) side_panel(theme ui2.ComponentTheme, f Frames) ui2.Element {
	s := a.feed
	mut children := [
		ui2.label('', 'Conversation', ui2.rect(0, 0, side_width, 22), style(theme, 15, true,
			false)),
		side_button('append', 'Append a message', 'plus.circle', 30, theme, true),
		side_button('stream', if a.stream >= 0 { 'Stop streaming' } else { 'Stream a reply' },
			if a.stream >= 0 { 'stop.fill' } else { 'bolt' }, 72, theme, true),
		side_button('earlier', 'Load ${earlier_batch} earlier', 'clock.arrow.circlepath',
			114, theme, a.messages.len > 0 && a.messages[0].serial > history_first),
		side_button('jump-unread', 'Jump to the first unread', 'envelope', 156, theme,
			a.unread_index() >= 0),
		side_button('jump-top', 'Jump to the oldest loaded', 'arrow.up', 198, theme, s.item_count() > 0),
		side_button('jump-latest', 'Jump to the latest', 'arrow.down.to.line', 240, theme,
			s.item_count() > 0),
		ui2.label('', 'Scroller state', ui2.rect(0, 296, side_width, 22), style(theme, 15,
			true, false)),
	]
	first := if a.messages.len > 0 { a.messages[0].serial } else { 0 }
	last := if a.messages.len > 0 { a.messages[a.messages.len - 1].serial } else { 0 }
	anchor := s.anchor()
	mut y := 326.0
	facts := [
		['Messages', if s.item_count() > 0 {
			'${group_digits(s.item_count())} (#${group_digits(first)}–#${group_digits(last)})'
		} else {
			'None'
		}],
		['Following the tail', if s.following { 'Yes' } else { 'No' }],
		['Scrolled up', if s.is_scrolled_up() { 'Yes' } else { 'No' }],
		['Unread', if s.unread() > 0 {
			'${s.unread()} from #${group_digits(first + s.first_unread)}'
		} else {
			'None'
		}],
		['Top row', if anchor.index >= 0 { '#${group_digits(first + anchor.index)}' } else { '—' }],
		['Rows built', if a.built.len() > 0 {
			'#${group_digits(first + a.built.start)}–#${group_digits(first + a.built.end - 1)} (${a.built.len()})'
		} else {
			'None'
		}],
		['Scroll element', 'serial ${s.serial}'],
	]
	for item in facts {
		children << fact(theme, item[0], item[1], y)
		y += 24
	}
	children << ui2.label('', 'Scroll up to leave the tail: new and streamed messages then count as unread, and the pill brings you back. Near the top, earlier history loads above you without moving what you read. Resize the window to reflow every row.',
		ui2.rect(0, y + 14, side_width, f.side.height - y - 14), ui2.TextStyle{
			...style(theme, 12.5, false, true)
			lines:  0
			valign: .top
		})
	return ui2.view('', f.side, ui2.BoxStyle{ transparent: true }, children)
}

fn (a &App) card(theme ui2.ComponentTheme, f Frames) ui2.Element {
	card := f.card
	mut children := []ui2.Element{}
	children << ui2.view('', ui2.rect(16, 12, 36, 36), ui2.BoxStyle{
		bg:     theme.muted
		radius: 10
	}, [
		symbol('number', ui2.rect(9, 9, 18, 18), theme.muted_foreground),
	])
	children << ui2.label('', 'design-review', ui2.rect(62, 11, 300, 20), style(theme,
		16, true, false))
	status := if a.loading {
		'Loading earlier messages…'
	} else if a.stream >= 0 {
		'Ada Lovelace is writing…'
	} else if a.feed.unread() > 0 {
		'${message_count(a.feed.unread())} below'
	} else {
		'${group_digits(a.messages.len)} messages · 5 members'
	}
	children << ui2.label('', status, ui2.rect(62, 31, card.width - 120, 18), style(theme,
		12, false, true))
	children << ui2.view('', ui2.rect(0, card_header, card.width, 1), ui2.BoxStyle{
		bg: theme.border
	}, []ui2.Element{})
	children << ui2.message_scroller(a.feed_config(theme, f.scroller)) or { panic(err) }
	composer_y := card.height - composer_height
	children << ui2.view('', ui2.rect(0, composer_y - 1, card.width, 1), ui2.BoxStyle{
		bg: theme.border
	}, []ui2.Element{})
	send_width := 96.0
	children << ui2.text_field_with_submit(composer_id, 'composer-submit', 'Message #design-review',
		'', ui2.rect(16, composer_y + 12, card.width - 32 - send_width - 10, 40), ui2.BoxStyle{
			// No border: each backend draws a standalone field's own frame.
			bg:     theme.background
			radius: 8
		}, style(theme, 14, false, false), 0)
	children << ui2.styled_button(
		id:      'send'
		label:   'Send'
		icon:    'paperplane.fill'
		frame:   ui2.rect(card.width - 16 - send_width, composer_y + 12, send_width, 40)
		variant: .primary
		theme:   theme
	) or { panic(err) }
	// Last, so that coming and going it does not move the composer to another
	// place among its siblings, which would give it a new native field.
	if a.loading {
		children << ui2.loading_spinner(
			id:    'history-spinner'
			frame: ui2.rect(card.width - 44, 20, 20, 20)
			theme: theme
		) or { panic(err) }
	}
	return ui2.view('', card, ui2.BoxStyle{
		bg:            theme.background
		radius:        12
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, children)
}

fn message_count(count int) string {
	return if count == 1 { '1 new message' } else { '${group_digits(count)} new messages' }
}

fn build() ui2.Element {
	mut a := app()
	theme := ui2.component_theme(a.dark)
	f := frames()
	a.fit(f.scroller)
	a.built = a.feed.layout.range(f.scroller.height, a.feed.offset, 4)
	a.top_row = a.feed.anchor().index
	page := if a.dark { u32(0x0f172a) } else { u32(0xf1f5f9) }
	subtitle := if a.feed.following {
		'Following the latest message.'
	} else if a.feed.unread() > 0 {
		'Reading earlier messages; ${message_count(a.feed.unread())} below.'
	} else {
		'Reading earlier messages.'
	}
	return ui2.screen(page, [
		ui2.label('', 'Message scroller', ui2.rect(margin, 16, 400, 30), style(theme, 22,
			true, false)),
		ui2.label('', subtitle, ui2.rect(margin, 48, f.width - 2 * margin - 140, 20),
			style(theme, 13, false, true)),
		ui2.styled_button(
			id:    'theme'
			label: if a.dark { 'Light' } else { 'Dark' }
			icon:  if a.dark { 'sun.max' } else { 'moon' }
			frame: ui2.rect(f.width - margin - 104, 18, 104, 32)
			theme: theme
		) or { panic(err) },
		a.card(theme, f),
		a.side_panel(theme, f),
	])
}

// ── Changes ─────────────────────────────────────────────────────────

// flush passes the scroll the scroller's state asked for to the backend. Call
// it after every change to the state, wherever the change is made. A move the
// application made is not necessarily reported by on_scroll, so the
// load-earlier threshold is checked here as well.
fn (mut a App) flush() {
	if request := a.feed.take_scroll_request(feed_id) {
		ui2.scroll_to_offset(request.id, request.offset)
	}
	a.load_if_near_start()
}

// load_if_near_start fetches earlier history once the rows in view come near
// the first one. It arrives a moment later, as it would from a server, and
// goes in above the reader without moving what they read.
fn (mut a App) load_if_near_start() bool {
	if a.loading || a.messages.len == 0 || a.messages[0].serial <= history_first
		|| !a.feed.near_start(earlier_threshold) {
		return false
	}
	a.loading = true
	ui2.after(0.5, fn () {
		mut later := app()
		later.loading = false
		// The reader may have moved on while the history was on its way.
		if later.feed.near_start(earlier_threshold) {
			later.load_earlier()
		}
		later.flush()
	})
	return true
}

// fit keeps the rows' heights and the scroller's height in step with the
// window: a new width reflows every row (the row at the top stays put, or the
// bottom does when following), a new height resizes the viewport.
fn (mut a App) fit(frame ui2.Rect) {
	width := frame.width - 2 * row_inset
	if width != a.row_width {
		a.row_width = width
		a.measure_all()
		a.feed = a.feed.remeasure(a.layout()) or { panic(err) }
	}
	if frame.height != a.feed.viewport {
		a.feed = a.feed.resize(frame.height)
	}
	a.flush()
}

fn (mut a App) add(m Message) {
	a.messages << m
	a.heights << a.row_height(m, a.row_width)
	a.feed = a.feed.append(a.layout()) or { panic(err) }
}

fn (a &App) next_serial() int {
	return if a.messages.len > 0 {
		a.messages[a.messages.len - 1].serial + 1
	} else {
		opened_last + 1
	}
}

fn (mut a App) append_incoming() {
	serial := a.next_serial()
	m := generated(serial)
	a.add(Message{
		...m
		author: pick(serial, 1, 4)
	})
}

fn (mut a App) send(text string) {
	body := text.trim_space()
	if body.len == 0 {
		return
	}
	a.add(Message{
		serial: a.next_serial()
		author: you
		body:   body
	})
	// Sending from the composer goes to the latest message, as chat apps do.
	a.feed = a.feed.scroll_to_end()
	a.sent = true
}

fn (mut a App) load_earlier() {
	if a.messages.len == 0 {
		return
	}
	first := a.messages[0].serial
	from := math.max(history_first, first - earlier_batch)
	if from >= first {
		return
	}
	mut older := []Message{cap: first - from}
	for serial in from .. first {
		older << generated(serial)
	}
	mut combined := older.clone()
	combined << a.messages
	a.messages = combined
	mut heights := older.map(a.row_height(it, a.row_width))
	heights << a.heights
	a.heights = heights
	a.feed = a.feed.prepend(a.layout()) or { panic(err) }
}

fn (a &App) index_of(serial int) int {
	if a.messages.len == 0 {
		return -1
	}
	index := serial - a.messages[0].serial
	return if index >= 0 && index < a.messages.len { index } else { -1 }
}

fn (mut a App) start_stream() {
	serial := a.next_serial()
	a.add(Message{
		serial:    serial
		author:    streamer
		streaming: true
	})
	a.stream = serial
	a.words = stream_text.split(' ')
	a.word = 0
	ui2.after(0.3, stream_tick)
}

fn (mut a App) stop_stream() {
	index := a.index_of(a.stream)
	a.stream = -1
	if index >= 0 {
		a.messages[index].streaming = false
		a.remeasure(index)
	}
}

// remeasure takes a new height for one row; the scroller keeps the bottom in
// view if it follows the tail and the reader's place otherwise.
fn (mut a App) remeasure(index int) {
	height := a.row_height(a.messages[index], a.row_width)
	if height != a.heights[index] {
		a.heights[index] = height
		a.feed = a.feed.remeasure_rows(index, index + 1, a.layout()) or { panic(err) }
	}
}

// stream_tick adds a few words to the streamed reply, about twenty a second.
fn stream_tick() {
	mut a := app()
	index := a.index_of(a.stream)
	if index < 0 {
		return
	}
	step := 1 + pick(a.word, 12, 3)
	end := math.min(a.word + step, a.words.len)
	a.messages[index].body = a.words[..end].join(' ')
	a.word = end
	if a.word >= a.words.len {
		a.stop_stream()
	} else {
		a.remeasure(index)
		ui2.after(0.08, stream_tick)
	}
	a.flush()
}

fn (mut a App) jump(index int, align ui2.VirtualListAlign) {
	if next := a.feed.scroll_to_row(index, align) {
		a.feed = next
	}
}

fn (mut a App) handle(event string) bool {
	theme := ui2.component_theme(a.dark)
	if next := ui2.message_scroller_update(a.feed_config(theme, frames().scroller), event) {
		a.feed = next
		return true
	}
	match event {
		'theme' {
			a.dark = !a.dark
		}
		'append' {
			a.append_incoming()
		}
		'stream' {
			if a.stream >= 0 {
				a.stop_stream()
			} else {
				a.start_stream()
			}
		}
		'earlier' {
			a.load_earlier()
		}
		'jump-unread' {
			a.jump(a.unread_index(), .start)
		}
		'jump-top' {
			a.jump(0, .start)
		}
		'jump-latest' {
			a.feed = a.feed.scroll_to_end()
		}
		'send', 'composer-submit' {
			a.send(ui2.text(composer_id))
		}
		else {
			return false
		}
	}
	return true
}

fn on_event(event string) {
	mut a := app()
	if !a.handle(event) {
		return
	}
	a.flush()
	ui2.refresh()
	if a.sent {
		a.sent = false
		ui2.set_text(composer_id, '')
		ui2.focus(composer_id)
	}
}

// on_scroll keeps the state in step with the reader. The rebuild is requested
// rather than run here, since a scroll can be reported while a rebuild is
// under way.
fn on_scroll(id string) {
	mut a := app()
	theme := ui2.component_theme(a.dark)
	step := ui2.message_scroller_scroll(a.feed_config(theme, frames().scroller), id,
		ui2.scroll_offset(id)) or { return }
	a.feed = step.state
	started := step.load_earlier && a.load_if_near_start()
	if step.rebuild || started || a.feed.anchor().index != a.top_row {
		ui2.request_refresh()
	}
}

fn main() {
	mut a := app()
	for serial in opened_first .. opened_last + 1 {
		a.messages << generated(serial)
	}
	f := frames_for(window_width, window_height)
	a.row_width = f.scroller.width - 2 * row_inset
	a.measure_all()
	// Open at the first unread message, with some of what came before it
	// above, and count everything after what shows as new.
	unread := opened_unread - opened_first
	a.feed = ui2.message_scroller_state(a.layout(), f.scroller.height,
		position:     .row
		row:          unread
		align:        .center
		first_unread: unread
	)
	a.flush()
	ui2.on_scroll(on_scroll)
	ui2.run_window('GPUI Kit message scroller', window_width, window_height, build, on_event)
}
