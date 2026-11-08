module ui2

import math

// The themed look of tabbed_panel: a tab_bar along one side of the active
// tab's content. TabbedPanelConfig.variant or .theme turns it on.

fn tabbed_panel_themed(config TabbedPanelConfig) bool {
	return config.variant != none || config.theme != none
}

fn tabbed_panel_bar_position(position TabPosition) TabBarPosition {
	return match position {
		.top_left, .top_mid, .top_right { .top }
		.bottom_left, .bottom_mid, .bottom_right { .bottom }
		.left_top, .left_mid, .left_bottom { .left }
		.right_top, .right_mid, .right_bottom { .right }
	}
}

// tabbed_panel_bar_frame is where a themed panel's bar goes, and the content
// frame beside it.
fn tabbed_panel_bar_frames(config TabbedPanelConfig) (Rect, Rect) {
	variant := config.variant or { TabVariant.tab }
	width := config.frame.width
	height := config.frame.height
	position := tabbed_panel_bar_position(config.tab_position)
	if position in [.top, .bottom] {
		bar := math.min(tab_bar_height(variant, config.size), height)
		return if position == .top {
			rect(0, 0, width, bar), rect(0, bar, width, height - bar)
		} else {
			rect(0, height - bar, width, bar), rect(0, 0, width, height - bar)
		}
	}
	side := math.min(if config.bar_size > 0 { config.bar_size } else { 180.0 }, width)
	return if position == .left {
		rect(0, 0, side, height), rect(side, 0, width - side, height)
	} else {
		rect(width - side, 0, side, height), rect(0, 0, width - side, height)
	}
}

// tabbed_panel_bar is the tab_bar a themed tabbed panel draws, in the
// panel's own coordinates. Its tabs are named by their index ('0', '1', …).
// Use it to scroll a tab into view (tab_bar_reveal_offset, with
// tab_bar_scroll_id of its id) when tabbed_panel_update asks to reveal one.
pub fn tabbed_panel_bar(config TabbedPanelConfig) !TabBarConfig {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if !component_finite(config.bar_size) || config.bar_size < 0 {
		return error('tabbed panel bar size must be finite and non-negative')
	}
	bar, _ := tabbed_panel_bar_frames(config)
	mut items := []TabBarItem{cap: config.tabs.len}
	for index, tab in config.tabs {
		items << TabBarItem{
			id:                  index.str()
			label:               tab.title
			icon:                tab.icon
			badge:               tab.badge
			closable:            tab.closable
			enabled:             tab.enabled
			action_id:           tab.action_id
			accessibility_label: tab.title
		}
	}
	current := tabbed_panel_current(config.current, config.tabs.len)
	return TabBarConfig{
		id:                  component_part_id(config.id, 'tabs')
		frame:               bar
		items:               items
		state:               TabBarState{
			selected: if config.tabs.len > 0 { current.str() } else { '' }
			hovered:  if config.hovered >= 0 && config.hovered < config.tabs.len {
				config.hovered.str()
			} else {
				''
			}
		}
		variant:             config.variant or { TabVariant.tab }
		position:            tabbed_panel_bar_position(config.tab_position)
		align:               tab_strip_alignment(config.tab_position)
		fill:                config.fill
		offset:              config.offset
		accessibility_label: config.accessibility_label
		size:                config.size
		theme:               config.theme or { ComponentTheme{} }
	}
}

fn tabbed_panel_themed_geometry(config TabbedPanelConfig) !TabbedPanelGeometry {
	bar_config := tabbed_panel_bar(config)!
	layout := tab_bar_layout(bar_config)!
	_, content := tabbed_panel_bar_frames(config)
	bar := bar_config.frame
	mut headers := []Rect{cap: layout.tabs.len}
	for tab in layout.tabs {
		// Tabs that scroll are given where they are with the strip unscrolled.
		headers << rect(bar.x + layout.strip.x + tab.x, bar.y + layout.strip.y + tab.y, tab.width,
			tab.height)
	}
	return TabbedPanelGeometry{
		content: content
		headers: headers
	}
}

fn tabbed_panel_themed_element(config TabbedPanelConfig) !Element {
	bar_config := tabbed_panel_bar(config)!
	_, content := tabbed_panel_bar_frames(config)
	theme := bar_config.theme
	mut children := []Element{}
	if config.tabs.len > 0 {
		active := config.tabs[tabbed_panel_current(config.current, config.tabs.len)]
		children << Element{
			...active.content
			frame: content
		}
	}
	children << tab_bar(bar_config)!
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{
			bg: theme.background
		}, children)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
	})
}

// TabbedPanelStep is what tabbed_panel_update or tabbed_panel_key did.
pub struct TabbedPanelStep {
pub:
	current  int  // The tab to show: store it as the panel's current.
	selected bool // current changed.
	closed   int = -1 // The index of the tab whose close button was pressed.
	hovered  int = -1 // The tab under the pointer: store it as the panel's hovered.
	// reveal is set when the selection moved: in a themed panel whose tabs
	// scroll, bring the tab into view with tab_bar_reveal_offset.
	reveal bool
}

fn tabbed_panel_step(config TabbedPanelConfig, step TabBarStep) TabbedPanelStep {
	current := step.state.selected.int()
	return TabbedPanelStep{
		current:  if step.state.selected.len > 0 {
			current
		} else {
			tabbed_panel_current(config.current, config.tabs.len)
		}
		selected: step.selected
		closed:   if step.closed.len > 0 { step.closed.int() } else { -1 }
		hovered:  if step.state.hovered.len > 0 { step.state.hovered.int() } else { -1 }
		reveal:   step.reveal
	}
}

// tabbed_panel_update decodes an event from on_event for a tabbed panel: a
// press on a tab (by the tab's action_id, or a themed tab's own action),
// on a themed tab's close button, and the pointer entering or leaving a
// themed tab. It returns none for events that are not the panel's, disabled
// tabs and presses that change nothing.
pub fn tabbed_panel_update(config TabbedPanelConfig, event string) ?TabbedPanelStep {
	current := tabbed_panel_current(config.current, config.tabs.len)
	for index, tab in config.tabs {
		if tab.action_id.len > 0 && event == tab.action_id {
			if !tab.enabled || index == current {
				return none
			}
			return TabbedPanelStep{
				current:  index
				selected: true
				hovered:  config.hovered
				reveal:   true
			}
		}
	}
	if !tabbed_panel_themed(config) {
		return none
	}
	if pointer := parse_pointer_event(event) {
		// A tab with an action of its own reports hover under that action.
		for index, tab in config.tabs {
			if tab.action_id.len == 0 || pointer.action != tab.action_id || !tab.enabled {
				continue
			}
			hovered := if pointer.phase == 'enter' {
				index
			} else if pointer.phase == 'leave' && config.hovered == index {
				-1
			} else {
				return none
			}
			if hovered == config.hovered {
				return none
			}
			return TabbedPanelStep{
				current: current
				hovered: hovered
			}
		}
	}
	bar := tabbed_panel_bar(config) or { return none }
	step := tab_bar_update(bar, event)?
	return tabbed_panel_step(config, step)
}

// tabbed_panel_key moves a tabbed panel's selection from on_key_event, the
// way tab_bar_key moves a tab bar's: arrows along the tabs, Home and End,
// Ctrl+Tab and Ctrl+Shift+Tab. It works for either look.
pub fn tabbed_panel_key(config TabbedPanelConfig, event KeyEvent) ?TabbedPanelStep {
	mut items := []TabBarItem{cap: config.tabs.len}
	for index, tab in config.tabs {
		items << TabBarItem{
			id:      index.str()
			label:   tab.title
			enabled: tab.enabled
		}
	}
	bar := TabBarConfig{
		id:       if config.id.len > 0 { config.id } else { 'tabbed-panel' }
		items:    items
		state:    TabBarState{
			selected: if config.tabs.len > 0 {
				tabbed_panel_current(config.current, config.tabs.len).str()
			} else {
				''
			}
		}
		position: tabbed_panel_bar_position(config.tab_position)
	}
	step := tab_bar_key(bar, event)?
	return TabbedPanelStep{
		...tabbed_panel_step(config, step)
		hovered: config.hovered
	}
}
