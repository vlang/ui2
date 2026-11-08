module ui2

import math

// The longest pause, in milliseconds, between two presses on a title bar that
// still make a double click, and how far apart (in points) they may be.
pub const title_bar_double_click_interval = i64(500)
pub const title_bar_double_click_distance = 4.0

// TitleBarWindow is what the window around a title bar is like. Fill it with
// title_bar_window, or set it yourself for a look of your own.
pub struct TitleBarWindow {
pub:
	// leading_inset is room left at the leading edge for the platform's own
	// window controls: macOS keeps its traffic lights over a hidden title bar.
	leading_inset f64
	// controls draws minimize, maximize (restore) and close at the trailing
	// edge: Windows needs them once the title bar is hidden, and an application
	// may want them anywhere for a custom-drawn look.
	controls    bool
	maximized   bool // The maximize button shows restore.
	minimizable bool = true
	maximizable bool = true // Also gates double click to maximize.
}

// title_bar_window asks the platform what a title bar needs. Pass whether
// set_window_chrome(.hidden_titlebar) succeeded: with the platform's own title
// bar still showing, a custom one is just a bar below it and needs neither the
// inset nor window buttons.
pub fn title_bar_window(chrome_hidden bool) TitleBarWindow {
	if !chrome_hidden {
		return TitleBarWindow{}
	}
	return TitleBarWindow{
		leading_inset: window_controls_leading_inset()
		controls:      window_draws_own_controls()
		maximized:     window_is_maximized()
	}
}

// TitleBarButton names the window buttons a title bar draws.
pub enum TitleBarButton {
	minimize
	maximize
	close
}

// TitleBarConfig describes a title bar drawn by the application in place of
// the platform's: a drag region the whole width of the window, with a title,
// items in three regions and, when the window asks for them, window buttons.
pub struct TitleBarConfig {
pub:
	id    string
	frame Rect
	// title is centered on the bar when `center` is empty, and leads the center
	// items otherwise.
	title    string
	leading  []BarItem // After the leading inset: an app menu, menu-bar buttons, a sidebar toggle.
	center   []BarItem // Breadcrumbs, a search field.
	trailing []BarItem // Before the window buttons: account, settings, notifications.
	window   TitleBarWindow
	enabled  bool = true // false disables the commands; dragging and window buttons keep working.
	// hovered is the command or window button under the pointer; keep it with
	// title_bar_hover_from_event.
	hovered string
	label   string // The accessible name; defaults to the title.
	style   BarStyle
	size    ComponentSize = .medium
	theme   ComponentTheme
}

// title_bar_drag_action is the action of the bar's background, the drag
// region. Its `pointer:down` is where to call start_window_drag();
// title_bar_event decodes it, and tells a double click apart.
pub fn title_bar_drag_action(id string) string {
	return component_part_id(id, 'drag')
}

fn title_bar_button_part(button TitleBarButton) string {
	return match button {
		.minimize { 'window:minimize' }
		.maximize { 'window:maximize' }
		.close { 'window:close' }
	}
}

// title_bar_button_action is the action of a window button, and the hovered
// value of a title bar whose button is under the pointer is
// `window:minimize`, `window:maximize` or `window:close`.
pub fn title_bar_button_action(id string, button TitleBarButton) string {
	return component_part_id(id, title_bar_button_part(button))
}

fn title_bar_buttons(config TitleBarConfig) []TitleBarButton {
	if !config.window.controls {
		return []TitleBarButton{}
	}
	mut buttons := []TitleBarButton{}
	if config.window.minimizable {
		buttons << .minimize
	}
	if config.window.maximizable {
		buttons << .maximize
	}
	buttons << .close
	return buttons
}

fn title_bar_items(config TitleBarConfig) []BarItem {
	mut items := config.leading.clone()
	items << config.center
	items << config.trailing
	return items
}

// title_bar_center_items puts the title before the center items when there
// are any; alone, the title is placed by title_bar_layout instead.
fn title_bar_center_items(config TitleBarConfig) []BarItem {
	if config.title.len == 0 || config.center.len == 0 {
		return config.center
	}
	mut items := [
		BarItem{
			kind:  .label
			label: config.title
			bold:  true
		},
	]
	items << config.center
	return items
}

struct TitleBarLayout {
	metrics    BarMetrics
	buttons    []TitleBarButton
	controls_x f64 // Where the window buttons start; the bar's width without them.
	title      Rect
	centered   bool // The title is centered on the bar rather than packed.
	leading    []BarPlacement
	center     []BarItem
	center_at  []BarPlacement
	trailing   []BarPlacement
}

// title_bar_layout packs the leading region after the inset and the trailing
// region before the window buttons, then centers the title (or the center
// items) on the whole bar, as close as the ends allow.
fn title_bar_layout(config TitleBarConfig) TitleBarLayout {
	m := bar_metrics(.title_bar, config.size)
	width := config.frame.width
	buttons := title_bar_buttons(config)
	controls_width := math.min(f64(buttons.len) * m.window_button, width)
	controls_x := width - controls_width
	inset := if component_finite(config.window.leading_inset) {
		math.max(config.window.leading_inset, 0.0)
	} else {
		0.0
	}
	start := math.min(math.max(inset, m.padding), controls_x)
	end := math.max(controls_x - if buttons.len > 0 { m.gap } else { m.padding }, start)
	leading := bars_pack(config.leading, start, end - start, m, false)
	_, leading_end := bars_used(leading)
	low := if bars_any_shown(leading) { math.min(leading_end + m.padding, end) } else { start }
	trailing := bars_pack_end(config.trailing, end, end - low, m, false)
	trailing_start, _ := bars_used(trailing)
	high := if bars_any_shown(trailing) { math.max(trailing_start - m.padding, low) } else { end }
	room := high - low
	center := title_bar_center_items(config)
	mut center_at := bars_pack(center, low, room, m, false)
	first, last := bars_used(center_at)
	used := last - first
	ideal := (width - used) / 2
	center_at = bars_shift(center_at, math.max(low, math.min(ideal, high - used)) - low)
	mut title := Rect{}
	mut centered := false
	if config.title.len > 0 && config.center.len == 0 {
		// Centered on the bar in a span symmetric about its middle, so the
		// text is centered however wide it really is; where the ends leave no
		// such span, it takes the room between them.
		half := math.min(width / 2 - low, high - width / 2)
		estimate := component_text_width_estimate(config.title, m.font_size)
		if half * 2 >= estimate {
			title = rect(math.round(width / 2 - half), 0, math.round(half * 2), config.frame.height)
			centered = true
		} else {
			title = rect(math.round(low), 0, math.round(room), config.frame.height)
		}
	}
	return TitleBarLayout{
		metrics:    m
		buttons:    buttons
		controls_x: controls_x
		title:      title
		centered:   centered
		leading:    leading
		center:     center
		center_at:  center_at
		trailing:   trailing
	}
}

// title_bar_background is GPUI Kit's title bar fill: a vertical gradient from
// the title bar color mixed toward the background down to the title bar color.
fn title_bar_background(theme ComponentTheme) Gradient {
	bar := choice_mix(theme.background, theme.muted, 0.85)
	return linear_gradient(90, gradient_stop(choice_mix(bar, theme.background, 0.45), 0),
		gradient_stop(bar, 1))
}

// title_bar_glyph draws a window button's symbol from one-point lines, so it is
// crisp and identical on every renderer; the close cross is the xmark symbol.
fn title_bar_glyph(button TitleBarButton, maximized bool, width f64, height f64, size f64, color u32) []Element {
	g := math.round(size)
	x := math.round((width - g) / 2)
	y := math.round((height - g) / 2)
	line := fn [color] (frame Rect) Element {
		return view('', frame, BoxStyle{ bg: color }, []Element{})
	}
	match button {
		.minimize {
			return [line(rect(x, math.round(height / 2), g, 1))]
		}
		.maximize {
			if !maximized {
				return [line(rect(x, y, g, 1)), line(rect(x, y + g - 1, g, 1)), line(rect(x, y, 1, g)),
					line(rect(x + g - 1, y, 1, g))]
			}
			// Restore: a square in front of the corner of another behind it.
			s := g - 2
			fy := y + 2
			return [line(rect(x + 2, y, s, 1)), line(rect(x + g - 1, y, 1, s)),
				line(rect(x, fy, s, 1)), line(rect(x, fy + s - 1, s, 1)), line(rect(x, fy, 1, s)),
				line(rect(x + s - 1, fy, 1, s))]
		}
		.close {
			side := g + 4
			return [
				bars_symbol('xmark', rect(math.round((width - side) / 2), math.round((height - side) / 2),
					side, side), color),
			]
		}
	}
}

fn title_bar_button_label(button TitleBarButton, maximized bool) string {
	return match button {
		.minimize { 'Minimize' }
		.maximize {
			if maximized { 'Restore' } else { 'Maximize' }
		}
		.close { 'Close' }
	}
}

fn title_bar_window_button(config TitleBarConfig, button TitleBarButton, frame Rect, look BarLook) Element {
	part := title_bar_button_part(button)
	hovered := look.hovered == part
	close := button == .close
	theme := config.theme
	color := if hovered && close { theme.danger_foreground } else { look.foreground }
	mut children := []Element{}
	local := component_local(frame)
	if hovered && close {
		children << view('', local, BoxStyle{ bg: theme.danger }, []Element{})
	} else if hovered {
		children << bars_overlay(local, 0, look.foreground, if bars_is_dark(theme) {
			0.12
		} else {
			0.08
		})
	}
	glyph := math.round(look.metrics.font_size * 0.77)
	if frame.width >= glyph + 4 && frame.height >= glyph + 4 {
		children << title_bar_glyph(button, config.window.maximized, frame.width, frame.height,
			glyph, color)
	}
	caption := title_bar_button_label(button, config.window.maximized)
	return Element{
		...button_view(component_part_id(config.id, part), frame, BoxStyle{ transparent: true },
			children)
		key:                 part
		action_id:           title_bar_button_action(config.id, button)
		hoverable:           true
		tooltip:             caption
		accessibility_role:  'button'
		accessibility_label: caption
	}
}

// title_bar draws an application-drawn title bar. The bar itself is the drag
// region: it reports `pointer:down` with title_bar_drag_action(id), while
// commands and window buttons answer their own clicks, and labels, the title
// and separators let a press through to the bar. Decode everything with
// title_bar_event.
pub fn title_bar(config TitleBarConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	all := title_bar_items(config)
	bars_validate_items(all, 'title bar')!
	for item in bars_flatten(all) {
		if item.id.starts_with('window:') {
			return error('title bar item ids cannot start with `window:`')
		}
	}
	layout := title_bar_layout(config)
	theme := config.theme
	m := layout.metrics
	gradient := if config.style.gradient.stops.len >= 2 {
		config.style.gradient
	} else if config.style.background != none {
		Gradient{}
	} else {
		title_bar_background(theme)
	}
	edges := if config.style.edges == .auto { BarEdges.bottom } else { config.style.edges }
	mut children := bars_surface(config.frame.width, config.frame.height, config.style.background,
		gradient, config.style.border or { bars_divider(theme) }, edges, config.style.radius,
		config.style.shadow)
	base := BarLook{
		bar_id:     config.id
		theme:      theme
		metrics:    m
		foreground: config.style.foreground or { theme.foreground }
		muted:      theme.muted_foreground
		surface:    bars_surface_color(config.style.background, gradient, theme.background)
		enabled:    config.enabled
		hovered:    config.hovered
	}
	if layout.title.width > 0 {
		children << Element{
			...label('', config.title, layout.title, TextStyle{
				color: base.foreground
				size:  m.font_size
				bold:  true
				align: if layout.centered { Align.center } else { Align.left }
			})
			key:                'title'
			accessibility_role: 'text'
		}
	}
	breadth := config.frame.height
	children << bars_items(config.leading, layout.leading, breadth, BarLook{
		...base
		region: 'leading:'
	})
	children << bars_items(layout.center, layout.center_at, breadth, BarLook{
		...base
		region: 'center:'
	})
	children << bars_items(config.trailing, layout.trailing, breadth, BarLook{
		...base
		region: 'trailing:'
	})
	if layout.buttons.len > 0 {
		// Squeezed evenly when the bar is narrower than the buttons.
		each := (config.frame.width - layout.controls_x) / f64(layout.buttons.len)
		for index, button in layout.buttons {
			frame := rect(layout.controls_x + f64(index) * each, 0, each, config.frame.height)
			children << title_bar_window_button(config, button, frame, base)
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		action_id:           title_bar_drag_action(config.id)
		clickable:           true
		accessibility_role:  'group'
		accessibility_label: if config.label.len > 0 {
			config.label
		} else if config.title.len > 0 {
			config.title
		} else {
			'Title bar'
		}
	})
}

// TitleBarClick is a press on a title bar's drag region: when it happened, in
// milliseconds (time.ticks()), and where. `count` is 1 for a single press and 2
// for the second press of a double click; the zero value is no press at all.
pub struct TitleBarClick {
pub:
	time_ms i64
	x       f64
	y       f64
	count   int
}

// title_bar_is_double_click reports whether a press completes a double click
// begun by `previous`: close enough in time and place to a single press. There
// is no double-click event, so the title bar keeps its last press and compares.
pub fn title_bar_is_double_click(previous TitleBarClick, current TitleBarClick) bool {
	if previous.count != 1 {
		return false
	}
	elapsed := current.time_ms - previous.time_ms
	return elapsed >= 0 && elapsed <= title_bar_double_click_interval
		&& math.abs(current.x - previous.x) <= title_bar_double_click_distance
		&& math.abs(current.y - previous.y) <= title_bar_double_click_distance
}

pub enum TitleBarEventKind {
	drag            // A press on the drag region: call start_window_drag().
	toggle_maximize // A double click on the drag region, or the maximize button: toggle_maximize_window().
	minimize        // The minimize button: minimize_window().
	close           // The close button: ui2.quit(), perhaps after asking to save.
	command         // A command in one of the regions: `item`.
}

// TitleBarEvent is a decoded title bar event. Keep `click` and pass it back as
// `previous` to the next title_bar_event, so a second press can be recognized
// as a double click.
pub struct TitleBarEvent {
pub:
	kind  TitleBarEventKind
	item  BarItem
	click TitleBarClick
}

// title_bar_event decodes an event from on_event: a press on the drag region
// (a drag, or with `previous` a double click that toggles maximize), a window
// button, or a command. now_ms is time.ticks(). It returns none for every
// other event, for disabled commands and for window buttons the bar does not
// draw.
pub fn title_bar_event(config TitleBarConfig, event string, previous TitleBarClick, now_ms i64) ?TitleBarEvent {
	if config.id.len == 0 {
		return none
	}
	if pointer := parse_pointer_event(event) {
		if pointer.phase != 'down' || pointer.action != title_bar_drag_action(config.id) {
			return none
		}
		press := TitleBarClick{
			time_ms: now_ms
			x:       pointer.x
			y:       pointer.y
			count:   1
		}
		if config.window.maximizable && title_bar_is_double_click(previous, press) {
			return TitleBarEvent{
				kind:  .toggle_maximize
				click: TitleBarClick{
					...press
					count: 2
				}
			}
		}
		return TitleBarEvent{
			kind:  .drag
			click: press
		}
	}
	for button in title_bar_buttons(config) {
		if event == title_bar_button_action(config.id, button) {
			return TitleBarEvent{
				kind: match button {
					.minimize { TitleBarEventKind.minimize }
					.maximize { TitleBarEventKind.toggle_maximize }
					.close { TitleBarEventKind.close }
				}
			}
		}
	}
	item := bars_item_from_action(config.id, title_bar_items(config), config.enabled, event) or {
		return none
	}
	return TitleBarEvent{
		kind: .command
		item: item
	}
}

// title_bar_hover_from_event returns the next `hovered` value when the pointer
// enters or leaves a command or a window button, and none otherwise.
pub fn title_bar_hover_from_event(config TitleBarConfig, event string) ?string {
	mut extra := map[string]string{}
	for button in title_bar_buttons(config) {
		extra[title_bar_button_action(config.id, button)] = title_bar_button_part(button)
	}
	return bars_hover_from_event(config.id, title_bar_items(config), extra, config.hovered,
		event)
}

// title_bar_item_frame is where an item is drawn, in the coordinates of the
// bar's parent: the anchor of the menu a menu-bar button opens. It is none
// for items that are not shown.
pub fn title_bar_item_frame(config TitleBarConfig, item_id string) ?Rect {
	layout := title_bar_layout(config)
	m := layout.metrics
	mut frames := map[string]Rect{}
	breadth := config.frame.height
	bars_item_frames(config.leading, layout.leading, breadth, m, false, mut frames)
	bars_item_frames(layout.center, layout.center_at, breadth, m, false, mut frames)
	bars_item_frames(config.trailing, layout.trailing, breadth, m, false, mut frames)
	local := frames[item_id] or { return none }
	return rect(config.frame.x + local.x, config.frame.y + local.y, local.width, local.height)
}
