module ui2

import math

// Pickers: select_box (component_pickers_select.v), combobox
// (component_pickers_combobox.v) and command_palette
// (component_pickers_command.v). This file holds what they share: the option
// model, the matcher that filters and scores options against a query, and the
// list of grouped rows they draw in their popups.

// PickerOption is one choice of a select or a combobox.
pub struct PickerOption {
pub:
	value       string   // Identity: non-empty and unique among the options; what the decoders report.
	label       string   // Shown and searched; the value is shown when it is empty.
	description string   // A muted second line.
	icon        string   // A symbol name (see symbol_known) drawn before the label.
	group       string   // The heading the option is listed under; '' lists it without one.
	keywords    []string // Further words a search matches, besides the label.
	enabled     bool = true
}

pub fn picker_option(value string, caption string) PickerOption {
	return PickerOption{
		value: value
		label: caption
	}
}

// title is what the option shows: its label, or its value without one.
pub fn (option PickerOption) title() string {
	return if option.label.len > 0 { option.label } else { option.value }
}

// validate_picker_options rejects options a picker cannot show or decode:
// missing or repeated values and icons not every renderer can draw.
pub fn validate_picker_options(options []PickerOption) ! {
	mut seen := map[string]bool{}
	for index, option in options {
		if option.value.len == 0 {
			return error('picker option ${index} has no value')
		}
		if option.value in seen {
			return error('duplicate picker option value `${option.value}`')
		}
		seen[option.value] = true
		if option.icon.len > 0 && !symbol_known(option.icon) {
			return error('picker option `${option.value}` uses `${option.icon}`, which not every renderer can draw; pick a name from symbol_names()')
		}
	}
}

// picker_value_part encodes a value for an action: as hex, so a value holding
// the separators of an action id cannot be mistaken for another part.
fn picker_value_part(prefix string, value string) string {
	return prefix + value.bytes().hex()
}

// picker_value_from_part decodes what picker_value_part wrote, or none.
fn picker_value_from_part(prefix string, part string) ?string {
	if !part.starts_with(prefix) {
		return none
	}
	hex := part[prefix.len..]
	if hex.len == 0 || hex.len % 2 != 0 {
		return none
	}
	mut bytes := []u8{cap: hex.len / 2}
	for i := 0; i < hex.len; i += 2 {
		high := picker_hex_digit(hex[i]) or { return none }
		low := picker_hex_digit(hex[i + 1]) or { return none }
		bytes << u8(high * 16 + low)
	}
	return bytes.bytestr()
}

// picker_hex_digit reads a lowercase hex digit, the only kind hex() writes.
fn picker_hex_digit(ch u8) ?int {
	if ch >= `0` && ch <= `9` {
		return int(ch - `0`)
	}
	if ch >= `a` && ch <= `f` {
		return int(ch - `a`) + 10
	}
	return none
}

// ── Matching ───────────────────────────────────────────────────────

// PickerMatchMode is how a query matches a label.
pub enum PickerMatchMode {
	substring // The query appears in the label as typed, ignoring case: GPUI Kit's search.
	fuzzy     // The query's characters appear in the label in order, with gaps between them.
}

// PickerRange is a run of matched characters: rune offsets into the label,
// end excluded.
pub struct PickerRange {
pub:
	start int
	end   int
}

// PickerMatch is how well a query matched a label: a higher score is a better
// match, and ranges are the characters that matched, for highlighting.
pub struct PickerMatch {
pub:
	score  int
	ranges []PickerRange
}

// PickerHit is an option a query matched, by its index in the options.
pub struct PickerHit {
pub:
	index  int
	score  int
	ranges []PickerRange // Matched characters of the option's title; none when a keyword matched.
}

// The scoring scale. Every matched character earns picker_score_char. A
// character right after the previous match earns picker_score_run on top, so
// a contiguous match beats a scattered one. One after a gap earns the bonus of
// where it lands (the start of the label or of a word) less the cost of the gap.
const picker_score_char = 16
const picker_score_run = 10
const picker_score_gap_open = 3
const picker_score_gap_extend = 1
const picker_score_lead_limit = 8
const picker_score_exact = 24
const picker_score_keyword = 12 // what a keyword match gives up against a label match
// Labels are matched up to this many characters; anything after is ignored.
const picker_match_limit = 512
const picker_score_none = -1_000_000_000

// picker_fold lowercases the letters of the common alphabets: ASCII, Latin-1,
// Greek and Cyrillic. Accents are kept: é does not match e.
fn picker_fold(r rune) rune {
	if (r >= `A` && r <= `Z`) || (r >= 0xc0 && r <= 0xde && r != 0xd7)
		|| (r >= 0x391 && r <= 0x3a9 && r != 0x3a2) || (r >= 0x410 && r <= 0x42f) {
		return r + 32
	}
	if r >= 0x400 && r <= 0x40f {
		return r + 80
	}
	return r
}

fn picker_is_upper(r rune) bool {
	return picker_fold(r) != r
}

fn picker_is_lower(r rune) bool {
	return (r >= `a` && r <= `z`) || (r >= 0xdf && r <= 0xff && r != 0xf7)
		|| (r >= 0x3b1 && r <= 0x3c9) || (r >= 0x430 && r <= 0x45f)
}

fn picker_is_digit(r rune) bool {
	return r >= `0` && r <= `9`
}

fn picker_is_separator(r rune) bool {
	return r in [` `, `\t`, `-`, `_`, `/`, `\\`, `.`, `,`, `:`, `;`, `(`, `)`, `[`, `]`, `{`, `}`,
		`<`, `>`, `&`, `+`, `|`, `@`, `#`, `'`, `"`, `…`]
}

// picker_bonus is what a match earns for landing at position j after a gap, or
// at the start: most at the start of the label, then at the start of a word,
// of a capitalized part of camelCase, or of a number.
fn picker_bonus(runes []rune, j int) int {
	if j == 0 {
		return 12
	}
	previous := runes[j - 1]
	current := runes[j]
	if picker_is_separator(previous) {
		return 8
	}
	if picker_is_lower(previous) && picker_is_upper(current) {
		return 6
	}
	if !picker_is_digit(previous) && picker_is_digit(current) {
		return 4
	}
	return 0
}

// picker_score scores matched positions (ascending rune offsets) in runes.
// The fuzzy matcher maximizes exactly this, and the substring matcher uses it
// to pick the best of several occurrences, so both modes share one scale.
fn picker_score(runes []rune, positions []int) int {
	mut score := 0
	for index, j in positions {
		score += picker_score_char
		if index == 0 {
			score += picker_bonus(runes, j) - math.min(j, picker_score_lead_limit)
		} else if j == positions[index - 1] + 1 {
			score += picker_score_run
		} else {
			score += picker_bonus(runes, j) - picker_score_gap_open - picker_score_gap_extend * (j - positions[index - 1] - 2)
		}
	}
	if positions.len > 0 && positions.len == runes.len {
		score += picker_score_exact
	}
	return score
}

// picker_ranges merges ascending positions into runs.
fn picker_ranges(positions []int) []PickerRange {
	mut ranges := []PickerRange{}
	mut index := 0
	for index < positions.len {
		start := positions[index]
		mut end := start + 1
		index++
		for index < positions.len && positions[index] == end {
			end++
			index++
		}
		ranges << PickerRange{start, end}
	}
	return ranges
}

// picker_query folds a query for matching: trimmed, and, for a fuzzy match,
// without its spaces, so 'new fi' still finds 'New File'.
fn picker_query(query string, mode PickerMatchMode) []rune {
	mut folded := []rune{}
	for r in query.trim_space().runes() {
		if mode == .fuzzy && (r == ` ` || r == `\t`) {
			continue
		}
		folded << picker_fold(r)
	}
	return folded
}

fn picker_text_runes(text string) []rune {
	runes := text.runes()
	return if runes.len > picker_match_limit { runes[..picker_match_limit] } else { runes }
}

// picker_substring_positions finds the best-scoring occurrence of the query.
fn picker_substring_positions(query []rune, runes []rune, folded []rune) ?[]int {
	n := query.len
	mut best := []int{}
	mut best_score := picker_score_none
	for start := 0; start + n <= folded.len; start++ {
		mut found := true
		for k in 0 .. n {
			if folded[start + k] != query[k] {
				found = false
				break
			}
		}
		if !found {
			continue
		}
		positions := []int{len: n, init: start + index}
		score := picker_score(runes, positions)
		if score > best_score {
			best_score = score
			best = positions.clone()
		}
	}
	return if best.len > 0 { best } else { none }
}

// picker_fuzzy_positions finds the matched positions with the highest
// picker_score by dynamic programming over (query character, label position):
// O(query × label) time, with a running maximum for the gap transitions.
fn picker_fuzzy_positions(query []rune, runes []rune, folded []rune) ?[]int {
	n := query.len
	m := folded.len
	if n > m {
		return none
	}
	mut score := []int{len: n * m, init: picker_score_none}
	mut from := []int{len: n * m, init: -1}
	for j in 0 .. m {
		if folded[j] == query[0] {
			score[j] = picker_score_char + picker_bonus(runes, j) - math.min(j, picker_score_lead_limit)
		}
	}
	for i in 1 .. n {
		row := i * m
		previous := (i - 1) * m
		// carry is the best previous[k] + extend * k over k <= j - 2.
		mut carry := picker_score_none
		mut carry_from := -1
		for j in 0 .. m {
			if j >= 2 && score[previous + j - 2] > picker_score_none {
				candidate := score[previous + j - 2] + picker_score_gap_extend * (j - 2)
				if candidate > carry {
					carry = candidate
					carry_from = j - 2
				}
			}
			if folded[j] != query[i] {
				continue
			}
			mut best := picker_score_none
			mut best_from := -1
			if j >= 1 && score[previous + j - 1] > picker_score_none {
				best = score[previous + j - 1] + picker_score_run
				best_from = j - 1
			}
			if carry > picker_score_none {
				gap := carry - picker_score_gap_extend * (j - 2) + picker_bonus(runes, j) - picker_score_gap_open
				if gap > best {
					best = gap
					best_from = carry_from
				}
			}
			if best_from >= 0 {
				score[row + j] = picker_score_char + best
				from[row + j] = best_from
			}
		}
	}
	last := (n - 1) * m
	mut end := -1
	for j in 0 .. m {
		if score[last + j] > picker_score_none && (end < 0 || score[last + j] > score[last + end]) {
			end = j
		}
	}
	if end < 0 {
		return none
	}
	mut positions := []int{len: n}
	mut j := end
	for i := n - 1; i >= 0; i-- {
		positions[i] = j
		j = from[i * m + j]
	}
	return positions
}

// picker_match matches a query against a label, ignoring case. An empty (or
// blank) query matches everything with score 0 and no ranges. Ranges are rune
// offsets into text.
pub fn picker_match(query string, text string, mode PickerMatchMode) ?PickerMatch {
	folded_query := picker_query(query, mode)
	if folded_query.len == 0 {
		return PickerMatch{}
	}
	runes := picker_text_runes(text)
	folded := runes.map(picker_fold(it))
	positions := match mode {
		.substring { picker_substring_positions(folded_query, runes, folded)? }
		.fuzzy { picker_fuzzy_positions(folded_query, runes, folded)? }
	}
	return PickerMatch{
		score:  picker_score(runes, positions)
		ranges: picker_ranges(positions)
	}
}

// picker_option_match matches a query against an option's title and keywords.
// A keyword match scores a little lower than the same match in the title and
// highlights nothing, since the keyword is not shown.
pub fn picker_option_match(option PickerOption, query string, mode PickerMatchMode) ?PickerMatch {
	mut best := PickerMatch{
		score: picker_score_none
	}
	if found := picker_match(query, option.title(), mode) {
		best = found
	}
	for keyword in option.keywords {
		if found := picker_match(query, keyword, mode) {
			if found.score - picker_score_keyword > best.score {
				best = PickerMatch{
					score: found.score - picker_score_keyword
				}
			}
		}
	}
	return if best.score > picker_score_none { best } else { none }
}

// picker_filter returns the options a query matches, grouped: groups appear in
// the order their first option does in options, and options keep their order
// within a group. With sort and a non-blank query, groups are ordered by their best
// match and options by their score, ties keeping that order.
pub fn picker_filter(options []PickerOption, query string, mode PickerMatchMode, sort bool) []PickerHit {
	mut order := []string{}
	mut groups := map[string][]PickerHit{}
	for option in options {
		if option.group !in groups {
			order << option.group
			groups[option.group] = []PickerHit{}
		}
	}
	for index, option in options {
		found := picker_option_match(option, query, mode) or { continue }
		groups[option.group] << PickerHit{
			index:  index
			score:  found.score
			ranges: found.ranges
		}
	}
	order = order.filter(groups[it].len > 0)
	ranked := sort && picker_query(query, mode).len > 0
	if ranked {
		for name in order {
			mut hits := groups[name].clone()
			hits.sort_with_compare(picker_hit_compare)
			groups[name] = hits
		}
		mut keyed := []PickerHit{cap: order.len}
		for position, name in order {
			keyed << PickerHit{
				index: position
				score: groups[name][0].score
			}
		}
		keyed.sort_with_compare(picker_hit_compare)
		order = keyed.map(order[it.index])
	}
	mut result := []PickerHit{cap: options.len}
	for name in order {
		result << groups[name]
	}
	return result
}

// picker_hit_compare orders by score, best first, then by index, so sorting is
// deterministic and keeps the given order among equals.
fn picker_hit_compare(a &PickerHit, b &PickerHit) int {
	if a.score != b.score {
		return if a.score > b.score { -1 } else { 1 }
	}
	return if a.index < b.index {
		-1
	} else if a.index > b.index {
		1
	} else {
		0
	}
}

// picker_navigable reports whether keyboard and pointer can highlight a hit.
fn picker_navigable(options []PickerOption, hit PickerHit) bool {
	return hit.index >= 0 && hit.index < options.len && options[hit.index].enabled
}

// picker_hit_of returns the position among hits of the option with a value.
fn picker_hit_of(options []PickerOption, hits []PickerHit, value string) int {
	if value.len == 0 {
		return -1
	}
	for position, hit in hits {
		if options[hit.index].value == value {
			return position
		}
	}
	return -1
}

// picker_first_value is the value of the first enabled hit, or ''.
fn picker_first_value(options []PickerOption, hits []PickerHit) string {
	for hit in hits {
		if picker_navigable(options, hit) {
			return options[hit.index].value
		}
	}
	return ''
}

// picker_step_value moves a highlight by step enabled hits, wrapping around,
// from the hit with value current. From nothing, forward starts at the first
// enabled hit and backward at the last. It returns '' when none is enabled.
fn picker_step_value(options []PickerOption, hits []PickerHit, current string, step int) string {
	count := hits.len
	if count == 0 || step == 0 {
		return current
	}
	forward := step > 0
	mut position := picker_hit_of(options, hits, current)
	if position < 0 || !picker_navigable(options, hits[position]) {
		position = if forward { -1 } else { count }
	}
	mut remaining := math.abs(step)
	mut last := ''
	for _ in 0 .. count * remaining {
		position = if forward { (position + 1) % count } else { (position - 1 + count) % count }
		if picker_navigable(options, hits[position]) {
			last = options[hits[position].index].value
			remaining--
			if remaining == 0 {
				break
			}
		}
	}
	return last
}

// picker_edge_value is the value of the first (or last) enabled hit.
fn picker_edge_value(options []PickerOption, hits []PickerHit, last bool) string {
	if !last {
		return picker_first_value(options, hits)
	}
	for i := hits.len - 1; i >= 0; i-- {
		if picker_navigable(options, hits[i]) {
			return options[hits[i].index].value
		}
	}
	return ''
}

// picker_typeahead_value is the next enabled hit after current whose title
// starts with ch, wrapping around, or '' when there is none.
fn picker_typeahead_value(options []PickerOption, hits []PickerHit, current string, ch rune) string {
	count := hits.len
	start := picker_hit_of(options, hits, current)
	target := picker_fold(ch)
	for offset in 1 .. count + 1 {
		hit := hits[(start + offset + count) % count]
		if !picker_navigable(options, hit) {
			continue
		}
		runes := options[hit.index].title().runes()
		if runes.len > 0 && picker_fold(runes[0]) == target {
			return options[hit.index].value
		}
	}
	return ''
}

// picker_key_rune is the letter or digit a key types on a US layout, for
// typeahead, or none.
fn picker_key_rune(event KeyEvent) ?rune {
	code := int(event.code)
	if (code >= int(KeyCode.a) && code <= int(KeyCode.z))
		|| (code >= int(KeyCode._0) && code <= int(KeyCode._9)) {
		return rune(code)
	}
	return none
}

fn picker_plain_key(event KeyEvent) bool {
	return !event.cmd && !event.ctrl && !event.alt
}

// ── Rows ───────────────────────────────────────────────────────────

enum PickerRowKind {
	heading
	separator
	option
}

// PickerRow is one row of a picker's list, positioned in the list's content.
struct PickerRow {
	kind   PickerRowKind
	hit    PickerHit // option rows
	text   string    // heading rows
	y      f64
	height f64
}

// PickerMetrics are the sizes of a picker's list for a component size.
struct PickerMetrics {
	inset       f64 // rows from the list's sides, and the list's top and bottom padding
	padding     f64 // content from a row's sides
	row         f64 // a one-line row
	described   f64 // a row with a description
	heading     f64
	separator   f64
	icon        f64
	gap         f64
	font_size   f64
	hint_size   f64
	label_line  f64 // the label's line in a described row
	row_radius  f64
	empty       f64 // the height of the empty and loading messages
	surface_rad f64
}

fn picker_metrics(size ComponentSize) PickerMetrics {
	metrics := component_metrics(size)
	return PickerMetrics{
		inset:       4
		padding:     metrics.padding
		row:         metrics.height - 4
		described:   metrics.height + metrics.font_size - 2
		heading:     metrics.height - 8
		separator:   9
		icon:        math.round(metrics.font_size * 1.15)
		gap:         metrics.gap + 2
		font_size:   metrics.font_size
		hint_size:   metrics.font_size - 2
		label_line:  metrics.font_size + 6
		row_radius:  math.max(metrics.radius - 2, 2)
		empty:       metrics.height * 2
		surface_rad: metrics.radius
	}
}

// picker_rows lays the hits out as rows from y = 0: a heading where a named
// group starts, a separator between groups when separators is set, and a row
// per option.
fn picker_rows(options []PickerOption, hits []PickerHit, separators bool, m PickerMetrics) []PickerRow {
	mut rows := []PickerRow{cap: hits.len + 4}
	mut y := 0.0
	mut group := ''
	for position, hit in hits {
		option := options[hit.index]
		if position == 0 || option.group != group {
			if position > 0 && separators {
				rows << PickerRow{
					kind:   .separator
					y:      y
					height: m.separator
				}
				y += m.separator
			}
			if option.group.len > 0 {
				rows << PickerRow{
					kind:   .heading
					text:   option.group
					y:      y
					height: m.heading
				}
				y += m.heading
			}
			group = option.group
		}
		height := if option.description.len > 0 { m.described } else { m.row }
		rows << PickerRow{
			kind:   .option
			hit:    hit
			y:      y
			height: height
		}
		y += height
	}
	return rows
}

fn picker_rows_height(rows []PickerRow) f64 {
	return if rows.len == 0 { 0.0 } else { rows[rows.len - 1].y + rows[rows.len - 1].height }
}

// picker_row_rect is the row of the option with value, in the list content's
// coordinates, inset as it is drawn.
fn picker_row_rect(options []PickerOption, rows []PickerRow, value string, width f64, m PickerMetrics) ?Rect {
	for row in rows {
		if row.kind == .option && options[row.hit.index].value == value {
			return rect(m.inset, row.y + m.inset, math.max(width - m.inset * 2, 0), row.height)
		}
	}
	return none
}

// picker_text_width estimates how wide a run of text draws: the per-letter
// estimate the dialogs wrap with, which tells narrow letters from wide ones.
fn picker_text_width(text string, size f64) f64 {
	return dialog_wrap_width(text, font_em_pixels(size))
}

// picker_label_slack is the room a label sized to its text needs beyond the
// text: AppKit insets a label's text from its frame by a couple of points on
// each side, and a label that is too narrow is cut short.
const picker_label_slack = 6.0

// picker_rune_slice is runes [start, end) of text, clamped.
fn picker_rune_slice(runes []rune, start int, end int) string {
	a := math.max(0, math.min(start, runes.len))
	b := math.max(a, math.min(end, runes.len))
	return runes[a..b].string()
}

// picker_marker_color tints the background behind matched characters: the
// primary color over the surface, a quarter of it on a light surface and more
// on a dark one, where it would otherwise vanish into a highlighted row.
fn picker_marker_color(theme ComponentTheme) u32 {
	bg := theme.background
	luminance := f64(((bg >> 16) & 0xff) + ((bg >> 8) & 0xff) + (bg & 0xff)) / (3 * 255.0)
	return popover_blend(bg, theme.primary, if luminance < 0.5 { 0.4 } else { 0.25 })
}

// picker_markers are the boxes drawn behind the matched characters of a label
// placed at frame. ui2 cannot style part of a label, so a match is marked
// like a highlighter pen would: the characters' positions are estimated, which
// a marker forgives where a bold run would show gaps.
fn picker_markers(caption string, ranges []PickerRange, frame Rect, size f64, color u32) []Element {
	if ranges.len == 0 || frame.width <= 0 {
		return []Element{}
	}
	runes := caption.runes()
	mut markers := []Element{cap: ranges.len}
	height := math.min(frame.height, math.round(font_em_pixels(size) * 1.3))
	y := frame.y + math.round((frame.height - height) / 2)
	origin := frame.x + picker_label_inset()
	for range in ranges {
		start := origin + picker_text_width(picker_rune_slice(runes, 0, range.start), size)
		width := picker_text_width(picker_rune_slice(runes, range.start, range.end), size)
		left := math.max(start - 1, frame.x)
		right := math.min(start + width + 2, frame.x + frame.width)
		if right <= left {
			continue
		}
		markers << view('', rect(math.round(left), y, math.round(right - left), height), BoxStyle{
			bg:     color
			radius: 3
		}, []Element{})
	}
	return markers
}

// picker_label_inset is how far a left-aligned label's text starts from its
// frame: AppKit's label cell insets it by two points, the custom renderer
// draws from the edge.
fn picker_label_inset() f64 {
	$if macos {
		$if ui2_custom_rendering ? {
			return 0.0
		} $else {
			return 2.0
		}
	} $else {
		return 0.0
	}
}

fn picker_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
		}
	}
}

// PickerListSpec is what a picker's list draws.
struct PickerListSpec {
	id        string // the component, whose part ids the rows take
	options   []PickerOption
	rows      []PickerRow
	width     f64
	highlight string
	selected  []string // values drawn with a check mark
	hints     []string // per option: a shortcut drawn at the right, or ''
	role      string = 'option'
	size      ComponentSize
	theme     ComponentTheme
}

fn picker_option_part(value string) string {
	return picker_value_part('option:', value)
}

fn picker_has_icons(options []PickerOption, rows []PickerRow) bool {
	for row in rows {
		if row.kind == .option && options[row.hit.index].icon.len > 0 {
			return true
		}
	}
	return false
}

fn picker_option_row(spec PickerListSpec, row PickerRow, icon_column bool) Element {
	m := picker_metrics(spec.size)
	theme := spec.theme
	option := spec.options[row.hit.index]
	frame := rect(m.inset, row.y + m.inset, math.max(spec.width - m.inset * 2, 0), row.height)
	enabled := option.enabled
	highlighted := enabled && option.value == spec.highlight
	selected := option.value in spec.selected
	foreground := if enabled { theme.foreground } else { theme.muted_foreground }
	described := option.description.len > 0
	line := if described { m.label_line } else { frame.height }
	top := if described {
		math.round((frame.height - m.label_line - m.hint_size - 4) / 2)
	} else {
		0.0
	}
	mut children := []Element{}
	mut x := m.padding
	if icon_column {
		if option.icon.len > 0 {
			children << picker_symbol(option.icon, rect(x, top + (line - m.icon) / 2,
				m.icon, m.icon), if enabled { theme.foreground } else { theme.muted_foreground })
		}
		x += m.icon + m.gap
	}
	hint := if row.hit.index < spec.hints.len { spec.hints[row.hit.index] } else { '' }
	trailing := if hint.len > 0 {
		math.min(dropdown_menu_hint_width(hint, m.hint_size) + m.gap, frame.width / 2)
	} else if selected {
		m.icon + m.gap
	} else {
		0.0
	}
	width := math.max(frame.width - x - m.padding - trailing, 0)
	caption := option.title()
	label_frame := rect(x, top, width, line)
	children << picker_markers(caption, row.hit.ranges, label_frame, m.font_size, picker_marker_color(theme))
	children << label('', caption, label_frame, TextStyle{
		color: foreground
		size:  m.font_size
	})
	if described {
		children << label('', option.description, rect(x, top + line, width, m.hint_size + 4),
			TextStyle{
				color: theme.muted_foreground
				size:  m.hint_size
			})
	}
	if hint.len > 0 {
		children << label('', hint, rect(frame.width - m.padding - trailing, top, trailing,
			line), TextStyle{
			color: theme.muted_foreground
			size:  m.hint_size
			align: .right
		})
	} else if selected {
		check := m.icon - 2
		children << picker_symbol('checkmark', rect(frame.width - m.padding - check, top +
			(line - check) / 2, check, check), if enabled {
			theme.primary
		} else {
			theme.muted_foreground
		})
	}
	part := picker_option_part(option.value)
	return Element{
		...button_view(component_part_id(spec.id, part), frame, if highlighted {
			BoxStyle{
				bg:     theme.muted
				radius: m.row_radius
			}
		} else {
			BoxStyle{
				transparent: true
			}
		}, children)
		key:                 part
		hoverable:           true
		enabled:             enabled
		accessibility_role:  spec.role
		accessibility_label: caption
		accessibility_value: if selected { 'selected' } else { '' }
	}
}

// picker_list_rows builds the rows of a list in its content's coordinates.
fn picker_list_rows(spec PickerListSpec) []Element {
	m := picker_metrics(spec.size)
	theme := spec.theme
	icon_column := picker_has_icons(spec.options, spec.rows)
	mut children := []Element{cap: spec.rows.len}
	for index, row in spec.rows {
		match row.kind {
			.separator {
				children << Element{
					...view('', rect(0, row.y + m.inset + math.floor(row.height / 2), spec.width,
						1), BoxStyle{ bg: theme.border }, []Element{})
					key:                'separator:${index}'
					accessibility_role: 'separator'
				}
			}
			.heading {
				children << Element{
					...label('', row.text, rect(m.inset + m.padding, row.y + m.inset, math.max(spec.width - (m.inset +
						m.padding) * 2, 0), row.height), TextStyle{
						color: theme.muted_foreground
						size:  m.hint_size
						bold:  true
					})
					key:                 'heading:${index}'
					accessibility_role:  'text'
					accessibility_label: row.text
				}
			}
			.option {
				children << picker_option_row(spec, row, icon_column)
			}
		}
	}
	return children
}

// picker_list builds a list viewport at frame: its rows in a scroll element
// (id scroll_id) when they are taller than the frame, as they are otherwise.
fn picker_list(spec PickerListSpec, frame Rect, scroll_id string) Element {
	m := picker_metrics(spec.size)
	rows := picker_list_rows(spec)
	content := picker_rows_height(spec.rows) + m.inset * 2
	if content > frame.height + 0.5 {
		return Element{
			...scroll(scroll_id, frame, spec.theme.background, rows)
			key:                'list'
			accessibility_role: 'list'
		}
	}
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, rows)
		key:                'list'
		accessibility_role: 'list'
	}
}

// picker_message is the centered line a list shows instead of rows: nothing
// matched, or results are loading (with a spinner before the text).
fn picker_message(id string, frame Rect, caption string, loading bool, size ComponentSize, theme ComponentTheme) Element {
	m := picker_metrics(size)
	mut children := []Element{}
	text_width := math.min(picker_text_width(caption, m.font_size) + 8, frame.width)
	mut x := (frame.width - text_width) / 2
	if loading {
		diameter := loading_spinner_diameter(size)
		x = (frame.width - text_width - diameter - m.gap) / 2
		children << loading_spinner(
			id:         component_part_id(id, 'spinner')
			frame:      rect(x, (frame.height - diameter) / 2, diameter, diameter)
			size:       size
			background: theme.background
			theme:      theme
		) or { view('', Rect{}, BoxStyle{ transparent: true }, []Element{}) }
		x += diameter + m.gap
	}
	children << label('', caption, rect(math.max(x, 0), 0, text_width, frame.height), TextStyle{
		color: theme.muted_foreground
		size:  m.font_size
		align: if loading { Align.left } else { Align.center }
	})
	return Element{
		...view('', frame, BoxStyle{ transparent: true }, children)
		key:                 if loading { 'loading' } else { 'empty' }
		accessibility_role:  'status'
		accessibility_label: caption
	}
}

// picker_surface is the bordered floating panel of a picker, framed in window
// coordinates. Clicks on its blank parts stay with it rather than falling
// through to the dismiss backdrop below.
fn picker_surface(id string, frame Rect, content []Element, role string, caption string, size ComponentSize, theme ComponentTheme) Element {
	box, mut children := popover_panel(frame, theme.background, theme.border, picker_metrics(size).surface_rad,
		true)
	children << content
	return Element{
		...view(id, frame, box, children)
		key:                 'surface'
		clickable:           true
		accessibility_role:  role
		accessibility_label: caption
	}
}

// picker_backdrop_around covers the window except hole with transparent
// buttons that emit action, so a press anywhere else dismisses the popup while
// a press on the hole (the combobox's own field) still reaches it.
fn picker_backdrop_around(id string, window Rect, hole Rect, action string) []Element {
	left := math.max(hole.x - window.x, 0)
	top := math.max(hole.y - window.y, 0)
	right := math.min(hole.x + hole.width - window.x, window.width)
	bottom := math.min(hole.y + hole.height - window.y, window.height)
	parts := [
		rect(0, 0, window.width, top),
		rect(0, bottom, window.width, window.height - bottom),
		rect(0, top, left, bottom - top),
		rect(right, top, window.width - right, bottom - top),
	]
	names := ['top', 'bottom', 'left', 'right']
	mut backdrops := []Element{cap: 4}
	for index, part in parts {
		if part.width <= 0 || part.height <= 0 {
			continue
		}
		backdrops << Element{
			...popover_backdrop(component_part_id(id, 'backdrop:' + names[index]), window,
				action)
			frame: part
			key:   'backdrop:' + names[index]
		}
	}
	return backdrops
}

// picker_popup_height fits a popup of natural height below its anchor, or
// above it when only there it fits, or else into the roomier of the two.
fn picker_popup_height(natural f64, anchor Rect, window Rect, margin f64, offset f64) f64 {
	limits := popover_limits(window, margin)
	below := limits.bottom - (anchor.y + anchor.height) - offset
	above := anchor.y - limits.top - offset
	if natural <= below || natural <= above {
		return natural
	}
	return math.max(math.max(below, above), 0)
}

// picker_anchor is where a popup opens from: anchor when given, else frame,
// for a trigger that is a direct child of the screen.
fn picker_anchor(anchor Rect, frame Rect) Rect {
	return if anchor.width > 0 || anchor.height > 0 || anchor.x != 0 || anchor.y != 0 {
		anchor
	} else {
		frame
	}
}
