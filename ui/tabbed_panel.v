module ui2

pub enum TabPosition {
	top_left
	top_mid
	top_right
	bottom_left
	bottom_mid
	bottom_right
	left_top
	left_mid
	left_bottom
	right_top
	right_mid
	right_bottom
}

pub struct TabbedPanelTab {
pub:
	id        string
	title     string
	action_id string
	content   Element
	enabled   bool = true
}

pub struct TabbedPanelConfig {
pub:
	id                       string
	frame                    Rect
	box                      BoxStyle
	current                  int
	tab_position             TabPosition
	tab_height               f64 = 40.0
	tab_width                f64 = 100.0
	header_box               BoxStyle
	active_header_box        BoxStyle
	header_text_style        TextStyle
	active_header_text_style TextStyle
	tabs                     []TabbedPanelTab
}

pub struct TabbedPanelGeometry {
pub:
	content Rect
	headers []Rect
}

pub fn tab_position(value string) !TabPosition {
	return match value {
		'', 'top_left' { .top_left }
		'top_mid' { .top_mid }
		'top_right' { .top_right }
		'bottom_left' { .bottom_left }
		'bottom_mid' { .bottom_mid }
		'bottom_right' { .bottom_right }
		'left_top' { .left_top }
		'left_mid' { .left_mid }
		'left_bottom' { .left_bottom }
		'right_top' { .right_top }
		'right_mid' { .right_mid }
		'right_bottom' { .right_bottom }
		else {
			return error('unknown tab position `${value}`')
		}
	}
}

pub fn tabbed_panel_current(current int, tab_count int) int {
	if tab_count <= 0 || current < 0 {
		return 0
	}
	return if current < tab_count { current } else { tab_count - 1 }
}

fn tabs_on_top(position TabPosition) bool {
	return position in [.top_left, .top_mid, .top_right]
}

fn tabs_on_bottom(position TabPosition) bool {
	return position in [.bottom_left, .bottom_mid, .bottom_right]
}

fn tabs_are_horizontal(position TabPosition) bool {
	return tabs_on_top(position) || tabs_on_bottom(position)
}

fn tab_strip_alignment(position TabPosition) BoxAlignment {
	return match position {
		.top_left, .bottom_left, .left_top, .right_top { .start }
		.top_mid, .bottom_mid, .left_mid, .right_mid { .center }
		.top_right, .bottom_right, .left_bottom, .right_bottom { .end }
	}
}

fn tabbed_panel_validate(config TabbedPanelConfig) ! {
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('tabbed panel dimensions cannot be negative')
	}
	if config.tab_height < 0 || config.tab_width < 0 {
		return error('tab dimensions cannot be negative')
	}
	if (tabs_are_horizontal(config.tab_position) && config.tab_height > config.frame.height)
		|| (!tabs_are_horizontal(config.tab_position) && config.tab_height > config.frame.width) {
		return error('tab height exceeds the panel bounds')
	}
}

fn tab_strip_start(available f64, occupied f64, alignment BoxAlignment) f64 {
	return match alignment {
		.start { 0 }
		.center { (available - occupied) / 2 }
		.end { available - occupied }
	}
}

// tabbed_panel_geometry returns one content frame and a header frame for every
// declared tab. A zero tab_width distributes headers evenly along the strip.
pub fn tabbed_panel_geometry(config TabbedPanelConfig) !TabbedPanelGeometry {
	tabbed_panel_validate(config)!
	horizontal := tabs_are_horizontal(config.tab_position)
	content := if horizontal {
		rect(0, if tabs_on_top(config.tab_position) { config.tab_height } else { 0 }, config.frame.width, config.frame.height - config.tab_height)
	} else {
		rect(if config.tab_position in [.left_top, .left_mid, .left_bottom] {
			config.tab_height
		} else {
			0
		}, 0, config.frame.width - config.tab_height, config.frame.height)
	}
	if config.tabs.len == 0 {
		return TabbedPanelGeometry{ content: content }
	}
	available := if horizontal { config.frame.width } else { config.frame.height }
	length := if config.tab_width > 0 {
		config.tab_width
	} else {
		available / f64(config.tabs.len)
	}
	occupied := length * f64(config.tabs.len)
	mut cursor := tab_strip_start(available, occupied, tab_strip_alignment(config.tab_position))
	mut headers := []Rect{cap: config.tabs.len}
	for _ in config.tabs {
		if horizontal {
			y := if tabs_on_top(config.tab_position) {
				0.0
			} else {
				config.frame.height - config.tab_height
			}
			headers << rect(cursor, y, length, config.tab_height)
		} else {
			x := if config.tab_position in [.left_top, .left_mid, .left_bottom] {
				0.0
			} else {
				config.frame.width - config.tab_height
			}
			headers << rect(x, cursor, config.tab_height, length)
		}
		cursor += length
	}
	return TabbedPanelGeometry{
		content: content
		headers: headers
	}
}

pub fn tabbed_panel(config TabbedPanelConfig) !Element {
	geometry := tabbed_panel_geometry(config)!
	mut children := []Element{}
	if config.tabs.len > 0 {
		current := tabbed_panel_current(config.current, config.tabs.len)
		active := config.tabs[current]
		children << Element{
			...active.content
			frame: geometry.content
		}
	}
	for index, tab in config.tabs {
		active := index == tabbed_panel_current(config.current, config.tabs.len)
		children << Element{
			...button(tab.id, tab.title, geometry.headers[index], if active {
				config.active_header_box
			} else {
				config.header_box
			}, if active { config.active_header_text_style } else { config.header_text_style })
			action_id: tab.action_id
			enabled: tab.enabled
			accessibility_role: 'tab'
			accessibility_value: if active { 'selected' } else { 'not selected' }
		}
	}
	return view(config.id, config.frame, config.box, children)
}
