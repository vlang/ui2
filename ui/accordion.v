module ui2

pub struct AccordionItem {
pub:
	id        string
	title     string
	action_id string // .fill: the action its header emits (.stack emits its own)
	content   Element
	enabled   bool = true
	icon      string // .stack: SF Symbol name drawn before the title
}

// AccordionLayout chooses between the two accordions ui2 offers. The fill layout
// is Kivy's: one item is always open and takes every point the other headers
// leave. The stack layout is GPUI Kit's: items stack from the top, any of them
// (or several, with `multiple`) may be open, and an open panel is as tall as its
// content. See component_disclosure.v.
pub enum AccordionLayout {
	fill
	stack
}

pub struct AccordionConfig {
pub:
	id                       string
	frame                    Rect
	box                      BoxStyle
	current                  int
	orientation              LayoutOrientation
	min_space                f64 = 44.0
	header_box               BoxStyle
	active_header_box        BoxStyle
	header_text_style        TextStyle
	active_header_text_style TextStyle
	items                    []AccordionItem
	// The fields below belong to the stack layout; the fill layout ignores them.
	layout              AccordionLayout
	open                []int // indices of the expanded items
	multiple            bool  // let more than one item be open at a time
	bordered            bool = true // one rounded card; false keeps only the separators
	enabled             bool = true // false disables every item
	hovered             int  = -1   // title row under the pointer: accordion_hover_from_event
	focused             int  = -1   // title row the keyboard is on: accordion_focus_after_key
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub struct AccordionGeometry {
pub:
	items   []Rect
	headers []Rect
	content Rect
}

pub fn accordion_current(current int, item_count int) int {
	return tabbed_panel_current(current, item_count)
}

fn accordion_validate(config AccordionConfig) ! {
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('accordion dimensions cannot be negative')
	}
	if config.min_space < 0 {
		return error('accordion minimum title space cannot be negative')
	}
	available := if config.orientation == .horizontal {
		config.frame.width
	} else {
		config.frame.height
	}
	if config.min_space * f64(config.items.len) > available {
		return error('accordion does not have enough space for all item headers')
	}
}

// accordion_geometry is the fill layout's: it reserves min_space for every
// title and assigns all remaining space to the active item.
pub fn accordion_geometry(config AccordionConfig) !AccordionGeometry {
	accordion_validate(config)!
	if config.items.len == 0 {
		return AccordionGeometry{}
	}
	current := accordion_current(config.current, config.items.len)
	available := if config.orientation == .horizontal {
		config.frame.width
	} else {
		config.frame.height
	}
	display_space := available - config.min_space * f64(config.items.len)
	mut cursor := f64(0)
	mut items := []Rect{cap: config.items.len}
	mut headers := []Rect{cap: config.items.len}
	mut content := Rect{}
	for index in 0 .. config.items.len {
		item_length := config.min_space + if index == current { display_space } else { 0 }
		if config.orientation == .horizontal {
			items << rect(cursor, 0, item_length, config.frame.height)
			headers << rect(cursor, 0, config.min_space, config.frame.height)
			if index == current {
				content = rect(cursor + config.min_space, 0, display_space, config.frame.height)
			}
		} else {
			items << rect(0, cursor, config.frame.width, item_length)
			headers << rect(0, cursor, config.frame.width, config.min_space)
			if index == current {
				content = rect(0, cursor + config.min_space, config.frame.width, display_space)
			}
		}
		cursor += item_length
	}
	return AccordionGeometry{
		items:   items
		headers: headers
		content: content
	}
}

// accordion builds the layout config.layout names. The fill layout (the
// default) is described by accordion_geometry; the stack layout by
// accordion_stack_layout.
pub fn accordion(config AccordionConfig) !Element {
	if config.layout == .stack {
		return accordion_stack(config)
	}
	geometry := accordion_geometry(config)!
	mut children := []Element{}
	if config.items.len > 0 {
		current := accordion_current(config.current, config.items.len)
		children << Element{
			...config.items[current].content
			frame: geometry.content
		}
	}
	for index, item in config.items {
		active := index == accordion_current(config.current, config.items.len)
		children << Element{
			...button(item.id, item.title, geometry.headers[index], if active {
				config.active_header_box
			} else {
				config.header_box
			}, if active { config.active_header_text_style } else { config.header_text_style })
			action_id:           item.action_id
			enabled:             item.enabled
			accessibility_role:  'button'
			accessibility_value: if active { 'expanded' } else { 'collapsed' }
		}
	}
	return view(config.id, config.frame, config.box, children)
}
