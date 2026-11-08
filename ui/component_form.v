module ui2

import math

// Form lays out labelled fields on a grid: a label above or beside each
// control, a description or validation message under it, section titles over
// a rule, and a row of actions at the end. The application owns every value
// and every control: a field's control is any element the application builds
// for the frame the form hands it. Validation helpers are in
// component_form_validate.v.

// FormSlotFn builds what goes in a slot of a field (its control, or a custom
// description) at frame, which is in the coordinates of the element the form
// puts it in. Closures can capture the application's state:
// `fn [app] (frame ui2.Rect) !ui2.Element { ... }`.
pub type FormSlotFn = fn (frame Rect) !Element

pub const form_max_columns = 12

// form_max_description_lines caps how many lines a description or message is
// given room for; longer text is cut short.
pub const form_max_description_lines = 4

pub enum FormFieldKind {
	field   // A label, a control and a description or message.
	section // A title and description over a rule, across every column.
}

// FormFieldAlign places a label beside a control taller than one line.
pub enum FormFieldAlign {
	center // Centered on the control.
	start  // On the control's first line, as for a text area.
	end    // On the control's last line.
}

pub struct FormField {
pub:
	id   string // Stable key, unique within the form; form_layout and form_control_frame take it.
	kind FormFieldKind
	// label is the field's label, or a section's title.
	label    string
	required bool // Draw a marker after the label.
	// description is drawn under the control in a muted color, wrapping onto
	// as many lines as it needs (up to form_max_description_lines).
	description string
	// description_fn builds a custom description element in a slot
	// description_height tall (one description line when zero).
	description_fn     FormSlotFn = unsafe { nil }
	description_height f64
	// error is a validation message. While it is not empty it replaces the
	// description, drawn in the theme's danger color after an alert icon.
	error string
	// A field that is not visible takes no room: the fields after it move up.
	// Its control is not built, so native state such as focus is not kept.
	visible bool = true
	// label_indent keeps the label's room (a row above, or the label column
	// beside) for a field without a label, so its control lines up with the
	// controls of labelled fields. False lets the control use that room.
	label_indent bool = true
	col_span     int  = 1 // Columns the field spans; more than the form has spans them all.
	col_start    int // 1-based column to put the field in; 0 places it after the previous one.
	// height is the control's; zero is the form size's control height.
	height f64
	align  FormFieldAlign
	// control builds the field's control at the frame it is given. Without
	// one, text is drawn there as a read-only value.
	control             FormSlotFn = unsafe { nil }
	text                string
	accessibility_label string // Given to a control without one; defaults to label.
}

pub enum FormActionKind {
	button // An ordinary command, such as Cancel or Preview.
	submit
	reset
}

pub struct FormAction {
pub:
	id    string // Stable key, unique among the actions; FormEvent.action reports it.
	label string
	kind  FormActionKind
	// variant defaults to primary for a submit action and secondary otherwise.
	variant             ?ButtonVariant
	outline             bool
	icon                string // A symbol name drawn before the label; see symbol_known.
	enabled             bool = true
	width               f64 // Zero fits the label.
	accessibility_label string
}

// FormActionsAlign places the actions row, which spans every column.
pub enum FormActionsAlign {
	end // Against the trailing edge, as GPUI Kit's footer.
	start
	center
	stretch // The buttons share the row equally.
}

pub struct FormConfig {
pub:
	id      string
	frame   Rect // Content is laid out from the top; the form's view grows to fit it.
	fields  []FormField
	actions []FormAction
	// label_layout puts labels above their controls (.vertical) or beside them
	// (.horizontal), independently of columns.
	label_layout LayoutOrientation = .vertical
	columns      int               = 1
	// collapse_below makes the form one column with labels above their
	// controls while frame is narrower than this; zero never collapses.
	collapse_below  f64
	label_width     f64 = 140 // The label column of a horizontal layout.
	label_align     Align // Of labels in a horizontal layout.
	label_text_size f64   // Zero is the size's font size.
	row_gap         f64 = -1 // Negative uses the size's spacing.
	column_gap      f64 = -1
	actions_align   FormActionsAlign
	// reserve_descriptions gives every field a description line even when it
	// has none, so a message appearing does not move the fields below it.
	reserve_descriptions bool
	accessibility_label  string
	size                 ComponentSize = .medium
	theme                ComponentTheme
}

// FormFieldLayout is where a visible field went, in the form's coordinates.
// A section's label is its title, its control the rule under it.
pub struct FormFieldLayout {
	index int // Into the config's fields.
pub:
	id          string
	kind        FormFieldKind
	row         int
	column      int // 0-based.
	span        int
	cell        Rect // The grid area: the field's columns and its row's height.
	label       Rect // Empty without label room.
	control     Rect
	description Rect // Empty without a description or message.
}

pub struct FormLayout {
pub:
	fields   []FormFieldLayout // The visible fields, in the order they were listed.
	actions  []Rect            // One per action, in order.
	columns  int               // After collapse_below.
	vertical bool              // Labels above their controls, after collapse_below.
	height   f64               // Of the content: fields, then actions.
}

// field returns the layout of a visible field.
pub fn (layout FormLayout) field(id string) ?FormFieldLayout {
	for item in layout.fields {
		if item.id == id {
			return item
		}
	}
	return none
}

pub struct FormEvent {
pub:
	kind FormActionKind
	// action is the FormAction's id; empty for Return in a field of a form
	// with no submit action.
	action string
}

// form_action_id is the id and action of an action's button.
pub fn form_action_id(id string, action string) string {
	return component_part_id(id, form_action_part(action))
}

// form_submit_action is the action that submits the form: pass it as the
// submit_id of text fields (text_field_with_submit) so Return submits.
pub fn form_submit_action(id string) string {
	return component_part_id(id, 'submit')
}

fn form_action_part(action string) string {
	return 'action:' + action.bytes().hex()
}

// form_event decodes an action of the form against the application's current
// configuration: a press of one of its actions, or form_submit_action, which
// is reported as the first enabled submit action. It rejects foreign and
// forged actions, unknown and disabled actions, and a submit while every
// submit action is disabled.
pub fn form_event(config FormConfig, action string) ?FormEvent {
	part := component_action_part(config.id, action) or { return none }
	if part == 'submit' {
		mut has_submit := false
		for item in config.actions {
			if item.kind != .submit {
				continue
			}
			has_submit = true
			if item.enabled {
				return FormEvent{
					kind:   .submit
					action: item.id
				}
			}
		}
		if has_submit {
			return none
		}
		return FormEvent{
			kind: .submit
		}
	}
	for item in config.actions {
		if form_action_part(item.id) == part {
			if !item.enabled {
				return none
			}
			return FormEvent{
				kind:   item.kind
				action: item.id
			}
		}
	}
	return none
}

// form_first_error is the first visible field with a message, in the order
// the fields are listed: the one to focus after a failed submit.
pub fn form_first_error(config FormConfig) ?string {
	for field in config.fields {
		if field.visible && field.kind == .field && field.error.len > 0 {
			return field.id
		}
	}
	return none
}

// form_responsive_columns is columns, or one while width is below breakpoint.
pub fn form_responsive_columns(width f64, columns int, breakpoint f64) int {
	return if breakpoint > 0 && width < breakpoint { 1 } else { math.max(columns, 1) }
}

// form_split divides frame side by side into parts, for a control made of
// several (first and last name, city and postal code). A positive width is
// fixed; the zero widths share what is left equally. Fixed widths shrink
// evenly when they do not fit. The frames are relative to frame's origin, for
// children of a view placed at frame.
pub fn form_split(frame Rect, widths []f64, gap f64) []Rect {
	if widths.len == 0 {
		return []Rect{}
	}
	space := if component_finite(gap) { math.max(gap, 0) } else { 0.0 }
	total := math.max(frame.width - space * f64(widths.len - 1), 0)
	mut fixed := 0.0
	mut flexible := 0
	for width in widths {
		if component_finite(width) && width > 0 {
			fixed += width
		} else {
			flexible++
		}
	}
	scale := if fixed > total && fixed > 0 { total / fixed } else { 1.0 }
	share := if flexible > 0 { math.max(total - fixed * scale, 0) / f64(flexible) } else { 0.0 }
	mut frames := []Rect{cap: widths.len}
	mut x := 0.0
	for width in widths {
		w := if component_finite(width) && width > 0 { width * scale } else { share }
		frames << rect(x, 0, w, frame.height)
		x += w + space
	}
	return frames
}

// form_control_frame is where a visible field's control goes, in the
// coordinates of the form's parent: the anchor for a popup that a control in
// the form opens, such as select_popup or date_picker_overlay. For a form that
// is a child of the screen it is the control's frame in the window.
pub fn form_control_frame(config FormConfig, id string) ?Rect {
	layout := form_layout(config) or { return none }
	item := layout.field(id)?
	return rect(config.frame.x + item.control.x, config.frame.y + item.control.y, item.control.width,
		item.control.height)
}

// ── Metrics ─────────────────────────────────────────────────────────

struct FormMetrics {
	control      f64 // The default control height.
	label_size   f64
	label_line   f64
	detail_size  f64 // Descriptions and messages.
	detail_line  f64
	section_size f64
	section_line f64
	label_gap    f64 // Between a label above and its control.
	label_space  f64 // Between the label column and the control.
	detail_gap   f64 // Between a control and its description.
	row_gap      f64
	column_gap   f64
	section_gap  f64 // Added above a section that follows other fields.
	actions_gap  f64 // Above the actions.
	button_gap   f64
	icon         f64
}

fn form_metrics(config FormConfig) FormMetrics {
	cm := component_metrics(config.size)
	label_size := if config.label_text_size > 0 { config.label_text_size } else { cm.font_size }
	detail_size := math.max(11.0, cm.font_size - 2)
	section_size := cm.font_size + 2
	spacing := match config.size {
		.small { 12.0 }
		.medium { 16.0 }
		.large { 20.0 }
	}
	row_gap := if config.row_gap >= 0 { config.row_gap } else { spacing }
	return FormMetrics{
		control:      cm.height
		label_size:   label_size
		label_line:   font_line_height(label_size)
		detail_size:  detail_size
		detail_line:  font_line_height(detail_size)
		section_size: section_size
		section_line: font_line_height(section_size)
		label_gap:    cm.gap
		label_space:  cm.padding * 1.5
		detail_gap:   cm.gap / 2
		row_gap:      row_gap
		column_gap:   if config.column_gap >= 0 { config.column_gap } else { spacing * 1.5 }
		section_gap:  spacing
		actions_gap:  spacing * 1.5
		button_gap:   cm.gap + 2
		icon:         font_em_pixels(detail_size) + 1
	}
}

// The advance widths of the printable ASCII characters, space to tilde in
// code point order, in thousandths of an em: of the system face at 14 points
// (its tracking changes a little with the size) and of Roboto, which the
// custom renderer draws with.
const form_widths_system = [u16(271), 300, 467, 619, 619, 915, 701, 286, 371, 371, 461, 619, 286,
	461, 286, 294, 619, 453, 593, 616, 633, 607, 626, 559, 628, 626, 286, 286, 619, 619, 619, 502,
	907, 663, 646, 705, 716, 585, 562, 736, 731, 257, 527, 648, 557, 863, 731, 761, 625, 761, 643,
	626, 623, 727, 663, 957, 668, 645, 651, 371, 294, 371, 619, 573, 489, 541, 604, 549, 604, 561,
	351, 599, 578, 236, 236, 532, 242, 859, 573, 580, 600, 599, 370, 513, 353, 573, 531, 764, 514,
	532, 528, 371, 248, 371, 619]

const form_widths_roboto = [u16(248), 258, 320, 616, 562, 732, 622, 175, 342, 348, 431, 567, 197,
	276, 264, 413, 562, 562, 562, 562, 562, 562, 562, 562, 562, 562, 242, 211, 508, 549, 523, 473,
	898, 652, 623, 651, 656, 568, 553, 681, 713, 272, 552, 627, 539, 873, 713, 688, 631, 688, 616,
	594, 597, 648, 637, 887, 627, 601, 599, 265, 411, 265, 418, 451, 309, 544, 562, 523, 564, 530,
	348, 562, 551, 243, 239, 507, 243, 877, 552, 570, 562, 568, 339, 516, 327, 551, 484, 751, 496,
	473, 496, 338, 244, 338, 680]

// form_glyph_widths is the table for the face labels are drawn in. Win32's
// Segoe UI is close enough to Roboto for this.
fn form_glyph_widths() []u16 {
	$if ui2_custom_rendering ? {
		return form_widths_roboto
	} $else $if macos || ios {
		return form_widths_system
	} $else {
		return form_widths_roboto
	}
}

// form_label_inset is how far in from its frame a label's text starts: AppKit
// text fields, which draw native labels, keep two points on either side.
fn form_label_inset() f64 {
	$if ui2_custom_rendering ? {
		return 0
	} $else $if macos {
		return 2
	} $else {
		return 0
	}
}

// form_text_scale corrects the table for the renderer: the custom renderer's
// text measures about 3% narrower than Roboto's advances add up to.
fn form_text_scale() f64 {
	$if ui2_custom_rendering ? {
		return 0.97
	} $else $if macos || ios || windows {
		return 1.0
	} $else {
		return 0.97
	}
}

// form_text_width estimates how wide text at size points renders. Unlike
// component_text_width_estimate it knows the widths of the face labels are
// drawn in, which puts a required marker right after its label. Kerning is
// left out, so it errs a little wide.
fn form_text_width(text string, size f64) f64 {
	widths := form_glyph_widths()
	mut thousandths := 0.0
	for r in text.runes() {
		thousandths += if r >= 32 && r <= 126 {
			f64(widths[int(r) - 32])
		} else if r >= 0x2e80 {
			1000.0
		} else {
			600.0
		}
	}
	return thousandths / 1000 * form_text_scale() * font_em_pixels(size)
}

// form_text_lines estimates how many lines text wraps to at width, at least
// one for any text and no more than form_max_description_lines. Word wrapping
// leaves the end of a line empty, so the estimate is generous.
fn form_text_lines(text string, width f64, size f64) int {
	if text.len == 0 {
		return 0
	}
	if width <= 0 {
		return 1
	}
	mut lines := 0
	for paragraph in text.split('\n') {
		lines += math.max(1, int(math.ceil(form_text_width(paragraph, size) * 1.08 / width)))
	}
	return math.min(lines, form_max_description_lines)
}

// ── Validation of the configuration ─────────────────────────────────

fn form_check_length(name string, value f64, allow_negative bool) ! {
	if !component_finite(value) || (!allow_negative && value < 0) {
		return error('form ${name} must be finite and non-negative')
	}
}

fn form_check_config(config FormConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if config.columns < 1 || config.columns > form_max_columns {
		return error('form columns must be between 1 and ${form_max_columns}')
	}
	form_check_length('label width', config.label_width, false)!
	form_check_length('label text size', config.label_text_size, false)!
	form_check_length('collapse width', config.collapse_below, false)!
	form_check_length('row gap', config.row_gap, true)!
	form_check_length('column gap', config.column_gap, true)!
	mut ids := map[string]bool{}
	for field in config.fields {
		if field.id.trim_space().len == 0 || field.id in ids {
			return error('form field ids must be non-empty and unique')
		}
		ids[field.id] = true
		if field.col_span < 1 || field.col_start < 0 {
			return error('form field `${field.id}` needs a positive col_span and a col_start of 0 or more')
		}
		form_check_length('field height', field.height, false)!
		form_check_length('description height', field.description_height, false)!
	}
	mut actions := map[string]bool{}
	for item in config.actions {
		if item.id.trim_space().len == 0 || item.id in actions {
			return error('form action ids must be non-empty and unique')
		}
		actions[item.id] = true
		if item.label.len == 0 && item.icon.len == 0 {
			return error('form action `${item.id}` needs a label or an icon')
		}
		if item.label.len == 0 && item.accessibility_label.trim_space().len == 0 {
			return error('form action `${item.id}` shows only an icon and needs an accessibility label')
		}
		if item.icon.len > 0 && !symbol_known(item.icon) {
			return error('form action `${item.id}` uses `${item.icon}`, which not every renderer can draw; pick a name from symbol_names()')
		}
		form_check_length('action width', item.width, false)!
	}
}

// ── Layout ──────────────────────────────────────────────────────────

struct FormPlacement {
	index  int
	row    int
	column int
	span   int
}

fn form_cells_free(rows [][]bool, row int, column int, span int) bool {
	if row >= rows.len {
		return true
	}
	for c in column .. column + span {
		if rows[row][c] {
			return false
		}
	}
	return true
}

// form_place puts the visible fields on the grid the way CSS grid's sparse
// auto-placement does with one-row items: a field goes at the first place
// after the previous one where its columns are free, a field with a column
// start goes in that column on the first row from there where it fits, and
// holes left behind are not filled later. A section takes a row to itself.
fn form_place(fields []FormField, columns int) []FormPlacement {
	mut placed := []FormPlacement{}
	mut rows := [][]bool{}
	mut row := 0
	mut column := 0
	for index, field in fields {
		if !field.visible {
			continue
		}
		section := field.kind == .section
		span := if section { columns } else { math.min(field.col_span, columns) }
		if section || field.col_start > 0 {
			start := if section { 0 } else { math.min(field.col_start - 1, columns - span) }
			if column > start {
				row++
			}
			column = start
			for !form_cells_free(rows, row, column, span) {
				row++
			}
		} else {
			for {
				for column + span <= columns && !form_cells_free(rows, row, column, span) {
					column++
				}
				if column + span <= columns {
					break
				}
				row++
				column = 0
			}
		}
		for rows.len <= row {
			rows << []bool{len: columns}
		}
		for c in column .. column + span {
			rows[row][c] = true
		}
		placed << FormPlacement{
			index:  index
			row:    row
			column: column
			span:   span
		}
		column += span
	}
	return placed
}

// FormPieces are a field's frames relative to its cell.
struct FormPieces {
	label       Rect
	control     Rect
	description Rect
	height      f64
}

fn form_offset(frame Rect, x f64, y f64) Rect {
	if frame.width == 0 && frame.height == 0 {
		return frame
	}
	return rect(frame.x + x, frame.y + y, frame.width, frame.height)
}

// form_detail_height is the room under a control for its message, custom
// description or description.
fn form_detail_height(field FormField, width f64, reserve bool, m FormMetrics) f64 {
	if field.error.len > 0 {
		return f64(form_text_lines(field.error, width - m.icon - 4, m.detail_size)) * m.detail_line
	}
	if voidptr(field.description_fn) != unsafe { nil } {
		return if field.description_height > 0 { field.description_height } else { m.detail_line }
	}
	if field.description.len > 0 {
		return f64(form_text_lines(field.description, width, m.detail_size)) * m.detail_line
	}
	return if reserve { m.detail_line } else { 0.0 }
}

fn form_field_pieces(field FormField, width f64, vertical bool, config FormConfig, m FormMetrics) FormPieces {
	control_height := if field.height > 0 { field.height } else { m.control }
	label_room := field.label.len > 0 || field.label_indent
	if vertical {
		label_height := if label_room { m.label_line } else { 0.0 }
		control_y := if label_room { label_height + m.label_gap } else { 0.0 }
		control := rect(0, control_y, width, control_height)
		mut height := control_y + control_height
		detail := form_detail_height(field, width, config.reserve_descriptions, m)
		mut description := Rect{}
		if detail > 0 {
			description = rect(0, height + m.detail_gap, width, detail)
			height = description.y + detail
		}
		return FormPieces{
			label:       if label_room { rect(0, 0, width, label_height) } else { Rect{} }
			control:     control
			description: description
			height:      height
		}
	}
	indent := if label_room { math.min(config.label_width, width / 2) } else { 0.0 }
	space := if indent > 0 { math.min(m.label_space, width - indent) } else { 0.0 }
	control_x := indent + space
	control_width := math.max(width - control_x, 0)
	line := m.label_line
	// A control shorter than a label line is centered on it.
	control_y := math.max((line - control_height) / 2, 0)
	control := rect(control_x, control_y, control_width, control_height)
	first := math.min(control_height, m.control)
	label_y := math.max(match field.align {
		.center { control_y + (control_height - line) / 2 }
		.start { control_y + (first - line) / 2 }
		.end { control_y + control_height - first + (first - line) / 2 }
	}, 0)
	mut height := math.max(control_y + control_height, if indent > 0 { label_y + line } else { 0.0 })
	detail := form_detail_height(field, control_width, config.reserve_descriptions, m)
	mut description := Rect{}
	if detail > 0 {
		description = rect(control_x, control_y + control_height + m.detail_gap, control_width,
			detail)
		height = math.max(height, description.y + detail)
	}
	return FormPieces{
		label:       if indent > 0 { rect(0, label_y, indent, line) } else { Rect{} }
		control:     control
		description: description
		height:      height
	}
}

// form_section_pieces stacks a section's title and description over a
// one-pixel rule, which FormPieces reports as the control.
fn form_section_pieces(field FormField, width f64, m FormMetrics) FormPieces {
	mut y := 0.0
	mut title := Rect{}
	if field.label.len > 0 {
		title = rect(0, 0, width, m.section_line)
		y = m.section_line
	}
	mut description := Rect{}
	if field.description.len > 0 {
		if y > 0 {
			y += 2
		}
		height := f64(form_text_lines(field.description, width, m.detail_size)) * m.detail_line
		description = rect(0, y, width, height)
		y += height
	}
	if y > 0 {
		y += m.label_gap
	}
	return FormPieces{
		label:       title
		control:     rect(0, y, width, 1)
		description: description
		height:      y + 1
	}
}

fn form_action_width(item FormAction, size ComponentSize) f64 {
	return if item.width > 0 {
		item.width
	} else {
		styled_button_width(item.label, item.icon, size)
	}
}

// form_action_frames lays the actions out in one row at y, as config's
// actions_align says; buttons shrink evenly when they do not fit.
fn form_action_frames(config FormConfig, width f64, y f64, m FormMetrics) []Rect {
	count := config.actions.len
	if count == 0 {
		return []Rect{}
	}
	gap := math.min(m.button_gap, width / f64(count))
	room := math.max(width - gap * f64(count - 1), 0)
	mut widths := []f64{cap: count}
	if config.actions_align == .stretch {
		for _ in 0 .. count {
			widths << room / f64(count)
		}
	} else {
		mut total := 0.0
		for item in config.actions {
			w := form_action_width(item, config.size)
			widths << w
			total += w
		}
		if total > room && total > 0 {
			for i in 0 .. count {
				widths[i] *= room / total
			}
		}
	}
	mut used := gap * f64(count - 1)
	for w in widths {
		used += w
	}
	mut x := match config.actions_align {
		.start, .stretch { 0.0 }
		.center { math.max((width - used) / 2, 0) }
		.end { math.max(width - used, 0) }
	}
	mut frames := []Rect{cap: count}
	for w in widths {
		frames << rect(x, y, w, m.control)
		x += w + gap
	}
	return frames
}

// form_layout places every visible field and the actions in the form's
// coordinates. It is what form draws, so applications can use it to size
// the form's container and to anchor popups (see form_control_frame).
pub fn form_layout(config FormConfig) !FormLayout {
	form_check_config(config)!
	m := form_metrics(config)
	collapsed := config.collapse_below > 0 && config.frame.width < config.collapse_below
	columns := if collapsed { 1 } else { config.columns }
	vertical := collapsed || config.label_layout == .vertical
	width := config.frame.width
	column_gap := if columns > 1 {
		math.min(m.column_gap, width / f64(columns - 1))
	} else {
		0.0
	}
	column_width := math.max((width - column_gap * f64(columns - 1)) / f64(columns), 0)
	placed := form_place(config.fields, columns)
	mut pieces := []FormPieces{cap: placed.len}
	mut row_count := 0
	for place in placed {
		field := config.fields[place.index]
		cell_width := column_width * f64(place.span) + column_gap * f64(place.span - 1)
		pieces << if field.kind == .section {
			form_section_pieces(field, cell_width, m)
		} else {
			form_field_pieces(field, cell_width, vertical, config, m)
		}
		row_count = math.max(row_count, place.row + 1)
	}
	mut heights := []f64{len: row_count}
	mut sections := []bool{len: row_count}
	for i, place in placed {
		heights[place.row] = math.max(heights[place.row], pieces[i].height)
		if config.fields[place.index].kind == .section {
			sections[place.row] = true
		}
	}
	mut tops := []f64{len: row_count}
	mut y := 0.0
	for row in 0 .. row_count {
		if row > 0 {
			y += m.row_gap
			if sections[row] {
				y += m.section_gap
			}
		}
		tops[row] = y
		y += heights[row]
	}
	mut fields := []FormFieldLayout{cap: placed.len}
	for i, place in placed {
		field := config.fields[place.index]
		x := f64(place.column) * (column_width + column_gap)
		top := tops[place.row]
		cell := rect(x, top, column_width * f64(place.span) + column_gap * f64(place.span - 1),
			heights[place.row])
		fields << FormFieldLayout{
			index:       place.index
			id:          field.id
			kind:        field.kind
			row:         place.row
			column:      place.column
			span:        place.span
			cell:        cell
			label:       form_offset(pieces[i].label, x, top)
			control:     form_offset(pieces[i].control, x, top)
			description: form_offset(pieces[i].description, x, top)
		}
	}
	mut height := y
	mut actions := []Rect{}
	if config.actions.len > 0 {
		actions_y := if row_count > 0 { y + m.actions_gap } else { 0.0 }
		actions = form_action_frames(config, width, actions_y, m)
		height = actions_y + m.control
	}
	return FormLayout{
		fields:   fields
		actions:  actions
		columns:  columns
		vertical: vertical
		height:   height
	}
}

// ── Building ────────────────────────────────────────────────────────

fn form_label_elements(field FormField, frame Rect, config FormConfig, m FormMetrics, vertical bool) []Element {
	align := if vertical { Align.left } else { config.label_align }
	style := TextStyle{
		color:  config.theme.foreground
		size:   m.label_size
		align:  align
		valign: .middle
	}
	inset := form_label_inset()
	full := form_text_width(field.label, m.label_size)
	if !field.required {
		return [
			Element{
				...label('', field.label, frame, style)
				key:     'label:' + field.id
				tooltip: if full > frame.width - 2 * inset { field.label } else { '' }
			},
		]
	}
	// The marker goes a few points after the label's estimated end. The label
	// gives up room for it, so a long label is cut short before the marker.
	// The marker's own frame has some slack: text that does not fit its frame
	// becomes an ellipsis.
	gap := 3.0
	star := form_text_width('*', m.label_size) + 4
	room := math.max(frame.width - gap - star, 0)
	shown := math.max(math.min(full, room - 2 * inset), 0)
	text_end := match align {
		.left { frame.x + inset + shown }
		.center { frame.x + (room + shown) / 2 }
		.right { frame.x + room - inset }
	}
	return [
		Element{
			...label('', field.label, rect(frame.x, frame.y, room, frame.height), style)
			key:                 'label:' + field.id
			tooltip:             if full > room - 2 * inset { field.label } else { '' }
			accessibility_label: '${field.label}, required'
		},
		Element{
			...label('', '*', rect(math.max(text_end + gap - inset, frame.x), frame.y,
				star + 2 * inset, frame.height), TextStyle{
				color:  config.theme.danger
				size:   m.label_size
				valign: .middle
			})
			key:                 'required:' + field.id
			accessibility_label: 'required'
		},
	]
}

// form_line_count is how many description lines fit in height. Labels get
// the count rather than 0 (as many as fit), which AppKit draws on one line.
fn form_line_count(height f64, m FormMetrics) int {
	return math.max(1, int(math.round(height / m.detail_line)))
}

// form_detail_frame is the frame of a description label: the room the layout
// gave it and a little more below, as AppKit cuts the last line short when
// the frame is a fraction of a point too low for it.
fn form_detail_frame(frame Rect) Rect {
	return rect(frame.x, frame.y, frame.width, frame.height + 4)
}

fn form_message_elements(field FormField, frame Rect, config FormConfig, m FormMetrics) []Element {
	icon := math.min(m.icon, frame.width)
	text_x := math.min(icon + 4, frame.width)
	return [
		Element{
			...image('', 'symbol:exclamationmark.circle', rect(frame.x, frame.y +
				(m.detail_line - icon) / 2, icon, icon))
			key:                 'error-icon:' + field.id
			text_style:          TextStyle{
				color: config.theme.danger
			}
			accessibility_label: 'Error'
		},
		Element{
			...label('', field.error, form_detail_frame(rect(frame.x + text_x, frame.y,
				frame.width - text_x, frame.height)), TextStyle{
				color:  config.theme.danger
				size:   m.detail_size
				valign: .top
				lines:  form_line_count(frame.height, m)
			})
			key:                 'error:' + field.id
			accessibility_label: field.error
		},
	]
}

fn form_field_elements(field FormField, item FormFieldLayout, config FormConfig, m FormMetrics, vertical bool) ![]Element {
	mut out := []Element{}
	if field.label.len > 0 && item.label.width > 0 {
		out << form_label_elements(field, item.label, config, m, vertical)
	}
	name := if field.accessibility_label.len > 0 {
		field.accessibility_label
	} else {
		field.label
	}
	if voidptr(field.control) != unsafe { nil } {
		control := field.control(item.control)!
		out << Element{
			...control
			key:                 'control:' + field.id
			accessibility_label: if control.accessibility_label.len > 0 {
				control.accessibility_label
			} else {
				name
			}
		}
	} else if field.text.len > 0 {
		out << Element{
			...label('', field.text, item.control, TextStyle{
				color:  config.theme.foreground
				size:   m.label_size
				valign: .middle
			})
			key: 'control:' + field.id
		}
	}
	if item.description.height <= 0 {
		return out
	}
	if field.error.len > 0 {
		out << form_message_elements(field, item.description, config, m)
	} else if voidptr(field.description_fn) != unsafe { nil } {
		custom := field.description_fn(item.description)!
		out << Element{
			...custom
			key: 'description:' + field.id
		}
	} else if field.description.len > 0 {
		out << Element{
			...label('', field.description, form_detail_frame(item.description), TextStyle{
				color:  config.theme.muted_foreground
				size:   m.detail_size
				valign: .top
				lines:  form_line_count(item.description.height, m)
			})
			key: 'description:' + field.id
		}
	}
	return out
}

fn form_section_elements(field FormField, item FormFieldLayout, config FormConfig, m FormMetrics) []Element {
	mut out := []Element{}
	if field.label.len > 0 {
		out << Element{
			...label('', field.label, item.label, TextStyle{
				color:  config.theme.foreground
				size:   m.section_size
				bold:   true
				valign: .middle
			})
			key:                'section:' + field.id
			accessibility_role: 'heading'
		}
	}
	if field.description.len > 0 {
		out << Element{
			...label('', field.description, form_detail_frame(item.description), TextStyle{
				color:  config.theme.muted_foreground
				size:   m.detail_size
				valign: .top
				lines:  form_line_count(item.description.height, m)
			})
			key: 'description:' + field.id
		}
	}
	out << Element{
		...view('', item.control, BoxStyle{ bg: config.theme.border }, []Element{})
		key:                'rule:' + field.id
		accessibility_role: 'separator'
	}
	return out
}

// form lays out labelled fields and an actions row. Fields flow over
// `columns` columns left to right, top to bottom, honoring col_span and
// col_start; labels go above or beside their controls (label_layout). Each
// control is built by its field's closure at the frame form_layout gives it,
// in the form's coordinates. The form's view is as tall as its frame or its
// content, whichever is taller. Decode the actions with form_event.
pub fn form(config FormConfig) !Element {
	layout := form_layout(config)!
	m := form_metrics(config)
	mut children := []Element{}
	for item in layout.fields {
		field := config.fields[item.index]
		if field.kind == .section {
			children << form_section_elements(field, item, config, m)
		} else {
			children << form_field_elements(field, item, config, m, layout.vertical)!
		}
	}
	for index, action in config.actions {
		variant := action.variant or {
			if action.kind == .submit { ButtonVariant.primary } else { ButtonVariant.secondary }
		}
		pressable := styled_button(
			id:                  form_action_id(config.id, action.id)
			frame:               layout.actions[index]
			label:               action.label
			icon:                action.icon
			variant:             variant
			outline:             action.outline
			enabled:             action.enabled
			accessibility_label: action.accessibility_label
			size:                config.size
			theme:               config.theme
		)!
		children << Element{
			...pressable
			key: 'action:' + action.id
		}
	}
	frame := config.frame
	return component_finish(Element{
		...view(config.id, rect(frame.x, frame.y, frame.width, math.max(frame.height, layout.height)),
			BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
	})
}

pub struct FormFieldConfig {
pub:
	id              string
	frame           Rect
	field           FormField
	label_layout    LayoutOrientation = .vertical
	label_width     f64               = 140
	label_align     Align
	label_text_size f64
	size            ComponentSize = .medium
	theme           ComponentTheme
}

// form_field draws one field on its own, laid out as in a one-column form: a
// labelled control anywhere in a layout. The control's frame is relative to
// the field's view.
pub fn form_field(config FormFieldConfig) !Element {
	return form(FormConfig{
		id:                  config.id
		frame:               config.frame
		fields:              [config.field]
		label_layout:        config.label_layout
		label_width:         config.label_width
		label_align:         config.label_align
		label_text_size:     config.label_text_size
		accessibility_label: config.field.label
		size:                config.size
		theme:               config.theme
	})
}
