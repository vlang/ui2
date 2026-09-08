module ui2

pub type BuildFn = fn () Element

pub type EventFn = fn (string)

// KeyFn receives normalized key strings: 'up', 'forward_delete', 'tab',
// 'cmd+shift+r', 'f5', or text-view commands like 'text:editor:backspace'
// and 'text:editor:line_break'.
pub type KeyFn = fn (string)

// ScrollFn receives the id of the Scroll element whose position changed.
pub type ScrollFn = fn (string)

// DropFn receives file URLs and/or plain text dropped on the application
// window, plus the pointer location in root-view coordinates.
pub type DropFn = fn (DropEvent)

pub struct DropEvent {
pub:
	paths []string
	text  string
	x     f64
	y     f64
}

pub enum Align {
	left
	center
	right
}

pub enum Kind {
	screen
	view
	label
	image
	button
	checkbox
	dropdown
	text_field
	text_area
	scroll
	slider
	switch_control
}

// MenuEntry is one right-click context menu item attached to an element.
pub struct MenuEntry {
pub:
	id    string
	title string
}

pub struct Rect {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

pub struct TextStyle {
pub:
	color              u32 = 0x111111
	background_color   u32
	size               f64 = 15.0
	font_family        string
	bold               bool
	italic             bool
	underline          bool
	strikethrough      bool
	shadow             bool
	outline            bool
	vertical_align     string
	link               string
	align              Align
	head_indent        f64
	first_line_indent  f64
	hyphenation_factor f64
	lines              int = 1
}

pub struct TextRun {
pub:
	text  string
	style TextStyle
}

pub enum TextFormat {
	bold
	italic
	underline
	strikethrough
}

pub struct TextFormatState {
pub:
	bold          bool
	italic        bool
	underline     bool
	strikethrough bool
	shadow        bool
	outline       bool
	subscript     bool
	superscript   bool
}

pub struct BoxStyle {
pub:
	bg            u32 = 0xffffff
	radius        f64
	transparent   bool
	border_color  u32
	border_left   f64
	border_top    f64
	border_right  f64
	border_bottom f64
}

// box_border_width keeps a declared border inside its element. Border widths
// are logical units, just like Rect and corner radii; each backend is
// responsible for mapping those units to its native device scale.
fn box_border_width(width f64, extent f64) f64 {
	if width <= 0 || extent <= 0 {
		return 0
	}
	return if width < extent { width } else { extent }
}

pub struct Element {
pub:
	// kind is readable from outside the module so a renderer can live in
	// another package: dispatching on it is the first thing any backend does.
	kind                  Kind
	id                    string // lookup/state identity
	action_id             string // event identity (falls back to id)
	submit_id             string // text_field: optional event id emitted when Return submits
	key                   string // stable identity for reconciliation (falls back to child index)
	text                  string
	checked               bool // checkbox: declared on/off state
	image_path            string
	tooltip               string
	placeholder           string
	frame                 Rect
	box                   BoxStyle
	text_style            TextStyle
	native_style          bool // button: let the platform own bezel and interaction styling
	text_runs             []TextRun // text_area: optional rich text style runs
	keyboard              int
	emit_change           bool
	long_press            bool
	swipe_left            bool
	readonly              bool // text_area: selectable but not editable
	disable_scroll        bool // text_area: hide the internal scroll view scroller
	persistent_scrollbars bool // scroll: keep a legacy always-visible scroller instead of the auto-fading overlay one
	secure                bool // text_field: native password entry
	clickable             bool // view/image: emit pointer down/up events
	draggable             bool // view/image: emit pointer drag events
	rotation              f64 // image: clockwise degrees
	cursor                string // view/image: hover cursor hint
	menu                  []MenuEntry
	children              []Element
	hidden                bool
	enabled               bool = true
	accessibility_role    string
	accessibility_label   string
	accessibility_value   string
	autocorrect           bool = true // native text inputs
	padding_left          f64 = 12.0 // text input content inset
	value                 f64 // slider: current value
	min_value             f64 // slider: lower range boundary
	max_value             f64 = 100.0 // slider: upper range boundary
	step                  f64 // slider: zero is continuous
	orientation           Orientation // slider: horizontal or vertical
	padding               f64 = 16.0 // slider: inset from each end of its track
	value_track           bool // slider: color the track between min and value
	slider_style          SliderStyle
	switch_style          SwitchStyle
}

pub enum BackendSupport {
	unsupported
	partial
	supported
}

// control_support makes backend differences explicit. Partial means the
// control works but lacks some native behavior (for example Android rich text).
pub fn control_support(kind Kind) BackendSupport {
	$if ( macos || windows ) && ui2_custom_rendering ? {
		return match kind {
			.text_area, .dropdown { .partial }
			else { .supported }
		}
	} $else $if macos {
		return .supported
	} $else $if ios {
		return match kind {
			.text_area, .checkbox { .partial }
			else { .supported }
		}
	} $else $if android || linux {
		return match kind {
			.text_area, .dropdown { .partial }
			else { .supported }
		}
	} $else $if windows {
		return match kind {
			.image, .text_area { .partial }
			else { .supported }
		}
	} $else {
		return .unsupported
	}
}

fn element_action_id(el Element) string {
	return if el.action_id.len > 0 { el.action_id } else { el.id }
}

// reconciliation_child_key encodes user keys so separators inside a key
// cannot alias a nested key path.
fn reconciliation_child_key(parent string, index int, el Element) string {
	suffix := if el.key.len > 0 { 'k:' + el.key.bytes().hex() } else { 'i:' + index.str() }
	return if parent.len == 0 { suffix } else { parent + '/' + suffix }
}

// validate_element_tree rejects ambiguous declarative identity before a
// renderer mutates native state.
pub fn validate_element_tree(root Element) ! {
	mut ids := map[string]bool{}
	validate_element_node(root, 'root', mut ids)!
}

fn validate_element_node(el Element, path string, mut ids map[string]bool) ! {
	if el.id.len > 0 {
		if el.id in ids {
			return error('duplicate element id `${el.id}` at ${path}')
		}
		ids[el.id] = true
	}
	mut keys := map[string]bool{}
	for index, child in el.children {
		if child.key.len > 0 {
			if child.key in keys {
				return error('duplicate sibling key `${child.key}` at ${path}')
			}
			keys[child.key] = true
		}
		validate_element_node(child, '${path}/${index}', mut ids)!
	}
}

pub const keyboard_default = 0
pub const keyboard_decimal = 8
pub const cursor_default = ''
pub const cursor_pointing_hand = 'pointing_hand'
pub const cursor_resize_nwse = 'resize_nwse'
pub const cursor_resize_nesw = 'resize_nesw'
pub const cursor_resize_ew = 'resize_ew'
pub const cursor_resize_ns = 'resize_ns'
pub const cursor_rotate = 'rotate'

pub fn rect(x f64, y f64, width f64, height f64) Rect {
	return Rect{
		x: x
		y: y
		width: width
		height: height
	}
}

fn intersect_rect(a Rect, b Rect) Rect {
	left := if a.x > b.x { a.x } else { b.x }
	top := if a.y > b.y { a.y } else { b.y }
	right_a := a.x + a.width
	right_b := b.x + b.width
	bottom_a := a.y + a.height
	bottom_b := b.y + b.height
	right := if right_a < right_b { right_a } else { right_b }
	bottom := if bottom_a < bottom_b { bottom_a } else { bottom_b }
	return Rect{
		x: left
		y: top
		width: if right > left { right - left } else { 0 }
		height: if bottom > top { bottom - top } else { 0 }
	}
}

pub fn screen(bg u32, children []Element) Element {
	return Element{
		kind: .screen
		box: BoxStyle{
			bg: bg
		}
		children: children
	}
}

pub fn view(id string, frame Rect, box_ BoxStyle, children []Element) Element {
	return Element{
		kind: .view
		id: id
		frame: frame
		box: box_
		children: children
	}
}

// clickable_view is a container that reports pointer down and up on itself,
// for a surface that is not a control but still has to answer a click — the
// body of a window that should come to the front when it is touched, say.
pub fn clickable_view(id string, frame Rect, box_ BoxStyle, children []Element) Element {
	return Element{
		kind: .view
		id: id
		frame: frame
		box: box_
		clickable: true
		children: children
	}
}

pub fn draggable_view(id string, frame Rect, box_ BoxStyle, children []Element) Element {
	return Element{
		kind: .view
		id: id
		frame: frame
		box: box_
		draggable: true
		children: children
	}
}

pub fn draggable_view_with_cursor(id string, frame Rect, box_ BoxStyle, cursor string, children []Element) Element {
	return Element{
		kind: .view
		id: id
		frame: frame
		box: box_
		draggable: true
		cursor: cursor
		children: children
	}
}

pub fn view_with_long_press(id string, frame Rect, box_ BoxStyle, children []Element) Element {
	return Element{
		kind: .view
		id: id
		frame: frame
		box: box_
		long_press: true
		children: children
	}
}

pub fn view_with_long_press_and_swipe_left(id string, frame Rect, box_ BoxStyle, children []Element) Element {
	return Element{
		kind: .view
		id: id
		frame: frame
		box: box_
		long_press: true
		swipe_left: true
		children: children
	}
}

pub fn scroll(id string, frame Rect, bg u32, children []Element) Element {
	return Element{
		kind: .scroll
		id: id
		frame: frame
		box: BoxStyle{
			bg: bg
		}
		children: children
	}
}

// scroll_persistent behaves like scroll but keeps a legacy, always-visible
// scroller (when the content overflows) rather than the system overlay scroller
// that fades out once scrolling stops. Suited to spreadsheet-style grids where a
// draggable scrollbar should stay on screen.
pub fn scroll_persistent(id string, frame Rect, bg u32, children []Element) Element {
	return Element{
		kind: .scroll
		id: id
		frame: frame
		box: BoxStyle{
			bg: bg
		}
		children: children
		persistent_scrollbars: true
	}
}

pub fn label(id string, text string, frame Rect, style TextStyle) Element {
	return Element{
		kind: .label
		id: id
		text: text
		frame: frame
		text_style: style
	}
}

pub fn image(id string, path string, frame Rect) Element {
	return Element{
		kind: .image
		id: id
		image_path: path
		frame: frame
	}
}

pub fn transformed_image(id string, path string, frame Rect, rotation f64, clickable bool) Element {
	return Element{
		kind: .image
		id: id
		image_path: path
		frame: frame
		rotation: rotation
		clickable: clickable
	}
}

pub fn transformed_image_with_cursor(id string, path string, frame Rect, rotation f64, clickable bool, cursor string) Element {
	return Element{
		kind: .image
		id: id
		image_path: path
		frame: frame
		rotation: rotation
		clickable: clickable
		cursor: cursor
	}
}

pub fn button(id string, title string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind: .button
		id: id
		text: title
		frame: frame
		box: box_
		text_style: style
	}
}

// with_native_style lets the platform render a button's standard bezel and
// interaction states. Declared styles remain available to custom renderers.
pub fn with_native_style(el Element) Element {
	return Element{
		...el
		native_style: true
	}
}

// checkbox creates the platform checkbox control. Its id is emitted when the
// user toggles it; rebuild with the updated checked value to retain that state.
pub fn checkbox(id string, title string, checked bool, frame Rect, style TextStyle) Element {
	return Element{
		kind: .checkbox
		id: id
		text: title
		checked: checked
		frame: frame
		box: BoxStyle{
			transparent: true
		}
		text_style: style
		accessibility_role: 'checkbox'
		accessibility_label: title
		accessibility_value: if checked { 'checked' } else { 'unchecked' }
	}
}

pub fn button_with_image(id string, title string, image_name string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind: .button
		id: id
		text: title
		image_path: image_name
		frame: frame
		box: box_
		text_style: style
	}
}

// with_tooltip adds hover help without changing an element's visible text.
pub fn with_tooltip(el Element, tooltip string) Element {
	return Element{
		...el
		tooltip: tooltip
	}
}

// with_action separates an emitted event name from the element's lookup id.
pub fn with_action(el Element, action_id string) Element {
	return Element{
		...el
		action_id: action_id
	}
}

// with_secure_entry makes a text field use the platform's native password
// control while retaining the field's change and submit bindings.
pub fn with_secure_entry(el Element) Element {
	return Element{
		...el
		secure: true
	}
}

pub fn button_with_long_press(id string, title string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind: .button
		id: id
		text: title
		frame: frame
		box: box_
		text_style: style
		long_press: true
	}
}

pub fn dropdown(id string, selected string, options []string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	mut entries := []MenuEntry{}
	for option in options {
		entries << MenuEntry{
			id: option
			title: option
		}
	}
	return Element{
		kind: .dropdown
		id: id
		text: selected
		frame: frame
		box: box_
		text_style: style
		menu: entries
	}
}

pub fn text_field(id string, placeholder string, text string, frame Rect, box_ BoxStyle, style TextStyle, keyboard int) Element {
	return Element{
		kind: .text_field
		id: id
		text: text
		placeholder: placeholder
		frame: frame
		box: box_
		text_style: style
		keyboard: keyboard
	}
}

// text_area is a multi-line editor (NSTextView on macOS) with native
// wrapping, scrolling, selection, clipboard and undo.
pub fn text_area(id string, text string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind: .text_area
		id: id
		text: text
		frame: frame
		box: box_
		text_style: style
	}
}

pub fn text_area_without_scroll(id string, text string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind: .text_area
		id: id
		text: text
		frame: frame
		box: box_
		text_style: style
		disable_scroll: true
	}
}

pub fn rich_text_area(id string, text string, runs []TextRun, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind: .text_area
		id: id
		text: text
		frame: frame
		box: box_
		text_style: style
		text_runs: runs
	}
}

pub fn rich_text_area_without_scroll(id string, text string, runs []TextRun, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind: .text_area
		id: id
		text: text
		frame: frame
		box: box_
		text_style: style
		text_runs: runs
		disable_scroll: true
	}
}

pub fn text_field_with_change(id string, placeholder string, text string, frame Rect, box_ BoxStyle, style TextStyle, keyboard int) Element {
	return text_field_with_change_and_submit(id, '', placeholder, text, frame, box_, style, keyboard)
}

// text_field_with_submit emits submit_id when Return/Enter is pressed without
// also emitting a live change event for every edit.
pub fn text_field_with_submit(id string, submit_id string, placeholder string, text string, frame Rect, box_ BoxStyle, style TextStyle, keyboard int) Element {
	return Element{
		kind: .text_field
		id: id
		submit_id: submit_id
		text: text
		placeholder: placeholder
		frame: frame
		box: box_
		text_style: style
		keyboard: keyboard
	}
}

pub fn text_field_with_change_and_submit(id string, submit_id string, placeholder string, text string, frame Rect, box_ BoxStyle, style TextStyle, keyboard int) Element {
	return Element{
		kind: .text_field
		id: id
		submit_id: submit_id
		text: text
		placeholder: placeholder
		frame: frame
		box: box_
		text_style: style
		keyboard: keyboard
		emit_change: true
	}
}

// text_field_display_text preserves the number of Unicode code points while
// keeping secure field contents out of the portable renderer.
fn text_field_display_text(text string, secure bool) string {
	if !secure || text.len == 0 {
		return text
	}
	mut masked := []rune{cap: rune_len(text)}
	for _ in text.runes() {
		masked << `•`
	}
	return masked.string()
}
