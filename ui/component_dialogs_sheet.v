module ui2

import math

pub enum SheetSide {
	right
	left
	top
	bottom
}

const sheet_resize_handle_thickness = 6.0

pub struct SheetConfig {
pub:
	id    string
	frame Rect // the area the sheet slides over, normally the window
	open  bool
	side  SheetSide
	// panel_size is the panel's width for a left or right sheet and its height
	// for a top or bottom one; it is clamped to the frame.
	panel_size f64 = 350
	// margin_top keeps a strip at the top of the frame clear, e.g. for a custom
	// title bar. It applies to every side but the bottom.
	margin_top  f64
	title       string
	description string
	// Body children are positioned relative to the body content, which is
	// layout.content_width wide; content_height -1 measures them.
	children          []Element
	content_height    f64 = -1
	buttons           []DialogButton
	footer_align      DialogFooterAlign = .end
	close_button      bool              = true
	close_on_backdrop bool              = true
	close_on_escape   bool              = true
	confirm_on_enter  bool
	backdrop          DialogBackdrop = .dim
	// resizable adds a drag handle on the panel's inner edge; decode its pointer
	// events with sheet_size_from_pointer and rebuild with the new panel_size.
	resizable bool
	min_size  f64 = 160
	// animation_duration is the length of sheet_open_animation and
	// sheet_close_animation, in seconds.
	animation_duration f64           = 0.2
	enabled            bool          = true
	size               ComponentSize = .medium
	theme              ComponentTheme
}

fn sheet_spec(config SheetConfig) DialogPanelSpec {
	return DialogPanelSpec{
		title:          config.title
		description:    config.description
		close_button:   config.close_button
		has_body:       config.children.len > 0 || config.content_height > 0
		content_height: if config.content_height >= 0 {
			config.content_height
		} else {
			dialog_children_height(config.children)
		}
		buttons:        config.buttons
		footer_align:   config.footer_align
		size:           config.size
	}
}

fn sheet_validate(config SheetConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	dialog_validate_extent(config.panel_size, 'sheet size')!
	dialog_validate_extent(config.margin_top, 'sheet top margin')!
	dialog_validate_extent(config.min_size, 'sheet minimum size')!
	dialog_validate_extent(config.animation_duration, 'sheet animation duration')!
	dialog_validate_content_height(config.content_height)!
	dialog_validate_buttons(config.buttons)!
}

fn sheet_top(config SheetConfig) f64 {
	return if config.side == .bottom {
		0.0
	} else {
		math.min(config.margin_top, config.frame.height)
	}
}

// sheet_panel_frames returns the panel where it rests and where it slides in
// from, just past its edge of the frame, both in frame-local coordinates.
fn sheet_panel_frames(config SheetConfig) (Rect, Rect) {
	w := config.frame.width
	h := config.frame.height
	top := sheet_top(config)
	if config.side in [.left, .right] {
		extent := math.min(config.panel_size, w)
		if config.side == .right {
			return rect(w - extent, top, extent, h - top), rect(w, top, extent, h - top)
		}
		return rect(0, top, extent, h - top), rect(-extent, top, extent, h - top)
	}
	if config.side == .top {
		extent := math.min(config.panel_size, h - top)
		return rect(0, top, w, extent), rect(0, top - extent, w, extent)
	}
	extent := math.min(config.panel_size, h)
	return rect(0, h - extent, w, extent), rect(0, h, w, extent)
}

// sheet_layout places the panel against its side of the frame and lays out its
// header, body and footer: the body fills the panel between them and scrolls
// when its content is taller.
pub fn sheet_layout(config SheetConfig) !DialogLayout {
	sheet_validate(config)!
	panel, offscreen := sheet_panel_frames(config)
	geom := dialog_panel_layout(sheet_spec(config), dialog_spacing(config.size), panel.width,
		panel.height)
	t := math.min(sheet_resize_handle_thickness, math.min(panel.width, panel.height))
	handle := if !config.resizable {
		Rect{}
	} else {
		match config.side {
			.right { rect(0, 0, t, panel.height) }
			.left { rect(panel.width - t, 0, t, panel.height) }
			.top { rect(0, panel.height - t, panel.width, t) }
			.bottom { rect(0, 0, panel.width, t) }
		}
	}
	return DialogLayout{
		...geom
		surface:       panel
		offscreen:     offscreen
		resize_handle: handle
	}
}

// sheet_panel_id is the id of the sliding panel, the element
// sheet_open_animation and sheet_close_animation move.
pub fn sheet_panel_id(id string) string {
	return component_part_id(id, 'panel')
}

fn sheet_panel_box(config SheetConfig) BoxStyle {
	return BoxStyle{
		bg:            config.theme.background
		border_color:  config.theme.border
		border_left:   if config.side == .right { 1 } else { 0 }
		border_right:  if config.side == .left { 1 } else { 0 }
		border_top:    if config.side == .bottom { 1 } else { 0 }
		border_bottom: if config.side == .top { 1 } else { 0 }
		shadow:        component_popup_shadow()
	}
}

// sheet builds a panel that slides over one side of the frame, with a backdrop
// over the rest. It follows modal_view's structure (a backdrop button, then a
// surface button that keeps clicks inside the panel from reaching it) but is
// anchored to an edge rather than centered. A closed sheet stays in the tree,
// hidden.
pub fn sheet(config SheetConfig) !Element {
	geom := sheet_layout(config)!
	local := rect(0, 0, geom.surface.width, geom.surface.height)
	mut panel_children := [
		Element{
			...button(component_part_id(config.id, 'surface'), '', local, BoxStyle{
				transparent: true
			}, TextStyle{})
			key:                'surface'
			accessibility_role: 'presentation'
		},
	]
	panel_children << dialog_panel_children(config.id, sheet_spec(config), geom, config.children,
		config.enabled, config.theme.foreground, config.theme)
	if config.resizable {
		vertical := config.side in [.left, .right]
		panel_children << Element{
			...draggable_view_with_cursor(component_part_id(config.id, 'resize'), geom.resize_handle,
				BoxStyle{ transparent: true }, if vertical {
					cursor_resize_ew
				} else {
					cursor_resize_ns
				}, []Element{})
			key:                 'resize'
			enabled:             config.enabled
			accessibility_label: 'Resize'
		}
	}
	mut children := []Element{cap: 2}
	if config.backdrop != .none {
		children << Element{
			...button(component_part_id(config.id, 'backdrop'), '', rect(0, 0, config.frame.width,
				config.frame.height), dialog_backdrop_box(config.backdrop, config.theme),
				TextStyle{})
			key:                'backdrop'
			action_id:          component_part_id(config.id, 'backdrop')
			accessibility_role: 'presentation'
		}
	}
	children << Element{
		...view(sheet_panel_id(config.id), geom.surface, sheet_panel_box(config), panel_children)
		key:                 'panel'
		accessibility_role:  'group'
		accessibility_label: config.title
	}
	// Without a backdrop the root covers only the panel, so the rest of the
	// window keeps working.
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		hidden:              !config.open
		accessibility_role:  'dialog'
		accessibility_label: config.title
	})
}

// sheet_event_from_action decodes an action from sheet against the config it
// was built with, like dialog_event_from_action.
pub fn sheet_event_from_action(config SheetConfig, action string) ?DialogEvent {
	return dialog_decode(config.id, config.open, config.enabled, config.close_button,
		config.close_on_backdrop && config.backdrop != .none, config.buttons, action)
}

// sheet_key_event is for on_key_event: Escape asks to dismiss, and when
// confirm_on_enter is set Enter confirms with the first enabled confirm button.
pub fn sheet_key_event(config SheetConfig, event KeyEvent) ?DialogEvent {
	return dialog_decode_key(config.open, config.enabled, config.close_on_escape, config.confirm_on_enter,
		config.buttons, event)
}

// sheet_size_from_pointer turns a press or drag on a resizable sheet's handle
// into the panel_size to rebuild with, between min_size and the frame. Pointer
// events carry window coordinates, so this expects the sheet's frame in window
// coordinates too, as it is when the sheet is a child of the screen.
pub fn sheet_size_from_pointer(config SheetConfig, event string) ?f64 {
	if !config.open || !config.enabled || !config.resizable {
		return none
	}
	pointer := parse_pointer_event(event)?
	if pointer.action != component_part_id(config.id, 'resize')
		|| pointer.phase !in ['down', 'drag', 'up'] {
		return none
	}
	top := config.frame.y + sheet_top(config)
	raw := match config.side {
		.right { config.frame.x + config.frame.width - pointer.x }
		.left { pointer.x - config.frame.x }
		.top { pointer.y - top }
		.bottom { config.frame.y + config.frame.height - pointer.y }
	}
	limit := if config.side in [.left, .right] {
		config.frame.width
	} else {
		config.frame.y + config.frame.height - top
	}
	if !component_finite(raw) {
		return none
	}
	return math.max(math.min(config.min_size, limit), math.min(raw, limit))
}

// sheet_open_animation slides the panel in from its edge. Rebuild with open set
// and start it on sheet_panel_id(config.id); when it ends, the panel returns
// to its declared frame.
pub fn sheet_open_animation(config SheetConfig) !Animation {
	geom := sheet_layout(config)!
	horizontal := config.side in [.left, .right]
	jump := if horizontal {
		animation(duration: 0, x: geom.offscreen.x)
	} else {
		animation(duration: 0, y: geom.offscreen.y)
	}
	slide := if horizontal {
		animation(
			duration:   config.animation_duration
			transition: .out_cubic
			x:          geom.surface.x
		)
	} else {
		animation(
			duration:   config.animation_duration
			transition: .out_cubic
			y:          geom.surface.y
		)
	}
	return (jump + slide).with_event_handler(dialog_release_animation)
}

// sheet_close_animation slides the panel back out past its edge, then calls
// closed, where the application sets open to false. Start it on
// sheet_panel_id(config.id) instead of closing the sheet directly.
pub fn sheet_close_animation(config SheetConfig, closed fn ()) !Animation {
	geom := sheet_layout(config)!
	slide := if config.side in [.left, .right] {
		animation(
			duration:   config.animation_duration
			transition: .in_cubic
			x:          geom.offscreen.x
		)
	} else {
		animation(
			duration:   config.animation_duration
			transition: .in_cubic
			y:          geom.offscreen.y
		)
	}
	return slide.with_event_handler(fn [closed] (event AnimationEvent) {
		if event.kind != .complete {
			return
		}
		if voidptr(closed) != unsafe { nil } {
			closed()
		}
		clear_animation(event.id)
	})
}
