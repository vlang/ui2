module ui2

pub type BuildFn = fn () Element

pub type EventFn = fn (string)

// KeyFn receives normalized key strings: 'up', 'forward_delete',
// 'cmd+shift+r', 'f5', or text-view commands like 'text:editor:backspace'
// and 'text:editor:line_break'.
pub type KeyFn = fn (string)

// ScrollFn receives the id of the Scroll element whose position changed.
pub type ScrollFn = fn (string)

pub enum Align {
	left
	center
	right
}

enum Kind {
	screen
	view
	label
	image
	button
	dropdown
	text_field
	text_area
	scroll
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
	color            u32 = 0x111111
	background_color u32
	size             f64 = 15.0
	font_family      string
	bold             bool
	italic           bool
	underline        bool
	strikethrough    bool
	vertical_align   string
	link             string
	align            Align
	lines            int = 1
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
	subscript     bool
	superscript   bool
}

pub struct BoxStyle {
pub:
	bg          u32 = 0xffffff
	radius      f64
	transparent bool
}

pub struct Element {
	kind Kind
pub:
	id             string
	key            string // stable identity for reconciliation (falls back to child index)
	text           string
	image_path     string
	placeholder    string
	frame          Rect
	box            BoxStyle
	text_style     TextStyle
	text_runs      []TextRun // text_area: optional rich text style runs
	keyboard       int
	emit_change    bool
	long_press     bool
	swipe_left     bool
	readonly       bool   // text_area: selectable but not editable
	disable_scroll bool   // text_area: hide the internal scroll view scroller
	secure         bool   // text_field: password entry (NSSecureTextField)
	clickable      bool   // view/image: emit pointer down/up events
	draggable      bool   // view/image: emit pointer drag events
	rotation       f64    // image: clockwise degrees
	cursor         string // view/image: hover cursor hint
	menu           []MenuEntry
	children       []Element
}

pub const keyboard_default = 0
pub const keyboard_decimal = 8
pub const cursor_default = ''
pub const cursor_pointing_hand = 'pointing_hand'
pub const cursor_resize_nwse = 'resize_nwse'
pub const cursor_resize_nesw = 'resize_nesw'
pub const cursor_rotate = 'rotate'

pub fn rect(x f64, y f64, width f64, height f64) Rect {
	return Rect{
		x:      x
		y:      y
		width:  width
		height: height
	}
}

pub fn screen(bg u32, children []Element) Element {
	return Element{
		kind:     .screen
		box:      BoxStyle{
			bg: bg
		}
		children: children
	}
}

pub fn view(id string, frame Rect, box_ BoxStyle, children []Element) Element {
	return Element{
		kind:     .view
		id:       id
		frame:    frame
		box:      box_
		children: children
	}
}

pub fn draggable_view(id string, frame Rect, box_ BoxStyle, children []Element) Element {
	return Element{
		kind:      .view
		id:        id
		frame:     frame
		box:       box_
		draggable: true
		children:  children
	}
}

pub fn draggable_view_with_cursor(id string, frame Rect, box_ BoxStyle, cursor string, children []Element) Element {
	return Element{
		kind:      .view
		id:        id
		frame:     frame
		box:       box_
		draggable: true
		cursor:    cursor
		children:  children
	}
}

pub fn view_with_long_press(id string, frame Rect, box_ BoxStyle, children []Element) Element {
	return Element{
		kind:       .view
		id:         id
		frame:      frame
		box:        box_
		long_press: true
		children:   children
	}
}

pub fn view_with_long_press_and_swipe_left(id string, frame Rect, box_ BoxStyle, children []Element) Element {
	return Element{
		kind:       .view
		id:         id
		frame:      frame
		box:        box_
		long_press: true
		swipe_left: true
		children:   children
	}
}

pub fn scroll(id string, frame Rect, bg u32, children []Element) Element {
	return Element{
		kind:     .scroll
		id:       id
		frame:    frame
		box:      BoxStyle{
			bg: bg
		}
		children: children
	}
}

pub fn label(id string, text string, frame Rect, style TextStyle) Element {
	return Element{
		kind:       .label
		id:         id
		text:       text
		frame:      frame
		text_style: style
	}
}

pub fn image(id string, path string, frame Rect) Element {
	return Element{
		kind:       .image
		id:         id
		image_path: path
		frame:      frame
	}
}

pub fn transformed_image(id string, path string, frame Rect, rotation f64, clickable bool) Element {
	return Element{
		kind:       .image
		id:         id
		image_path: path
		frame:      frame
		rotation:   rotation
		clickable:  clickable
	}
}

pub fn transformed_image_with_cursor(id string, path string, frame Rect, rotation f64, clickable bool, cursor string) Element {
	return Element{
		kind:       .image
		id:         id
		image_path: path
		frame:      frame
		rotation:   rotation
		clickable:  clickable
		cursor:     cursor
	}
}

pub fn button(id string, title string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind:       .button
		id:         id
		text:       title
		frame:      frame
		box:        box_
		text_style: style
	}
}

pub fn button_with_image(id string, title string, image_name string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind:       .button
		id:         id
		text:       title
		image_path: image_name
		frame:      frame
		box:        box_
		text_style: style
	}
}

pub fn button_with_long_press(id string, title string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind:       .button
		id:         id
		text:       title
		frame:      frame
		box:        box_
		text_style: style
		long_press: true
	}
}

pub fn dropdown(id string, selected string, options []string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	mut entries := []MenuEntry{}
	for option in options {
		entries << MenuEntry{
			id:    option
			title: option
		}
	}
	return Element{
		kind:       .dropdown
		id:         id
		text:       selected
		frame:      frame
		box:        box_
		text_style: style
		menu:       entries
	}
}

pub fn text_field(id string, placeholder string, text string, frame Rect, box_ BoxStyle, style TextStyle, keyboard int) Element {
	return Element{
		kind:        .text_field
		id:          id
		text:        text
		placeholder: placeholder
		frame:       frame
		box:         box_
		text_style:  style
		keyboard:    keyboard
	}
}

// text_area is a multi-line editor (NSTextView on macOS) with native
// wrapping, scrolling, selection, clipboard and undo.
pub fn text_area(id string, text string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind:       .text_area
		id:         id
		text:       text
		frame:      frame
		box:        box_
		text_style: style
	}
}

pub fn text_area_without_scroll(id string, text string, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind:           .text_area
		id:             id
		text:           text
		frame:          frame
		box:            box_
		text_style:     style
		disable_scroll: true
	}
}

pub fn rich_text_area(id string, text string, runs []TextRun, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind:       .text_area
		id:         id
		text:       text
		frame:      frame
		box:        box_
		text_style: style
		text_runs:  runs
	}
}

pub fn rich_text_area_without_scroll(id string, text string, runs []TextRun, frame Rect, box_ BoxStyle, style TextStyle) Element {
	return Element{
		kind:           .text_area
		id:             id
		text:           text
		frame:          frame
		box:            box_
		text_style:     style
		text_runs:      runs
		disable_scroll: true
	}
}

pub fn text_field_with_change(id string, placeholder string, text string, frame Rect, box_ BoxStyle, style TextStyle, keyboard int) Element {
	return Element{
		kind:        .text_field
		id:          id
		text:        text
		placeholder: placeholder
		frame:       frame
		box:         box_
		text_style:  style
		keyboard:    keyboard
		emit_change: true
	}
}
