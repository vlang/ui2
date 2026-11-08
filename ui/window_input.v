@[has_globals]
module ui2

// window_input.v holds the platform-neutral state of the window input hooks. The custom
// renderer delivers pointer moves, raw mouse buttons and wheels, and draws the menu bar
// from it; native backends accept the calls and do not act on them yet.

__global g_pointer_move_handler = PointerMoveFn(unsafe { nil })
__global g_mouse_button_handler = MouseButtonFn(unsafe { nil })
__global g_wheel_handler = WheelFn(unsafe { nil })
__global g_menu_bar_hidden = false

// on_pointer_move reports every pointer move over the window, wherever it lands, in
// logical units. The custom renderer delivers it; native backends do not yet.
pub fn on_pointer_move(handler PointerMoveFn) {
	g_pointer_move_handler = handler
}

// on_mouse_button reports raw mouse button transitions in window points:
// button 0 left, 1 right, 2 middle; down true on press, false on release. The
// custom renderer delivers it; native backends do not yet.
pub fn on_mouse_button(handler MouseButtonFn) {
	g_mouse_button_handler = handler
}

// on_wheel reports raw wheel deltas before any scroll element or the menu bar
// sees them: shift+wheel arrives as a vertical delta, exactly as the hardware
// sent it. The custom renderer delivers it; native backends do not yet.
pub fn on_wheel(handler WheelFn) {
	g_wheel_handler = handler
}

// set_menu_bar_hidden hides the menu bar in the custom renderer: it takes no room,
// draws nothing and takes no clicks. Native menu bars are not hidden.
pub fn set_menu_bar_hidden(hidden bool) {
	g_menu_bar_hidden = hidden
}

// menu_bar_hidden reports the state set by set_menu_bar_hidden.
pub fn menu_bar_hidden() bool {
	return g_menu_bar_hidden
}
