module ui2

import math

// otp_input_max_length bounds how many cells a code may have, so a forged or
// mistaken length cannot make a build allocate without limit.
pub const otp_input_max_length = 32

pub enum OtpInputCharset {
	digits       // 0-9; full-width digits from an IME are folded to ASCII.
	alphanumeric // ASCII letters and digits; full-width forms are folded too.
}

pub struct OtpInputConfig {
pub:
	id                  string
	frame               Rect
	code                string // Controlled: the characters entered so far, without gaps.
	length              int = 6
	groups              int = 2 // Cells are split into this many groups (clamped to 1..length).
	separator           string // Drawn between groups, e.g. '-'; empty leaves a wider gap.
	charset             OtpInputCharset
	masked              bool // Native secure entry in every cell.
	enabled             bool = true
	invalid             bool // Draw the danger border, e.g. after a rejected code.
	accessibility_label string        = 'One-time code'
	size                ComponentSize = .medium
	theme               ComponentTheme
}

// OtpInputEdit is the result of an edit: the new code, the cell to focus next,
// whether the code changed, and whether every cell is now filled.
pub struct OtpInputEdit {
pub:
	code     string
	focus    int
	changed  bool
	complete bool
}

// otp_input_cell_id is the id of cell index, for text(), set_text() and
// focus(). It is also the action the cell emits on each edit.
pub fn otp_input_cell_id(id string, index int) string {
	return component_part_id(id, 'cell:${index}')
}

// otp_input_cell_from_action returns the index of the cell an action (or a
// focused_id()) names, or none for foreign, malformed and out-of-range ids and
// for every cell while the input is disabled.
pub fn otp_input_cell_from_action(config OtpInputConfig, action string) ?int {
	if !config.enabled || config.length < 1 || config.length > otp_input_max_length {
		return none
	}
	part := component_action_part(config.id, action) or { return none }
	if !part.starts_with('cell:') {
		return none
	}
	return component_parse_index(part['cell:'.len..], config.length - 1)
}

// otp_input_normalize keeps the characters a code may hold: full-width forms
// become ASCII, and anything outside the charset (spaces, dashes, punctuation
// in a pasted `123-456`) is dropped.
pub fn otp_input_normalize(source string, charset OtpInputCharset) string {
	mut kept := []rune{cap: source.len}
	for raw in source.runes() {
		r := if raw >= 0xff01 && raw <= 0xff5e { raw - 0xfee0 } else { raw }
		digit := r >= `0` && r <= `9`
		letter := (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`)
		if digit || (letter && charset == .alphanumeric) {
			kept << r
		}
	}
	return kept.string()
}

fn otp_input_runes(config OtpInputConfig) []rune {
	code := config.code.runes()
	return if code.len > config.length { code[..math.max(config.length, 0)].clone() } else { code }
}

// otp_input_cell_text is what cell index shows for code: its character, or
// nothing past the end.
pub fn otp_input_cell_text(code string, index int) string {
	runes := code.runes()
	return if index >= 0 && index < runes.len { runes[index].str() } else { '' }
}

// otp_input_focus_index is the cell that takes the next character: the first
// empty one, or the last cell of a complete code.
pub fn otp_input_focus_index(config OtpInputConfig) int {
	return math.max(math.min(otp_input_runes(config).len, config.length - 1), 0)
}

fn otp_input_result(config OtpInputConfig, before []rune, after []rune, target int) OtpInputEdit {
	return OtpInputEdit{
		code:     after.string()
		focus:    math.max(math.min(target, config.length - 1), 0)
		changed:  after != before
		complete: config.length > 0 && after.len == config.length
	}
}

fn otp_input_without(code []rune, index int) []rune {
	mut rest := code.clone()
	rest.delete(index)
	return rest
}

// otp_input_edit applies what the user left in cell index, read with
// text(otp_input_cell_id(id, index)) when that cell's action arrives. The code
// never has gaps, so:
//
// - a character typed into a filled cell replaces that cell's character;
// - one typed into an empty cell is appended to the code;
// - several characters at once (a paste, or an autofilled code) fill cells
//   from there on, up to the length;
// - a cell left empty removes its character and the rest move up.
//
// Focus moves to the cell after the last one written. The edited cell may
// still show what was typed (say `35` after typing 5 over 3), and a rebuild
// with an unchanged declaration keeps it, so call set_text on that cell with
// otp_input_cell_text(edit.code, index) after storing the code.
pub fn otp_input_edit(config OtpInputConfig, index int, cell_text string) OtpInputEdit {
	code := otp_input_runes(config)
	unchanged := otp_input_result(config, code, code, index)
	if !config.enabled || index < 0 || index >= config.length {
		return unchanged
	}
	old := if index < code.len { code[index].str() } else { '' }
	if cell_text == old {
		return unchanged
	}
	if cell_text.len == 0 {
		if index >= code.len {
			return unchanged
		}
		return otp_input_result(config, code, otp_input_without(code, index), index)
	}
	// A native field appends at its caret: keep what was added around the
	// character the cell already had, or everything when it was replaced.
	added := if old.len > 0 && cell_text.starts_with(old) {
		cell_text[old.len..]
	} else if old.len > 0 && cell_text.ends_with(old) {
		cell_text[..cell_text.len - old.len]
	} else {
		cell_text
	}
	chars := otp_input_normalize(added, config.charset).runes()
	if chars.len == 0 {
		return unchanged
	}
	start := math.min(index, code.len)
	mut next := code[..start].clone()
	for ch in chars {
		if next.len >= config.length {
			break
		}
		next << ch
	}
	written := next.len
	for position in written .. code.len {
		next << code[position]
	}
	return otp_input_result(config, code, next, written)
}

// otp_input_key handles the keys a single-character cell cannot handle well on
// its own, for the cell at index (decode focused_id() with
// otp_input_cell_from_action). Backspace removes the cell's character, or the
// last one when the cell is empty, and focuses the cell it emptied; Delete
// removes the cell's character; Left, Right, Home and End move between the
// filled cells and the next empty one. It returns none for every other key and
// for a key with nothing to do, so the application consumes only what it used.
pub fn otp_input_key(config OtpInputConfig, index int, event KeyEvent) ?OtpInputEdit {
	if !config.enabled || index < 0 || index >= config.length || event.cmd || event.ctrl
		|| event.alt {
		return none
	}
	code := otp_input_runes(config)
	last := otp_input_focus_index(config)
	match event.code {
		.backspace {
			if index < code.len {
				return otp_input_result(config, code, otp_input_without(code, index), index)
			}
			if code.len == 0 {
				return none
			}
			return otp_input_result(config, code, otp_input_without(code, code.len - 1),
				code.len - 1)
		}
		.delete {
			if index >= code.len {
				return none
			}
			return otp_input_result(config, code, otp_input_without(code, index), index)
		}
		.left, .home {
			if event.shift || index == 0 {
				return none
			}
			return otp_input_result(config, code, code, if event.code == .home {
				0
			} else {
				index - 1
			})
		}
		.right, .end {
			target := if event.code == .end { last } else { math.min(index + 1, last) }
			if event.shift || target <= index {
				return none
			}
			return otp_input_result(config, code, code, target)
		}
		else {
			return none
		}
	}
}

struct OtpInputMetrics {
	width     f64
	height    f64
	font_size f64
	gap       f64
	group_gap f64
}

// otp_input_metrics sizes a cell for one character. AppKit insets field text
// by about ten points and ignores alignment, so a cell about twenty points
// wider than a digit keeps the character centered there as well.
fn otp_input_metrics(size ComponentSize) OtpInputMetrics {
	return match size {
		.small { OtpInputMetrics{30, 32, 14, 4, 16} }
		.medium { OtpInputMetrics{34, 40, 18, 6, 20} }
		.large { OtpInputMetrics{38, 48, 22, 8, 24} }
	}
}

fn otp_input_group_count(config OtpInputConfig) int {
	return math.min(math.max(config.groups, 1), math.max(config.length, 1))
}

// otp_input_group_of follows GPUI Kit's grouping: each group holds
// ceil(length / groups) cells, the last one whatever remains.
fn otp_input_group_of(config OtpInputConfig, index int) int {
	groups := otp_input_group_count(config)
	per_group := math.max((config.length + groups - 1) / groups, 1)
	return index / per_group
}

// otp_input_width is how wide the cells and gaps of a configuration are at its
// size, for sizing its frame.
pub fn otp_input_width(config OtpInputConfig) f64 {
	if config.length < 1 {
		return 0
	}
	m := otp_input_metrics(config.size)
	groups := otp_input_group_of(config, config.length - 1) + 1
	return f64(config.length) * m.width + f64(config.length - groups) * m.gap + f64(groups - 1) * m.group_gap
}

// otp_input_cell_frames lays the cells out from the left edge, vertically
// centered. A frame narrower than otp_input_width shrinks cells and gaps alike.
fn otp_input_cell_frames(config OtpInputConfig) []Rect {
	m := otp_input_metrics(config.size)
	needed := otp_input_width(config)
	scale := if needed > config.frame.width && needed > 0 {
		config.frame.width / needed
	} else {
		1.0
	}
	height := math.min(m.height, config.frame.height)
	y := (config.frame.height - height) / 2
	mut frames := []Rect{cap: config.length}
	mut x := 0.0
	for index in 0 .. config.length {
		if index > 0 {
			same_group := otp_input_group_of(config, index) == otp_input_group_of(config, index - 1)
			x += (if same_group { m.gap } else { m.group_gap }) * scale
		}
		frames << rect(x, y, m.width * scale, height)
		x += m.width * scale
	}
	return frames
}

// otp_input shows one native single-character field per cell of a fixed-length
// code. Each cell is a real text field, so input methods, paste, secure entry,
// Tab order and screen readers work as they do in any field; the application
// moves focus between cells with otp_input_edit and otp_input_key.
pub fn otp_input(config OtpInputConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if config.length < 1 || config.length > otp_input_max_length {
		return error('otp input length must be between 1 and ${otp_input_max_length}')
	}
	m := otp_input_metrics(config.size)
	theme := config.theme
	frames := otp_input_cell_frames(config)
	code := otp_input_runes(config).string()
	noun := if config.charset == .digits { 'Digit' } else { 'Character' }
	mut children := []Element{cap: config.length + otp_input_group_count(config)}
	for index, frame in frames {
		if index > 0 && config.separator.len > 0
			&& otp_input_group_of(config, index) != otp_input_group_of(config, index - 1) {
			previous := frames[index - 1]
			children << Element{
				...label('', config.separator, rect(previous.x + previous.width, frame.y,
					frame.x - previous.x - previous.width, frame.height), TextStyle{
					color: theme.muted_foreground
					size:  m.font_size
					align: .center
				})
				key: 'separator:${index}'
			}
		}
		children << inputs_field(
			id:                otp_input_cell_id(config.id, index)
			text:              otp_input_cell_text(code, index)
			frame:             frame
			font_size:         m.font_size * frame.height / m.height
			align:             .center
			// The custom renderer keeps 8 points clear on the right of a field's
			// text, so the same on the left centers it.
			padding:           8
			enabled:           config.enabled
			secure:            config.masked
			invalid:           config.invalid
			autocorrect:       false
			keyboard:          if config.charset == .digits {
				keyboard_decimal
			} else {
				keyboard_default
			}
			label:             '${noun} ${index + 1} of ${config.length}'
			key:               'cell:${index}'
			theme:             theme
			// Each cell stands alone, so it keeps the native field frame.
			standalone_radius: component_metrics(config.size).radius
		)
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
		accessibility_value: '${code.runes().len} of ${config.length} entered'
	})
}
