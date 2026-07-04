module ui2

pub type BuildFn = fn () Element

pub type EventFn = fn (string)

// KeyFn receives normalized key strings: 'up', 'forward_delete', 'cmd+shift+r', 'f5', ...
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
	button
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
	color u32 = 0x111111
	size  f64 = 15.0
	bold  bool
	align Align
	lines int = 1
}

pub struct BoxStyle {
pub:
	bg     u32 = 0xffffff
	radius f64
}

pub struct Element {
	kind Kind
pub:
	id          string
	key         string // stable identity for reconciliation (falls back to child index)
	text        string
	placeholder string
	frame       Rect
	box         BoxStyle
	text_style  TextStyle
	keyboard    int
	emit_change bool
	long_press  bool
	swipe_left  bool
	readonly    bool // text_area: selectable but not editable
	secure      bool // text_field: password entry (NSSecureTextField)
	menu        []MenuEntry
	children    []Element
}

pub const keyboard_default = 0
pub const keyboard_decimal = 8

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
